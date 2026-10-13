#pragma once
#include <fstream>
#include <string>
#include <vector>
#include <algorithm>
#include <sqlite3.h>
namespace armkeykey {
class PhraseSuggestions {
    std::vector<std::string> words;
    sqlite3 *db=nullptr;
public:
    explicit PhraseSuggestions(const std::string& path) {
        if(path.size()>=8 && path.substr(path.size()-8)==".sqlite3"){
            if(sqlite3_open_v2(path.c_str(),&db,SQLITE_OPEN_READONLY,nullptr)!=SQLITE_OK){sqlite3_close(db);db=nullptr;}
            return;
        }
        std::ifstream input(path);std::string word;
        while(std::getline(input,word)) {
            if(!word.empty() && word.back()=='\r')word.pop_back();
            if(!word.empty() && word[0]!='#' && std::find(words.begin(),words.end(),word)==words.end())words.push_back(word);
        }
    }
    ~PhraseSuggestions(){if(db)sqlite3_close(db);}
    PhraseSuggestions(const PhraseSuggestions&)=delete;
    PhraseSuggestions& operator=(const PhraseSuggestions&)=delete;
    std::vector<std::string> lookup(const std::string& head) const {
        std::vector<std::string> result;
        if(head.empty())return result;
        if(db){
            sqlite3_stmt *stmt=nullptr;
            if(sqlite3_prepare_v2(db,"SELECT word FROM phrases WHERE prefix=? ORDER BY score DESC,seq",-1,&stmt,nullptr)==SQLITE_OK){
                sqlite3_bind_text(stmt,1,head.c_str(),-1,SQLITE_TRANSIENT);
                while(sqlite3_step(stmt)==SQLITE_ROW)result.emplace_back(reinterpret_cast<const char*>(sqlite3_column_text(stmt,0)));
            }
            sqlite3_finalize(stmt);return result;
        }
        for(const auto& word:words)
            if(word.size()>head.size() && word.compare(0,head.size(),head)==0)result.push_back(word);
        return result;
    }
};
}
