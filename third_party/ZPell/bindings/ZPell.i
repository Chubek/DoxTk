%module(directors="1") ZPELL_MODULE_NAME

%{
#include "zpell-api.h"
#include "bktree.h"
#include "wordlist.h"
#include "config.h"
#include "pattern.h"
#include "cache.h"
#include <string>
#include <vector>
#include <utility>
#include <filesystem>
%}

%include "std_string.i"
%include "std_vector.i"
%include "std_pair.i"

// Template instantiations
%template(StringVector) std::vector<std::string>;
%template(SuggestionPair) std::pair<std::string, int>;
%template(SuggestionVector) std::vector<std::pair<std::string, int>>;

// Python-specific features
#ifdef SWIGPYTHON

#if defined(XFEAT_CONTEXT_MANAGER) || defined(XFEAT_CONVENIENCE_FUNCTIONS) || defined(XFEAT_EXCEPTION_HANDLING) || defined(XFEAT_DECORATORS)
%pythoncode %{
import os
import sys
from typing import List, Tuple, Optional
#if defined(XFEAT_DECORATORS)
from functools import wraps
#endif

#if defined(XFEAT_CONTEXT_MANAGER)
class ZPellContext:
    """Context manager wrapper for ZPell"""
    def __init__(self, config=None):
        self._zpell = ZPell() if config is None else ZPell(config)
        self._initialized = False
    
    def __enter__(self):
        return self._zpell
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        # Cleanup if needed
        return False
    
    def initialize(self, config):
        self._initialized = self._zpell.initialize(config)
        return self._initialized
    
    def load_wordlist(self, path):
        return self._zpell.load_wordlist(path)
    
    def check(self, word):
        return self._zpell.check(word)
    
    def suggest(self, word, max_suggestions=5):
        return self._zpell.suggest(word, max_suggestions)
    
    def load_patterns(self, path):
        return self._zpell.load_patterns(path)
#endif

#if defined(XFEAT_CONVENIENCE_FUNCTIONS)
def check_word(word: str, wordlist_path: Optional[str] = None) -> bool:
    """Convenience function to check a single word"""
    zpell = ZPell()
    if wordlist_path:
        zpell.load_wordlist(wordlist_path)
    return zpell.check(word)

def suggest_word(word: str, max_suggestions: int = 5, wordlist_path: Optional[str] = None) -> List[Tuple[str, int]]:
    """Convenience function to get suggestions for a word"""
    zpell = ZPell()
    if wordlist_path:
        zpell.load_wordlist(wordlist_path)
    return zpell.suggest(word, max_suggestions)
#endif

#if defined(XFEAT_DECORATORS)
def spellcheck(wordlist_path: Optional[str] = None):
    """Decorator to spellcheck function arguments"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            zpell = ZPell()
            if wordlist_path:
                zpell.load_wordlist(wordlist_path)
            
            # Check string arguments
            for arg in args:
                if isinstance(arg, str):
                    words = arg.split()
                    for word in words:
                        if not zpell.check(word):
                            suggestions = zpell.suggest(word, 3)
                            print(f"Warning: '{word}' may be misspelled. Suggestions: {[s[0] for s in suggestions]}")
            
            return func(*args, **kwargs)
        return wrapper
    return decorator

def autocorrect(wordlist_path: Optional[str] = None, threshold: int = 2):
    """Decorator to autocorrect function string arguments"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            zpell = ZPell()
            if wordlist_path:
                zpell.load_wordlist(wordlist_path)
            
            corrected_args = []
            for arg in args:
                if isinstance(arg, str):
                    words = arg.split()
                    corrected_words = []
                    for word in words:
                        if not zpell.check(word):
                            suggestions = zpell.suggest(word, 1)
                            if suggestions and suggestions[0][1] <= threshold:
                                corrected_words.append(suggestions[0][0])
                            else:
                                corrected_words.append(word)
                        else:
                            corrected_words.append(word)
                    corrected_args.append(' '.join(corrected_words))
                else:
                    corrected_args.append(arg)
            
            return func(*tuple(corrected_args), **kwargs)
        return wrapper
    return decorator
#endif
%}
#endif

