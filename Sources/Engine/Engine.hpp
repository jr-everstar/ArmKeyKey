#pragma once
#include <memory>
#include <string>
#include <vector>
namespace armkeykey {
enum class InputMode { Cangjie3, Cangjie5, Simplex, Jyutping, Zhuyin, SmartZhuyin };
enum class CharacterSet { Compatible, FullUnicode };
struct Key { unsigned code; std::string text; unsigned modifiers=0; };
struct State {
    bool handled=false, beep=false, visible=false, associated=false;
    std::string composition, committed;
    std::vector<std::string> candidates;
    size_t page=0, pageSize=9, highlight=0;
    // UTF-8 byte offsets; npos means caret at end (legacy modes).
    size_t selectionStart=std::string::npos, selectionLength=0;
};
class JyutpingEngine;
class ZhuyinEngine;
class Engine {
public:
    Engine(const std::string& dictionary, const std::string& userDirectory, InputMode mode, bool learning, CharacterSet characters = CharacterSet::Compatible, const std::string& phrases = "", const std::string& cantonese = "", unsigned phraseModifier = 8, const std::string& mandarin = "");
    // Source compatibility for existing legacy-engine differential fixtures.
    Engine(const std::string& dictionary, const std::string& userDirectory, bool simplex, bool learning, CharacterSet characters = CharacterSet::Compatible, const std::string& phrases = "", const std::string& cantonese = "", unsigned phraseModifier = 8);
    ~Engine();
    State process(const Key& key);
    State select(size_t index);
    void reset();
    State finish();
private:
    unsigned phraseModifier;
    struct Impl;
    std::unique_ptr<Impl> impl;
    std::unique_ptr<JyutpingEngine> jyutping;
    std::unique_ptr<ZhuyinEngine> zhuyin;
};
}
