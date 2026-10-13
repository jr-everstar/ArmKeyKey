#include <OpenVanilla/OpenVanilla.h>
#include <sqlite3.h>
#include <memory>
#include <stdexcept>
using namespace OpenVanilla;
int main(int argc, char**argv) {
    if(argc!=3) return 2;
    sqlite3* db=nullptr;
    const std::string output=argv[2], staging=output+".building-"+std::to_string(getpid());
    if(sqlite3_open(staging.c_str(), &db)!=SQLITE_OK) {sqlite3_close(db);std::remove(staging.c_str());return 3;}
    try {
    auto exec=[&](const std::string&s){if(sqlite3_exec(db,s.c_str(),nullptr,nullptr,nullptr)!=SQLITE_OK) throw std::runtime_error(sqlite3_errmsg(db));};
    exec("BEGIN");
    for(auto mode : {std::string("cj"),std::string("simplex")}) {
        OVCINDataTableParser parser;
        std::unique_ptr<OVCINDataTable> table(parser.CINDataTableFromFileName(std::string(argv[1])+"/"+mode+"-ext.cin"));
        if(!table) throw std::runtime_error("Missing CIN source");
        std::string name="Generic-"+mode+"-cin";
        exec("DROP TABLE IF EXISTS '"+name+"'");
        exec("CREATE TABLE '"+name+"' (key TEXT NOT NULL, value TEXT NOT NULL, seq INTEGER PRIMARY KEY)");
        sqlite3_stmt* stmt=nullptr;
        sqlite3_prepare_v2(db,("INSERT INTO '"+name+"' VALUES(?,?,?)").c_str(),-1,&stmt,nullptr);
        int seq=0;
        auto insert=[&](std::string k,std::string v){sqlite3_bind_text(stmt,1,k.c_str(),-1,SQLITE_TRANSIENT);sqlite3_bind_text(stmt,2,v.c_str(),-1,SQLITE_TRANSIENT);sqlite3_bind_int(stmt,3,seq++);if(sqlite3_step(stmt)!=SQLITE_DONE)throw std::runtime_error("Insert failed");sqlite3_reset(stmt);};
        for(auto item : {std::make_pair(table->propertyMap(),std::string("__property_")),std::make_pair(table->keynameMap(),std::string("__property_keyname-")),std::make_pair(table->chardefMap(),std::string())}) {
            for(size_t i=0;i<item.first->size();++i){auto p=item.first->keyValuePairAtIndex(i);insert(item.second+p.first,p.second);}
        }
        sqlite3_finalize(stmt);
        exec("CREATE INDEX '"+name+"-key' ON '"+name+"'(key,seq)");
    }
    exec("PRAGMA user_version=1");exec("COMMIT");exec("VACUUM");sqlite3_close(db);db=nullptr;
    if(std::rename(staging.c_str(),output.c_str()))throw std::runtime_error("Cannot replace dictionary");
    } catch(const std::exception& error) {
        if(db)sqlite3_close(db);std::remove(staging.c_str());std::cerr<<error.what()<<"\n";return 1;
    }
}