#endif // SWIGPYTHON

// Ruby-specific features
#ifdef SWIGRUBY

#if defined(XFEAT_BLOCK_SYNTAX)
%extend zpell::ZPell {
    void with_context() {
        rb_yield(self);
    }
}

%typemap(out) std::vector<std::pair<std::string, int>> {
    $result = rb_ary_new();
    for (size_t i = 0; i < $1.size(); i++) {
        VALUE hash = rb_hash_new();
        rb_hash_aset(hash, ID2SYM(rb_intern("word")), rb_str_new2($1[i].first.c_str()));
        rb_hash_aset(hash, ID2SYM(rb_intern("distance")), INT2NUM($1[i].second));
        rb_ary_push($result, hash);
    }
}
#endif

#if defined(XFEAT_METHOD_CHAINING)
%extend zpell::ZPell {
    zpell::ZPell* chain_load_wordlist(const std::filesystem::path& path) {
        self->load_wordlist(path);
        return self;
    }
    
    zpell::ZPell* chain_load_patterns(const std::filesystem::path& path) {
        self->load_patterns(path);
        return self;
    }
}
#endif

#endif // SWIGRUBY

// Go-specific features
#ifdef SWIGGO

#if defined(XFEAT_ERROR_INTERFACE)
%insert(go_wrapper) %{
type ZPellError struct {
    Message string
}

func (e *ZPellError) Error() string {
    return e.Message
}
%}
#endif

#if defined(XFEAT_DEFER_CLEANUP)
%extend zpell::ZPell {
    void Close() {
        // Cleanup resources
    }
}
#endif

#endif // SWIGGO

// JavaScript/Node.js-specific features
#ifdef SWIGJAVASCRIPT

#if defined(XFEAT_PROMISE_API)
%insert(javascript) %{
function checkAsync(word) {
    return new Promise((resolve, reject) => {
        try {
            const result = this.check(word);
            resolve(result);
        } catch (e) {
            reject(e);
        }
    });
}

function suggestAsync(word, maxSuggestions = 5) {
    return new Promise((resolve, reject) => {
        try {
            const result = this.suggest(word, maxSuggestions);
            resolve(result);
        } catch (e) {
            reject(e);
        }
    });
}
%}
#endif

#endif // SWIGJAVASCRIPT

// C++-specific features
#ifdef SWIGCPLUSPLUS

#if defined(XFEAT_RAII_WRAPPER)
%inline %{
namespace zpell {
class ZPellRAII {
private:
    std::unique_ptr<ZPell> zpell_;
public:
    ZPellRAII() : zpell_(std::make_unique<ZPell>()) {}
    explicit ZPellRAII(const Config& config) : zpell_(std::make_unique<ZPell>(config)) {}
    ~ZPellRAII() = default;
    
    ZPellRAII(const ZPellRAII&) = delete;
    ZPellRAII& operator=(const ZPellRAII&) = delete;
    
    ZPellRAII(ZPellRAII&&) = default;
    ZPellRAII& operator=(ZPellRAII&&) = default;
    
    bool initialize(const Config& config) { return zpell_->initialize(config); }
    bool load_wordlist(const std::filesystem::path& path) { return zpell_->load_wordlist(path); }
    bool check(const std::string& word) const { return zpell_->check(word); }
    std::vector<std::pair<std::string, int>> suggest(const std::string& word, int max_suggestions = 5) const {
        return zpell_->suggest(word, max_suggestions);
    }
    bool load_patterns(const std::filesystem::path& path) { return zpell_->load_patterns(path); }
};
}
%}
#endif

#if defined(XFEAT_EXCEPTION_SAFETY)
%exception {
    try {
        $action
    } catch (const std::exception& e) {
        SWIG_exception(SWIG_RuntimeError, e.what());
    }
}
#endif

#endif // SWIGCPLUSPLUS

// Include the main API header
%include "zpell-api.h"
%include "config.h"
%include "wordlist.h"
%include "bktree.h"
%include "pattern.h"
%include "cache.h"
