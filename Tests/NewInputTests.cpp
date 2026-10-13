#include <algorithm>

#include "Engine.hpp"
#include <sqlite3.h>
#include <filesystem>
#include <iostream>
#include <cstdlib>
#include <chrono>
using namespace armkeykey;
void check(bool v,const char* s){if(!v){std::cerr<<"FAIL "<<s<<"\n";std::exit(1);}}
State type(Engine& e,const std::string& text){State s;for(unsigned char c:text)s=e.process({c,std::string(1,c)});return s;}
int main(int argc,char**argv){
    std::filesystem::create_directories(argv[3]);
    Engine five(argv[1],argv[3],InputMode::Cangjie5,false);
    for(auto [code,value]:{std::pair{"mwsl","面"},{"lmsy","非"},{"hui","鬼"}}){auto s=type(five,std::string(code)+" ");check(s.committed==value || std::find(s.candidates.begin(),s.candidates.end(),value)!=s.candidates.end(),code);five.reset();}
    Engine plain(argv[1],argv[3],InputMode::Zhuyin,false,CharacterSet::Compatible,"","",8,argv[2]);
    auto s=type(plain,"su3");check(s.visible,"plain candidates");check(std::find(s.candidates.begin(),s.candidates.end(),"你")!=s.candidates.end(),"plain ni3");
    size_t i=std::find(s.candidates.begin(),s.candidates.end(),"你")-s.candidates.begin();s=plain.select(i);check(s.committed=="你" && s.composition.empty(),"plain commit");
    Engine smart(argv[1],argv[3],InputMode::SmartZhuyin,true,CharacterSet::Compatible,"","",8,argv[2]);
    s=type(smart,"su3cl3");check(s.composition=="你好" && s.committed.empty(),"smart phrase");
    s=smart.process({28,""});check(s.selectionStart==3,"middle caret");
    s=smart.process({31,""});check(s.visible,"smart candidates");
    check(!s.candidates.empty(),"smart alternatives");s=smart.select(0);check(s.committed.empty(),"selection remains in buffer");
    s=smart.finish();check(!s.committed.empty() && s.composition.empty(),"smart finish");check(smart.finish().committed.empty(),"finish idempotent");
    type(smart,"su3cl3");s=smart.process({27,""});check(s.composition.empty(),"escape whole sentence");
    type(smart,"su3");type(smart,"c");smart.process({27,""});s=smart.finish();check(!s.committed.empty(),"escape cancels unfinished syllable only");
    // Tone keys remain phonetic until the candidate panel is open.
    for(auto keys:{"a8 ","a86","a83","a84","a87"}){plain.reset();auto tone=type(plain,keys);check(tone.visible,"five tone lookups");}
    plain.reset();s=type(plain,"3");check(s.beep && s.composition.empty(),"standalone tone rejected");
    type(plain,"su3");s=plain.process({12,""});check(s.page==1,"plain paging");plain.reset();
    smart.reset();type(smart,"su3cl3");smart.process({28,""});smart.process({127,""});s=smart.finish();check(s.committed=="你","delete after middle caret");
    type(smart,"su3cl3");smart.process({1,""});type(smart,"5j/ ");s=smart.finish();check(s.committed.size()>=9,"insert at home");
    type(smart,"su3cl3");s=smart.process({'c',"c",16});check(!s.handled && s.committed=="你好","shortcut commits converted text once");
    type(smart,"su3cl3");s=smart.process({'<',"<",8});check(s.committed=="你好，","shift punctuation flushes sentence");
    // A deliberately selected uncommon homophone is learned only after commit.
    smart.reset();type(smart,"su3");s=smart.process({31,""});
    size_t rare=s.candidates.size()-1;std::string selected=s.candidates[rare];smart.select(rare);smart.finish();
    Engine remembered(argv[1],argv[3],InputMode::SmartZhuyin,true,CharacterSet::Compatible,"","",8,argv[2]);
    s=type(remembered,"su3");check(s.composition==selected,"learning survives engine restart");remembered.reset();
    Engine disabled(argv[1],argv[3],InputMode::SmartZhuyin,false,CharacterSet::Compatible,"","",8,argv[2]);
    s=type(disabled,"su3");check(s.composition!=selected,"disabled learning ignores preferences");disabled.reset();
    type(remembered,"su3");s=remembered.process({31,""});remembered.select(0);remembered.reset();
    Engine afterCancel(argv[1],argv[3],InputMode::SmartZhuyin,true,CharacterSet::Compatible,"","",8,argv[2]);
    s=type(afterCancel,"su3");check(s.composition==selected,"cancel never learns");
    auto begin=std::chrono::steady_clock::now();
    for(int n=0;n<64;n++)type(disabled,"su3cl3");
    s=type(disabled,"su3");check(s.beep,"bounded composition");
    auto elapsed=std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now()-begin).count();
    std::cout<<"128 syllables: "<<elapsed<<" ms\n";
    std::cout<<"PASS Cangjie 5, traditional and smart Zhuyin\n";
}
