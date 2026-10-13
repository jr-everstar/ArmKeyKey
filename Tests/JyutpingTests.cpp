#include "Engine.hpp"
#include "PhraseSuggestions.hpp"
#include <algorithm>
#include <iostream>
#include <cstdlib>
using namespace armkeykey;
static void check(bool ok,const char*message){if(!ok){std::cerr<<"FAIL "<<message<<"\n";exit(1);}}
static State type(Engine& e,const std::string& text){State s;for(char c:text)s=e.process({unsigned(c),std::string(1,c)});return s;}
int main(int argc,char**argv){
    Engine e("","",false,false,CharacterSet::Compatible,argv[1],argv[1]);
    for(const std::string code:{"neihou","nei5hou2","nei5'hou2"}){
        e.reset();auto s=type(e,code);check(s.composition==code&&!s.visible,"tones are reading before space");
        s=e.process({32," "});check(s.visible&&s.candidates[0]=="你好","toned and untoned phrase lookup");
        s=e.process({'1',"1"});check(s.committed=="你好"&&s.composition.empty(),"commit whole phrase once");
        s=e.process({27,""});check(s.committed.empty(),"commit not replayed");
    }
    e.reset();type(e,"ngo5dei6");auto s=e.process({32," "});check(std::find(s.candidates.begin(),s.candidates.end(),"我哋")!=s.candidates.end(),"Cantonese phrase");
    e.reset();type(e,"si");s=e.process({32," "});check(s.candidates.size()>9,"multi page homophones");
    auto first=s.candidates;s=e.process({32," "});check(s.page==1,"space paging");s=e.process({'1',"1"});check(s.committed==first[9],"second page selection");
    e.reset();type(e,"neihox");s=e.process({32," "});check(!s.visible&&s.beep&&s.composition=="neihox","invalid keeps composition");
    e.process({8,""});type(e,"u");s=e.process({32," "});check(s.candidates[0]=="你好","backspace correction");
    s=e.process({8,""});check(!s.visible&&s.composition=="neiho","edit candidates without inserting");
    s=e.process({27,""});check(s.composition.empty()&&!s.visible,"escape");
    type(e,"hoenggong");e.process({32," "});s=e.process({'c',"c",16});check(!s.handled&&!s.visible&&s.committed.empty(),"shortcut cancels");
    s=e.process({'5',"5"});check(!s.handled,"idle digits pass");
    type(e,"abc");s=e.process({13,""});check(s.committed=="abc","return raw reading");
    e.reset();type(e,"nei5hou2");e.process({32," "});s=e.select(99999);check(s.beep&&s.visible&&s.committed.empty(),"invalid index");e.reset();
    for(unsigned modifier:{8u,4u,2u,16u,0u}){
        Engine configured("","",false,false,CharacterSet::Compatible,argv[1],argv[1],modifier);
        auto suggest=[&](){configured.reset();type(configured,"ngo5");auto found=configured.process({32," "});
            auto it=std::find(found.candidates.begin(),found.candidates.end(),"我");
            check(it!=found.candidates.end(),"find suggestion head");
            return configured.select(it-found.candidates.begin());};
        s=suggest();check(s.associated,"Jyutping suggestions shown");
        auto expected=s.candidates[0].substr(std::string("我").size());
        s=configured.process({'1',"1",modifier});check(s.committed==expected && !s.visible,"Jyutping configured selection");
        suggest();s=configured.process({32," ",modifier});check(s.page==1,"Jyutping configured paging");
        expected=s.candidates[9].substr(std::string("我").size());
        s=configured.process({'1',"1",modifier});check(s.committed==expected,"Jyutping second page suffix");
        suggest();s=configured.process({'1',"1",modifier==0?8u:0u});
        check(!s.handled && !s.visible && s.committed.empty(),"Jyutping wrong selection modifier");
        suggest();s=configured.process({32," ",modifier==0?8u:0u});
        check(!s.handled && !s.visible && s.committed.empty(),"Jyutping wrong paging modifier");
        suggest();s=configured.process({'n',"n"});check(s.composition=="n" && !s.associated,"Jyutping continues reading");
    }
    PhraseSuggestions phrases(argv[1]);auto words=phrases.lookup("我");check(words.size()>20,"expanded offline suggestions");
    check(std::find(words.begin(),words.end(),"我哋")!=words.end(),"Cantonese associated word");
    check(std::find(words.begin(),words.end(),"我的")!=words.end(),"starter retained");
    std::cout<<"PASS Jyutping: tones, no tones, separators, selection, paging, editing, shortcuts, invalid codes; 我 suggestions="<<words.size()<<"\n";
}
