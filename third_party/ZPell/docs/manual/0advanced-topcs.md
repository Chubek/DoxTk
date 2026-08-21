# Advanced Topics

## Performance Tuning

### BK-Tree Optimization

The BK-Tree performance depends on:
1. **Word order**: Insert common words first
2. **Tree balance**: Random insertion order improves balance
3. **Distance threshold**: Lower thresholds = faster searches

```cpp
// Optimize insertion order
std::vector<std::string> words = load_words();
std::shuffle(words.begin(), words.end(), rng);

for (const auto& word : words) {
    tree.insert(word);
}
```

### Caching Strategy

```toml
[cache]
enable = true
path = "~/.cache/zpell/cache.mdb"
```

Benefits:
- First load: ~5s for 100k words
- Cached load: ~50ms
- 100x speedup

### Memory Usage

| Component | Memory per 100k words |
|-----------|----------------------|
| BK-Tree   | ~10 MB              |
| Cache     | ~5 MB               |
| Patterns  | ~1 MB               |
| Total     | ~16 MB              |

## Large Dictionary Handling

### Splitting Dictionaries

```bash
# Split by first letter
for letter in {a..z}; do
    grep "^$letter" words.txt > words_$letter.txt
done
```

```cpp
// Load selectively
zpell.load_wordlist("words_" + first_letter + ".txt");
```

### Memory-Mapped Files

For dictionaries >1M words, use memory mapping:

```cpp
#include <sys/mman.h>

void* map_wordlist(const char* path) {
    int fd = open(path, O_RDONLY);
    struct stat sb;
    fstat(fd, &sb);
    
    void* addr = mmap(NULL, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    
    return addr;
}
```

## Multi-Language Support

### Language Detection

```cpp
class MultiLangChecker {
    std::map<std::string, zpell::ZPell> checkers;
    
public:
    void add_language(const std::string& lang, const std::string& wordlist) {
        zpell::ZPell checker;
        checker.load_wordlist(wordlist);
        checkers[lang] = std::move(checker);
    }
    
    bool check(const std::string& word, const std::string& lang) {
        return checkers[lang].check(word);
    }
};
```

### Unicode Handling

ZPell uses UTF-8 throughout:

```cpp
// Normalize Unicode
#include <unicode/normalizer2.h>

std::string normalize(const std::string& word) {
    UErrorCode status = U_ZERO_ERROR;
    const Normalizer2* nfc = Normalizer2::getNFCInstance(status);
    
    UnicodeString ustr = UnicodeString::fromUTF8(word);
    UnicodeString normalized;
    nfc->normalize(ustr, normalized, status);
    
    std::string result;
    normalized.toUTF8String(result);
    return result;
}
```

## Custom Distance Metrics

### Phonetic Distance

```cpp
#include <metaphone.h>

int phonetic_distance(const std::string& a, const std::string& b) {
    std::string pa = metaphone(a);
    std::string pb = metaphone(b);
    return edit_distance(pa, pb);
}
```

### Keyboard Distance

```cpp
// QWERTY keyboard layout
std::map<char, std::pair<int, int>> keyboard = {
    {'q', {0, 0}}, {'w', {0, 1}}, {'e', {0, 2}}, // ...
};

int keyboard_distance(char a, char b) {
    auto [ax, ay] = keyboard[a];
    auto [bx, by] = keyboard[b];
    return abs(ax - bx) + abs(ay - by);
}
```

## Parallel Processing

### Multi-threaded Checking

```cpp
#include <thread>
#include <future>

std::vector<bool> check_words_parallel(
    const zpell::ZPell& zpell,
    const std::vector<std::string>& words
) {
    std::vector<std::future<bool>> futures;
    
    for (const auto& word : words) {
        futures.push_back(std::async(std::launch::async, 
            [&zpell, word]() { return zpell.check(word); }
        ));
    }
    
    std::vector<bool> results;
    for (auto& future : futures) {
        results.push_back(future.get());
    }
    
    return results;
}
```

## Profiling

### Timing Measurements

```cpp
#include <chrono>

auto start = std::chrono::high_resolution_clock::now();

// Operation to measure
zpell.check("word");

auto end = std::chrono::high_resolution_clock::now();
auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);

std::cout << "Time: " << duration.count() << "μs\n";
```

### Memory Profiling

```bash
# Valgrind
valgrind --tool=massif zpell check word

# Analyze
ms_print massif.out.*
```

## Integration Examples

### Vim Plugin

```vim
function! ZPellCheck()
    let word = expand('<cword>')
    let result = system('zpell check ' . shellescape(word))
    if v:shell_error
        echo 'Misspelled: ' . word
    else
        echo 'Correct: ' . word
    endif
endfunction

nnoremap <leader>s :call ZPellCheck()<CR>
```

### Git Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Check commit message
zpell check "$(git log -1 --pretty=%B)" || {
    echo "Commit message has spelling errors"
    exit 1
}
```

### CI/CD Integration

```yaml
# .github/workflows/spell-check.yml
name: Spell Check

on: [push, pull_request]

jobs:
  spell-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install ZPell
        run: |
          wget https://github.com/zpell/releases/latest/zpell.deb
          sudo dpkg -i zpell.deb
      - name: Check spelling
        run: |
          find . -name "*.md" -exec zpell check {} \;
```
