#pragma once
#include "Engine.hpp"
#include "PhraseSuggestions.hpp"
#include <sqlite3.h>
#include <stdexcept>
#include <set>
#include <cctype>
namespace armkeykey {
// Numeric tones belong to the reading until Space opens numbered selection.
class JyutpingEngine {
    sqlite3 *db=nullptr;
    PhraseSuggestions phrases;
    State state;
    std::string head;
    void lookup(){
        std::string code;bool toned=false;
        for(char c:state.composition)if(c!='\''){code+=c;if(c>='1'&&c<='6')toned=true;}
        sqlite3_stmt *stmt=nullptr;
        const char* sql=toned?"SELECT word FROM readings WHERE toned=? ORDER BY score DESC,seq":"SELECT word FROM readings WHERE plain=? ORDER BY score DESC,seq";
        state.candidates.clear();state.page=state.highlight=0;
        if(sqlite3_prepare_v2(db,sql,-1,&stmt,nullptr)==SQLITE_OK){
            sqlite3_bind_text(stmt,1,code.c_str(),-1,SQLITE_TRANSIENT);std::set<std::string> seen;
            while(sqlite3_step(stmt)==SQLITE_ROW){std::string word=reinterpret_cast<const char*>(sqlite3_column_text(stmt,0));if(seen.insert(word).second)state.candidates.push_back(word);}
        }
        sqlite3_finalize(stmt);state.visible=!state.candidates.empty();state.beep=!state.visible;
    }
public:
    JyutpingEngine(const std::string& path,const std::string& phrasePath):phrases(phrasePath){
        if(sqlite3_open_v2(path.c_str(),&db,SQLITE_OPEN_READONLY,nullptr)!=SQLITE_OK){sqlite3_close(db);db=nullptr;throw std::runtime_error("Cantonese dictionary unavailable");}
    }
    ~JyutpingEngine(){if(db)sqlite3_close(db);}
    bool showingSuggestions() const { return state.associated; }
    void reset(){state={};head.clear();}
    State select(size_t index){
        state.committed.clear();state.beep=false;state.handled=true;
        if(!state.visible || index>=state.candidates.size()){state.beep=true;return state;}
        auto word=state.candidates[index];bool associated=state.associated;auto prefix=head;reset();state.handled=true;
        state.committed=associated?word.substr(prefix.size()):word;
        if(!associated){state.candidates=phrases.lookup(word);state.visible=!state.candidates.empty();state.associated=state.visible;head=word;}
        return state;
    }
    State process(const Key& key){
        state.committed.clear();state.beep=false;state.handled=true;
        if(key.modifiers&(2|4|16|64|32)){reset();state.handled=false;return state;}
        unsigned c=key.code;
        if(state.visible){
            if(c>='1'&&c<='9')return select(state.page*9+c-'1');
            if(c==13)return select(state.highlight);
            if(c==27){reset();state.handled=true;return state;}
            if(c==32||c==11||c==12){size_t n=(state.candidates.size()+8)/9;state.page=(state.page+n+(c==11?-1:1))%n;state.highlight=state.page*9;return state;}
            if(c==30||c==31){
                if(c==30){if(state.highlight)state.highlight--;else state.beep=true;}
                else if(state.highlight+1<state.candidates.size())state.highlight++;else state.beep=true;
                state.page=state.highlight/9;return state;
            }
            if(state.associated){reset();state.handled=true;}
            else if(c==8){state.visible=false;state.candidates.clear();state.page=state.highlight=0;}
            else {state.beep=true;return state;}
        }
        if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||((c>='1'&&c<='6')&&!state.composition.empty())||(c=='\''&&!state.composition.empty())){
            if(state.composition.size()>=64)state.beep=true;else state.composition+=char(std::tolower(c));return state;
        }
        if(state.composition.empty()){state.handled=false;return state;}
        if(c==8){state.composition.pop_back();return state;}
        if(c==27){reset();state.handled=true;return state;}
        if(c==32){lookup();return state;}
        if(c==13){auto raw=state.composition;reset();state.committed=raw;state.handled=true;return state;}
        if(c>=0x10000){reset();state.handled=false;return state;}
        state.beep=true;return state;
    }
};
}
