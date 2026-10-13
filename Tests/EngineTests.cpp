#include "Engine.hpp"
#include <OpenVanilla/OpenVanilla.h>
#include <filesystem>
#include <algorithm>
#include <iostream>
#include <set>
#include <stdexcept>
using namespace armkeykey;
using namespace OpenVanilla;
void require(bool b,const char*message){if(!b)throw std::runtime_error(message);}
State key(Engine&e,unsigned code,unsigned mods=0){return e.process({code,code>=32&&code<127?std::string(1,char(code)):"",mods});}
State type(Engine&e,const std::string&text){State s;for(unsigned char c:text)s=key(e,c);return s;}
int main(int argc,char**argv){try{
    require(argc==4,"usage: tests dictionary tables temp");
    std::filesystem::create_directories(argv[3]);
    std::unique_ptr<OVSQLiteDatabaseService> db(OVSQLiteDatabaseService::Create(argv[1]));
    size_t keys=0,entries=0;
    for(auto mode:{std::string("cj"),std::string("simplex")}){
        OVCINDataTableParser parser;std::unique_ptr<OVCINDataTable> reference(parser.CINDataTableFromFileName(std::string(argv[2])+"/"+mode+"-ext.cin"));
        require(bool(reference),"reference parser");
        std::unique_ptr<OVKeyValueDataTableInterface> table(db->createKeyValueDataTableInterface("Generic-"+mode+"-cin"));
        std::set<std::string> allKeys;
        for(size_t i=0;i<reference->chardefMap()->size();++i)allKeys.insert(reference->chardefMap()->keyValuePairAtIndex(i).first);
        for(auto&k:allKeys){auto expected=reference->findChardef(k);auto actual=table->valuesForKey(k);require(expected==actual,"exact lookup/order mismatch");++keys;entries+=actual.size();}
        for(auto pattern:{"a*","?a","ab?*","z*","*a"}) {auto expected=reference->findChardefWithWildcard(OVWildcard(pattern)); auto actual=table->valuesForKey(OVWildcard(pattern)); actual.erase(std::remove_if(actual.begin(),actual.end(),[](auto&p){return p.first.rfind("__property_",0)==0;}),actual.end()); if(expected!=actual) {std::cerr<<mode<<" pattern "<<pattern<<" expected "<<expected.size()<<" actual "<<actual.size()<<"\n"; for(size_t n=0;n<std::min(expected.size(),actual.size());++n)if(expected[n]!=actual[n]){std::cerr<<n<<" "<<expected[n].first<<":"<<expected[n].second<<" / "<<actual[n].first<<":"<<actual[n].second<<"\n";break;}} require(expected==actual,"wildcard ordering mismatch");}
    }
    std::cout<<"PASS exact lookup/order: "<<keys<<" codes, "<<entries<<" entries; wildcard lookup\n";
    Engine cj(argv[1],argv[3],false,false),simplex(argv[1],argv[3],true,false);
    auto s=type(cj,"a");require(s.composition=="日"&&s.committed.empty(),"Cangjie reading");s=key(cj,32);require(s.visible||!s.committed.empty(),"Cangjie compose");
    cj.reset();s=type(cj,"aaaaaa");require(s.beep,"Cangjie max five");cj.reset();type(cj,"ab");s=key(cj,8);require(s.composition=="日","Backspace radical");s=key(cj,27);require(s.composition.empty(),"Escape clears");
    s=key(cj,13);require(!s.handled,"empty Return passes");s=key(cj,8);require(!s.handled,"empty Backspace passes");
    s=type(cj,"zzzzz");s=key(cj,32);require(s.beep&&s.composition.empty(),"invalid clears");
    s=type(simplex,"aa");require(s.visible,"Simplex automatic compose");require(s.candidates.size()>9,"paging fixture");auto ordered=s.candidates;
    s=key(simplex,32);require(s.page==1,"Space next page");s=key(simplex,11);require(s.page==0,"PageUp");s=key(simplex,'2');require(s.committed==ordered[1]&&!s.visible&&s.composition.empty(),"number selection");
    type(simplex,"aa");s=key(simplex,31);require(s.highlight==1,"Down highlight");s=key(simplex,13);require(s.committed==ordered[1],"Return selection");
    type(simplex,"aa");s=key(simplex,8);require(!s.visible&&s.composition=="日","Backspace from candidates");simplex.reset();
    type(simplex,"aa");s=key(simplex,27);require(!s.visible&&s.composition.empty(),"candidate Escape");
    type(simplex,"aa");s=key(simplex,'a');require(s.committed==ordered[0]&&s.composition=="日","continue typing chooses highlight");simplex.reset();
    type(cj,"a*");s=key(cj,32);require(s.visible&&s.candidates.size()>9,"wildcard compose");cj.reset();
    s=key(cj,',');require(s.committed=="，"||s.visible,"punctuation");cj.reset();
    type(cj,"ab");s=key(cj,'c',16);require(!s.handled&&s.composition.empty(),"command shortcut");
    // User-supplied YahooKeyKey screenshot: 竹戈, nine choices per page, 17 pages.
    Engine compatible(argv[1],argv[3],true,false);
    auto hi=type(compatible,"hi");
    const std::vector<std::string> firstPage={"凡","么","丟","夙","舟","卵","我","私","的"};
    require(hi.candidates.size()==145 && hi.pageSize==9 && (hi.candidates.size()+8)/9==17,"hi compatible page count");
    require(std::equal(firstPage.begin(),firstPage.end(),hi.candidates.begin()),"hi screenshot first page");
    for(int page=1;page<17;++page){hi=key(compatible,32);require(hi.page==size_t(page),"hi consecutive pages");}
    require(hi.candidates.size()-hi.page*hi.pageSize==1,"hi final page count");
    require(hi.candidates.back()=="䑛","hi user-confirmed legacy final page");
    Engine full(argv[1],argv[3],true,false,CharacterSet::FullUnicode);
    auto fullHi=type(full,"hi");require(fullHi.candidates.size()==398 && (fullHi.candidates.size()+8)/9==45,"hi full charset remains available");
    std::vector<std::string> retained;
    for(auto& value:fullHi.candidates){auto c=OVUTF8Helper::CodePointFromSingleUTF8String(value);if(c<0x10000 && !(c>=0xe000&&c<0xf900) && c<0xfff0)retained.push_back(value);}
    require(retained==hi.candidates,"filter preserves original relative order");
    std::cout<<"PASS hi screenshot: compatible 145 candidates / 17 pages; full 398 / 45; first nine, final 䑛 and retained order match\n";
    std::string learned;
    {
        Engine learning(argv[1],argv[3],false,true);type(learning,"a*");s=key(learning,32);learned=s.candidates[1];s=key(learning,'2');require(s.committed==learned,"learn selection");
    }
    {Engine learning(argv[1],argv[3],false,true);type(learning,"a*");s=key(learning,32);require(s.candidates[0]==learned,"learning survives restart");}
    std::cout<<"PASS key handling, paging, punctuation, wildcard, learning persistence\n";
    if(std::getenv("AK_TRACE")) {
        // Deterministic source-engine differential trace, with independent fresh databases.
        for(bool simple:{false,true}){
            Engine e(argv[1],argv[3],simple,false);
            for(auto sequence:{"aa 2","ab \r","a* \033","zzzzz ","a\b\033",",","aa \v1","aa\037\r","aa\b\033","abcde\033","aa!\033"}){
                e.reset();
                for(unsigned char c:std::string(sequence)){
                    auto t=key(e,c);std::cout<<simple<<":"<<int(c)<<":"<<t.handled<<":"<<t.beep<<":"<<t.visible<<":"<<t.composition<<":"<<t.committed<<":"<<t.page<<":"<<t.highlight;
                    for(auto&v:t.candidates)std::cout<<":"<<v;std::cout<<"\n";
                }
            }
        }
    }
    return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
