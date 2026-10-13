#include "Engine.hpp"
#include <iostream>
#include <cstdlib>
using namespace armkeykey;
static void check(bool ok,const char* message){if(!ok){std::cerr<<message<<"\n";std::exit(1);}}
static State word(Engine& e){e.process({'h',"h"});e.process({'i',"i"});return e.process({'7',"7"});}
int main(int argc,char**argv){
    Engine engine(argv[1],argv[2],true,false,CharacterSet::Compatible,argv[3]);
    auto s=word(engine);check(s.committed=="我" && s.associated && s.visible && s.candidates[0]=="我們","suggest after explicit selection");
    s=engine.process({'1',"!",8});check(s.committed=="們" && !s.visible,"append suffix only");
    s=word(engine);s=engine.process({'a',"a"});check(s.composition=="日" && s.committed.empty() && !s.associated,"new code keeps first key");engine.reset();
    word(engine);s=engine.process({27,""});check(s.handled && s.committed.empty() && !s.visible,"escape dismisses without commit");
    word(engine);s=engine.process({8,""});check(!s.handled && !s.visible && s.committed.empty(),"backspace reaches host");
    word(engine);s=engine.process({'c',"c",16});check(!s.handled && !s.visible,"shortcut reaches host");
    word(engine);s=engine.process({'9',"(",8});check(s.visible && s.beep && s.committed.empty(),"invalid selection does not insert");
    s=engine.process({31,""});check(s.highlight==1,"suggestion highlight");s=engine.process({13,""});check(s.committed=="的","enter uses highlight");
    engine.reset();word(engine);engine.reset();s=engine.process({13,""});check(s.committed.empty() && !s.visible,"reset dismisses");
    engine.reset();engine.process({'k',"k"});s=engine.process({32," "});
    if(!s.associated)s=engine.select(0);
    check(s.associated && s.candidates.size()>9,"multi-page suggestions");
    s=engine.process({32," ",8});check(s.page==1 && s.highlight==9,"space pages suggestions");
    std::string suffix=s.candidates[9].substr(std::string("大").size());
    s=engine.process({'1',"!",8});check(s.committed==suffix && !s.visible,"selection on second page");
    for(unsigned modifier:{8u,4u,2u,16u,0u}){
        Engine configured(argv[1],argv[2],true,false,CharacterSet::Compatible,argv[3],"",modifier);
        word(configured);s=configured.process({'1',"1",modifier});
        check(s.committed=="們" && !s.visible,"configured modifier selects suffix");
        word(configured);s=configured.process({'1',"1",modifier==0?8u:0u});
        check(!s.handled && !s.visible && s.committed.empty(),"wrong modifier passes digit to host");
        word(configured);s=configured.process({32," ",modifier==0?8u:0u});
        check(!s.handled && !s.visible && s.committed.empty(),"wrong modifier passes space to host");
        configured.process({'k',"k"});s=configured.process({32," "});
        if(!s.associated)s=configured.select(0);
        s=configured.process({32," ",modifier});check(s.page==1,"configured modifier pages");
        auto expected=s.candidates[9].substr(std::string("大").size());
        s=configured.process({'1',"1",modifier});check(s.committed==expected,"configured second page selection");
        word(configured);s=configured.process({'1',"1",modifier|16u|4u});
        check(!s.handled && s.committed.empty(),"extra modifiers pass through");
    }
    Engine disabled(argv[1],argv[2],true,false);s=word(disabled);check(s.committed=="我" && !s.visible,"off preserves original behavior");
    std::cout<<"PASS phrase suggestions: suffix-only commit, dismissal, shortcuts, invalid selection, navigation, opt-out\n";
}
