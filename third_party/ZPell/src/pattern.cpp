#include "pattern.h"
#include <oniguruma.h>
#include <fstream>
#include <sstream>
#include <tao/pegtl.hpp>
#include <tao/pegtl/contrib/parse_tree.hpp>

namespace zpell {

struct PatternMatcher::Impl {
    struct CompiledPattern {
        regex_t* regex;
        bool is_exclusion;
        
        ~CompiledPattern() {
            if (regex) {
                onig_free(regex);
            }
        }
    };
    
    std::vector<CompiledPattern> compiled;
    
    ~Impl() {
        compiled.clear();
        onig_end();
    }
};

PatternMatcher::PatternMatcher() : impl_(std::make_unique<Impl>()) {
    onig_init();
}

PatternMatcher::~PatternMatcher() = default;

PatternMatcher::PatternMatcher(PatternMatcher&&) noexcept = default;
PatternMatcher& PatternMatcher::operator=(PatternMatcher&&) noexcept = default;

void PatternMatcher::add_pattern(const std::string& pattern, bool is_exclusion, char delimiter) {
    patterns_.emplace_back(pattern, is_exclusion, delimiter);
    
    // Compile regex
    regex_t* reg;
    OnigErrorInfo einfo;
    
    const UChar* pattern_str = reinterpret_cast<const UChar*>(pattern.c_str());
    int r = onig_new(&reg, pattern_str, pattern_str + pattern.length(),
                     ONIG_OPTION_DEFAULT, ONIG_ENCODING_UTF8,
                     ONIG_SYNTAX_DEFAULT, &einfo);
    
    if (r == ONIG_NORMAL) {
        Impl::CompiledPattern cp;
        cp.regex = reg;
        cp.is_exclusion = is_exclusion;
        impl_->compiled.push_back(std::move(cp));
    }
}

bool PatternMatcher::matches(const std::string& word) const {
    bool has_match = false;
    
    const UChar* str = reinterpret_cast<const UChar*>(word.c_str());
    const UChar* end = str + word.length();
    
    for (const auto& cp : impl_->compiled) {
        OnigRegion* region = onig_region_new();
        int r = onig_search(cp.regex, str, end, str, end, region, ONIG_OPTION_NONE);
        
        if (r >= 0) {
            if (cp.is_exclusion) {
                onig_region_free(region, 1);
                return false;  // Excluded
            }
            has_match = true;
        }
        
        onig_region_free(region, 1);
    }
    
    return has_match || impl_->compiled.empty();
}

void PatternMatcher::clear() {
    patterns_.clear();
    impl_->compiled.clear();
}

// PEGTL grammar for .zpell files
namespace grammar {
    using namespace tao::pegtl;
    
    struct ws : star<space> {};
    struct comment : seq<one<'#'>, until<eolf>> {};
    struct blank_line : seq<ws, opt<comment>, eol> {};
    
    struct delimiter : sor<one<'/'>, one<'|'>> {};
    struct pattern_char : not_one<'/', '|', '\n', '\r'> {};
    struct pattern_content : plus<pattern_char> {};
    
    struct exclusion_marker : one<'!'> {};
    struct pattern_line : seq<
        ws,
        opt<exclusion_marker>,
        delimiter,
        pattern_content,
        delimiter,
        ws,
        opt<comment>,
        eol
    > {};
    
    struct line : sor<blank_line, pattern_line> {};
    struct grammar : until<eof, line> {};
}

PatternMatcher DotfileParser::parse(const std::filesystem::path& path) {
    if (!std::filesystem::exists(path)) {
        return PatternMatcher();
    }
    
    std::ifstream file(path);
    std::string content((std::istreambuf_iterator<char>(file)),
                        std::istreambuf_iterator<char>());
    
    return parse_string(content);
}

PatternMatcher DotfileParser::parse_string(const std::string& content) {
    PatternMatcher matcher;
    
    // Simple line-by-line parsing
    std::istringstream stream(content);
    std::string line;
    
    while (std::getline(stream, line)) {
        // Trim whitespace
        line.erase(0, line.find_first_not_of(" \t"));
        line.erase(line.find_last_not_of(" \t\r\n") + 1);
        
        // Skip empty lines and comments
        if (line.empty() || line[0] == '#') {
            continue;
        }
        
        // Check for exclusion marker
        bool is_exclusion = false;
        if (line[0] == '!') {
            is_exclusion = true;
            line = line.substr(1);
        }
        
        // Find delimiter
        if (line.size() < 3) continue;
        
        char delim = line[0];
        if (delim != '/' && delim != '|') continue;
        
        size_t end_pos = line.find(delim, 1);
        if (end_pos == std::string::npos) continue;
        
        std::string pattern = line.substr(1, end_pos - 1);
        matcher.add_pattern(pattern, is_exclusion, delim);
    }
    
    return matcher;
}

} // namespace zpell
