#pragma once
#include "Engine.hpp"
#include <McBopomofo/Source/Engine/Mandarin/Mandarin.h>
#include <McBopomofo/Source/Engine/gramambular2/reading_grid.h>
#include <sqlite3.h>
#include <algorithm>
#include <cmath>
#include <map>
#include <stdexcept>

namespace armkeykey {
namespace zhuyin {
using Grid = Formosa::Gramambular2::ReadingGrid;
using LM = Formosa::Gramambular2::LanguageModel;
inline size_t byteAt(const std::string& s, size_t character) {
    size_t i=0;
    while(i<s.size() && character) { ++i; while(i<s.size() && (static_cast<unsigned char>(s[i])&0xc0)==0x80)++i; --character; }
    return i;
}
struct DB {
    sqlite3* value=nullptr;
    DB(const std::string& path,int flags) {
        if(sqlite3_open_v2(path.c_str(),&value,flags,nullptr)!=SQLITE_OK){sqlite3_close(value);value=nullptr;throw std::runtime_error("Mandarin database unavailable");}
        sqlite3_busy_timeout(value,1000);
    }
    ~DB(){sqlite3_close(value);}
};
struct Statement {
    sqlite3_stmt* value=nullptr;
    Statement(sqlite3* db,const char* sql){if(sqlite3_prepare_v2(db,sql,-1,&value,nullptr)!=SQLITE_OK)throw std::runtime_error("Mandarin query unavailable");}
    ~Statement(){sqlite3_finalize(value);}
    void bind(int n,const std::string& s){sqlite3_bind_text(value,n,s.c_str(),-1,SQLITE_TRANSIENT);}
};
class Model : public LM {
    DB source;
    std::unique_ptr<DB> user;
    bool smart;
public:
    Model(const std::string& dictionary,const std::string& directory,bool smartMode,bool learning)
      :source(dictionary,SQLITE_OPEN_READONLY),smart(smartMode) {
        Statement check(source.value,smart?"SELECT key,value,score FROM smart LIMIT 1":"SELECT key,value,score FROM plain LIMIT 1");
        if(sqlite3_step(check.value)!=SQLITE_ROW)throw std::runtime_error("Empty Mandarin dictionary");
        if(smart && learning){
            user=std::make_unique<DB>(directory+"/Generic-smartZhuyin-cin-DynamicCandidateOrder.sqlite3",SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE);
            if(sqlite3_exec(user->value,"CREATE TABLE IF NOT EXISTS user_frequency (key,value,count)",nullptr,nullptr,nullptr)!=SQLITE_OK)throw std::runtime_error("Mandarin learning unavailable");
        }
    }
    std::vector<Unigram> getUnigrams(const std::string& key) override {
        Statement q(source.value,smart?"SELECT value,score FROM smart WHERE key=? ORDER BY score DESC,seq":"SELECT value,score FROM plain WHERE key=? ORDER BY seq");q.bind(1,key);
        std::vector<Unigram> result;
        while(sqlite3_step(q.value)==SQLITE_ROW)result.emplace_back(reinterpret_cast<const char*>(sqlite3_column_text(q.value,0)),sqlite3_column_double(q.value,1));
        if(user && !result.empty()){
            Statement learned(user->value,"SELECT value,count FROM user_frequency WHERE key=? ORDER BY count DESC,rowid DESC");learned.bind(1,key);
            std::map<std::string,int> counts;
            while(sqlite3_step(learned.value)==SQLITE_ROW)counts[reinterpret_cast<const char*>(sqlite3_column_text(learned.value,0))]=sqlite3_column_int(learned.value,1);
            double top=result.front().score();
            for(auto& item:result){auto found=counts.find(item.value());if(found!=counts.end())item=Unigram(item.value(),top+std::min(1.0,0.1*std::log1p(found->second)));}
            std::stable_sort(result.begin(),result.end(),[](auto&a,auto&b){return a.score()>b.score();});
        }
        return result;
    }
    bool hasUnigrams(const std::string& key) override {return !getUnigrams(key).empty();}
    bool learn(const Grid::WalkResult& walk) {
        if(!user)return true;
        if(sqlite3_exec(user->value,"BEGIN IMMEDIATE",nullptr,nullptr,nullptr)!=SQLITE_OK)return false;
        try {
            for(auto& node:walk.nodes)if(node->isOverridden()){
                Statement update(user->value,"UPDATE user_frequency SET count=min(count+1,2147483647) WHERE key=? AND value=?");update.bind(1,node->reading());update.bind(2,node->value());
                if(sqlite3_step(update.value)!=SQLITE_DONE)throw std::runtime_error("Learning write failed");
                if(!sqlite3_changes(user->value)){
                    Statement add(user->value,"INSERT INTO user_frequency VALUES(?,?,1)");add.bind(1,node->reading());add.bind(2,node->value());
                    if(sqlite3_step(add.value)!=SQLITE_DONE)throw std::runtime_error("Learning write failed");
                }
            }
            if(sqlite3_exec(user->value,"COMMIT",nullptr,nullptr,nullptr)!=SQLITE_OK)throw std::runtime_error("Learning commit failed");
            return true;
        } catch(...) {sqlite3_exec(user->value,"ROLLBACK",nullptr,nullptr,nullptr);return false;}
    }
};
}
class ZhuyinEngine {
    using Grid=zhuyin::Grid;
    bool smart;
    Formosa::Mandarin::BopomofoReadingBuffer reading{Formosa::Mandarin::BopomofoKeyboardLayout::StandardLayout()};
    std::shared_ptr<zhuyin::Model> model;
    Grid grid;
    std::vector<Grid::Candidate> choices;
    size_t highlight=0, choiceLocation=0;
    bool choosing=false;
    State snapshot(bool handled=true,bool beep=false) {
        State s;s.handled=handled;s.beep=beep;
        auto walk=grid.walk();std::string text;
        for(auto& n:walk.nodes)text+=n->value();
        size_t caret=zhuyin::byteAt(text,grid.cursor());
        s.composition=text.substr(0,caret)+reading.composedString()+text.substr(caret);
        s.selectionStart=caret+reading.composedString().size();s.selectionLength=0;
        if(choosing){
            s.visible=true;s.highlight=highlight;s.page=highlight/s.pageSize;
            for(auto& c:choices)s.candidates.push_back(c.value);
            if(smart && !choices.empty()){
                size_t end=0;auto node=walk.findNodeAt(choiceLocation,&end);
                if(node!=walk.nodes.end()){
                    s.selectionStart=zhuyin::byteAt(text,end-(*node)->spanningLength());
                    s.selectionLength=zhuyin::byteAt(text,end)-s.selectionStart;
                }
            }
        }
        return s;
    }
    State openChoices(){
        choices.clear();highlight=0;
        if(smart){choiceLocation=grid.cursor()==grid.length()?grid.length()-1:grid.cursor();choices=grid.candidatesAt(choiceLocation);}
        else for(auto& u:model->getUnigrams(reading.composedString()))choices.emplace_back(reading.composedString(),u.value());
        choosing=!choices.empty();return snapshot(true,!choosing);
    }
    State completeReading(){
        if(reading.isEmpty() || reading.hasToneMarkerOnly())return snapshot(true,true);
        if(!smart)return openChoices();
        if(grid.length()>=128)return snapshot(true,true);
        if(!grid.insertReading(reading.composedString()))return snapshot(true,true);
        reading.clear();return snapshot();
    }
public:
    ZhuyinEngine(const std::string& dictionary,const std::string& directory,bool smartMode,bool learning)
      :smart(smartMode),model(std::make_shared<zhuyin::Model>(dictionary,directory,smartMode,learning)),grid(model){}
    void reset(){reading.clear();grid.clear();choices.clear();choosing=false;highlight=0;}
    State finish(){
        if(!smart){if(choosing)return select(highlight);reset();return snapshot();}
        auto walk=grid.walk();std::string text;for(auto& n:walk.nodes)text+=n->value();
        bool saved=model->learn(walk);reset();auto s=snapshot(true,!saved);s.committed=text;return s;
    }
    State select(size_t index){
        if(!choosing || index>=choices.size())return snapshot(true,true);
        auto selected=choices[index];
        if(!smart){reset();auto s=snapshot();s.committed=selected.value;return s;}
        if(!grid.overrideCandidate(choiceLocation,selected))return snapshot(true,true);
        choosing=false;choices.clear();return snapshot();
    }
    State process(const Key& key){
        unsigned k=key.code;
        if(key.modifiers & (2|4|16|64)){
            if(smart){auto s=finish();s.handled=false;return s;}
            reset();return snapshot(false);
        }
        if(choosing){
            if(k>='1'&&k<='9'&&!key.modifiers)return select((highlight/9)*9+k-'1');
            if(k==13)return select(highlight);
            if(k==27){choosing=false;choices.clear();return snapshot();}
            if(k==32||k==11||k==12){size_t pages=(choices.size()+8)/9;size_t page=(highlight/9+pages+(k==11?-1:1))%pages;highlight=page*9;return snapshot();}
            if(k==30||k==31){if(k==30&&highlight) --highlight;else if(k==31&&highlight+1<choices.size())++highlight;else return snapshot(true,true);return snapshot();}
            if(k==8){choosing=false;choices.clear();if(!smart)reading.backspace();return snapshot();}
            return snapshot(true,true);
        }
        if(k==27){if(!reading.isEmpty())reading.clear();else grid.clear();return snapshot();}
        if(k==8||k==127){
            if(!reading.isEmpty()){reading.backspace();return snapshot();}
            if(grid.length()){bool ok=k==8?grid.deleteReadingBeforeCursor():grid.deleteReadingAfterCursor();return snapshot(true,!ok);}
            return snapshot(false);
        }
        if(k==13){if(!reading.isEmpty())return completeReading();if(grid.length())return finish();return snapshot(false);}
        if(smart && grid.length() && reading.isEmpty()){
            if(k==28||k==29||k==1||k==4){size_t c=grid.cursor();if(k==28&&c)--c;else if(k==29&&c<grid.length())++c;else if(k==1)c=0;else if(k==4)c=grid.length();grid.setCursor(c);return snapshot();}
            if(k==31||k==32)return openChoices();
        }
        if(k==32&&!reading.isEmpty())return completeReading();
        if(!(key.modifiers&8) && k<128 && reading.isValidKey(static_cast<char>(k))){
            if(reading.isEmpty() && (k=='3'||k=='4'||k=='6'||k=='7'))return snapshot(true,true);
            reading.combineKey(static_cast<char>(k));
            if(reading.hasToneMarker())return completeReading();
            return snapshot();
        }
        // Shift-punctuation is explicit: unshifted punctuation keys may be Zhuyin vowels.
        if(reading.isEmpty() && key.text.size()==1 && (key.modifiers&8)){
            const std::map<char,std::string> punctuation={{'<',"，"},{'>',"。"},{'?',"？"},{':',"："},{'!',"！"},{'"',"、"},{'(',"（"},{')',"）"}};
            auto p=punctuation.find(key.text[0]);if(p!=punctuation.end()){auto s=finish();s.committed+=p->second;return s;}
        }
        if(!reading.isEmpty())return snapshot(true,true);
        auto s=finish();s.handled=false;return s;
    }
};
}
