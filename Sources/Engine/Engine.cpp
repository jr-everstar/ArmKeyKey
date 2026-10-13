#include "Engine.hpp"
#include "PhraseSuggestions.hpp"
#include "JyutpingEngine.hpp"
#include <Generic/OVIMGeneric.h>
#include <PlainVanilla/PVLoaderService.h>
#include <PlainVanilla/PVCandidate.h>
#include <PlainVanilla/PVTextBuffer.h>
#include <PlainVanilla/PVBasicKeyValueMapImpl.h>
#include <stdexcept>
using namespace OpenVanilla;
namespace armkeykey {
struct QuietLog : PVLogEmitter { void emitLog(const std::string&) override {} };
// Stable cross-platform compatibility profile, not a claim to reproduce a
// particular historical PMingLiU font version. Keep dictionary order unchanged.
struct CharacterFilter : PVDefaultEncodingService {
    CharacterSet characters;
    explicit CharacterFilter(CharacterSet value):characters(value){}
    bool codepointSupportedBySystem(const std::string& text) override {
        if(characters==CharacterSet::FullUnicode)return true;
        auto code=OVUTF8Helper::CodePointFromSingleUTF8String(text);
        return code<0x10000 && !(code>=0xe000 && code<0xf900) && !(code>=0xfff0);
    }
};
struct Engine::Impl {
    PhraseSuggestions phrases;
    State suggestion;
    std::string phraseHead;
    QuietLog log;
    CharacterFilter encoding;
    std::unique_ptr<OVSQLiteDatabaseService> db;
    PVLoaderService loader;
    PVCandidateService candidates;
    PVTextBuffer reading, composing;
    std::unique_ptr<OVIMGeneric> module;
    std::unique_ptr<OVEventHandlingContext> context;
    Impl(const std::string& dictionary,const std::string& user,bool simplex,bool learning,CharacterSet characters,const std::string& phrasePath)
    : phrases(phrasePath),encoding(characters),db(OVSQLiteDatabaseService::Create(dictionary)),loader("en",nullptr,db.get(),&log,&encoding),candidates(&loader) {
        if(!db || !db->connection()->hasTable(simplex?"Generic-simplex-cin":"Generic-cj-cin")) throw std::runtime_error("ArmKeyKey dictionary is unavailable");
        // The bundled database is never modified by the engine.
        db->connection()->execute("PRAGMA query_only=ON");
        module=std::make_unique<OVIMGeneric>(simplex?"Generic-simplex-cin":"Generic-cj-cin",db.get());
        OVPathInfo path;path.writablePath=user;
        if(!module->initialize(&path,&loader)) throw std::runtime_error("Engine initialization failed");
        PVBasicKeyValueMapImpl values;OVKeyValueMap config(&values);
        config.setKeyBoolValue("UseDynamicFrequency",learning);
        module->loadConfig(&config,&loader);
        context.reset(module->createContext());
        if(!context) throw std::runtime_error("Engine context unavailable");
        candidates.resetAll();context->startSession(&loader);
    }
    ~Impl(){if(context) context->stopSession(&loader);}
    PVVerticalCandidatePanel* panel(){return candidates.accessVerticalCandidatePanel();}
    State state(bool handled){
        State s;s.handled=handled;s.beep=loader.shouldBeep();s.composition=reading.composedText();s.committed=composing.composedCommittedText();
        auto p=panel();s.visible=p->isVisible();s.page=p->currentPage();s.pageSize=p->candidatesPerPage();s.highlight=p->currentHightlightIndexInCandidateList();
        if(s.visible)for(size_t i=0;i<p->candidateList()->size();++i)s.candidates.push_back(p->candidateList()->candidateAtIndex(i));
        composing.finishCommit();
        if(!s.committed.empty() && s.composition.empty() && !s.visible){
            auto words=phrases.lookup(s.committed);
            if(!words.empty()){
                phraseHead=s.committed;s.candidates=std::move(words);s.visible=true;s.associated=true;
                s.page=0;s.pageSize=9;s.highlight=0;suggestion=s;suggestion.committed.clear();
            }
        }
        return s;
    }
};
Engine::Engine(const std::string& d,const std::string& u,bool s,bool l,CharacterSet c,const std::string& phrases,const std::string& cantonese,unsigned modifier):phraseModifier(modifier){
    if(!cantonese.empty())jyutping=std::make_unique<JyutpingEngine>(cantonese,phrases);
    else impl=std::make_unique<Impl>(d,u,s,l,c,phrases);
}
Engine::~Engine()=default;
void Engine::reset(){if(jyutping){jyutping->reset();return;}impl->suggestion={};impl->phraseHead.clear();impl->context->stopSession(&impl->loader);impl->reading.clear();impl->composing.clear();impl->composing.finishCommit();impl->candidates.resetAll();impl->context->startSession(&impl->loader);}
State Engine::select(size_t index){if(jyutping)return jyutping->select(index);auto&i=*impl;
    if(i.suggestion.visible){
        if(index>=i.suggestion.candidates.size()){auto s=i.suggestion;s.handled=true;s.beep=true;return s;}
        State s;s.handled=true;s.committed=i.suggestion.candidates[index].substr(i.phraseHead.size());
        i.suggestion={};i.phraseHead.clear();return s;
    }
auto p=i.panel();i.loader.resetState();if(index>=p->candidateList()->size())return i.state(false);auto text=p->candidateList()->candidateAtIndex(index);i.context->candidateSelected(&i.candidates,text,index,&i.reading,&i.composing,&i.loader);p->reset();return i.state(true);}
State Engine::process(const Key& input){
    Key event=input;
    const bool associated=jyutping?jyutping->showingSuggestions():impl->suggestion.visible;
    if(associated && ((event.code>='1' && event.code<='9') || event.code==32)){
        // Only the configured chord may select or page suggestions. Other keys
        // dismiss the panel and reach the client without inserting a phrase.
        if(event.modifiers!=phraseModifier){reset();return State{};}
        event.modifiers=0;
    }
    if(jyutping)return jyutping->process(event);
    auto&i=*impl;i.loader.resetState();
    // Host shortcuts must remain with the client; cancel unfinished reading.
    if(event.modifiers & (OVKeyMask::Command|OVKeyMask::Ctrl|OVKeyMask::AltOpt)){reset();return i.state(false);}
    if(i.suggestion.visible){
        auto& s=i.suggestion;s.handled=true;s.beep=false;
        if(!event.modifiers && event.code>='1' && event.code<='9')return select(s.page*s.pageSize+event.code-'1');
        if(!event.modifiers && event.code==13)return select(s.highlight);
        if(!event.modifiers && event.code==27){i.suggestion={};i.phraseHead.clear();State out;out.handled=true;return out;}
        if(!event.modifiers && (event.code==32 || event.code==11 || event.code==12)){
            size_t pages=(s.candidates.size()+s.pageSize-1)/s.pageSize;
            s.page=(s.page+pages+(event.code==11?-1:1))%pages;s.highlight=s.page*s.pageSize;return s;
        }
        if(!event.modifiers && (event.code==30 || event.code==31)){
            if(event.code==30){if(s.highlight)s.highlight--;else s.beep=true;}
            else if(s.highlight+1<s.candidates.size())s.highlight++;else s.beep=true;
            s.page=s.highlight/s.pageSize;return s;
        }
        // Dismiss suggestions and let the same key start a new code or reach the host.
        i.suggestion={};i.phraseHead.clear();
    }
    OVKey key(new PVKeyImpl(event.text,event.code,event.modifiers));
    auto p=i.panel();bool handled=true;
    if(p->isInControl()){
        auto result=p->handleKeyEvent(key,&i.loader);
        switch(result){
            case PVCandidateState::CandidateChosen:return select(p->chosenCandidateIndex());
            case PVCandidateState::Canceled:i.context->candidateCanceled(&i.candidates,&i.reading,&i.composing,&i.loader);break;
            case PVCandidateState::Ignored:
                if(!i.context->candidateNonPanelKeyReceived(&i.candidates,&key,&i.reading,&i.composing,&i.loader)) i.loader.beep();
                if(!p->isInControl())p->reset();
                break;
            case PVCandidateState::InvalidCandidateKey:case PVCandidateState::ReachedPageBoundary:i.loader.beep();break;
            default:break;
        }
    }else handled=i.context->handleKey(&key,&i.reading,&i.composing,&i.candidates,&i.loader);
    return i.state(handled);
}
}
