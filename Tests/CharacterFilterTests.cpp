#include "Engine.hpp"
#include <algorithm>
#include <filesystem>
#include <iostream>
#include <stdexcept>
using namespace armkeykey;
State hi(Engine& engine){engine.process({'h',"h"});return engine.process({'i',"i"});}
int main(int argc,char**argv){try{
    if(argc!=3)return 2;
    std::filesystem::create_directories(argv[2]);
    std::string learned;
    {
        Engine full(argv[1],argv[2],true,true,CharacterSet::FullUnicode);
        auto state=hi(full);
        for(size_t i=1;i<state.candidates.size();++i){
            if(static_cast<unsigned char>(state.candidates[i][0])>=0xf0){
                learned=state.candidates[i];full.select(i);break;
            }
        }
        if(learned.empty())throw std::runtime_error("missing supplementary character fixture");
    }
    {
        Engine compatible(argv[1],argv[2],true,true);
        auto state=hi(compatible);
        if(state.candidates.size()!=145 || std::find(state.candidates.begin(),state.candidates.end(),learned)!=state.candidates.end())throw std::runtime_error("learning bypassed character filter");
    }
    {
        Engine full(argv[1],argv[2],true,true,CharacterSet::FullUnicode);
        if(hi(full).candidates.front()!=learned)throw std::runtime_error("switching profiles lost learning");
    }
    std::cout<<"PASS filtered learning stays hidden without deleting it; full charset restores it\n";
}catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}}
