# Wordlist Loading

## Default Wordlist

ZPell uses `/usr/share/dict/words` as the default wordlist on Unix systems.

## Custom Wordlists

### Format

Wordlists are plain text files with one word per line:

```
hello
world
test
example
```

### Loading via Configuration

```toml
wordlist_path = "/path/to/custom/words.txt"
```

### Loading via CLI

```bash
zpell --wordlist /path/to/words.txt check word
zpell load /path/to/words.txt
```

### Loading Programmatically

```cpp
zpell::ZPell zpell;
zpell.load_wordlist("/path/to/words.txt");
```

## Multiple Wordlists

Load multiple wordlists by calling `load_wordlist` multiple times:

```cpp
zpell.load_wordlist("/usr/share/dict/words");
zpell.load_wordlist("/custom/technical-terms.txt");
zpell.load_wordlist("/custom/names.txt");
```

## Wordlist Sources

### System Dictionaries
- Linux: `/usr/share/dict/words`
- macOS: `/usr/share/dict/words`
- Windows: Custom installation required

### Online Sources
- [SCOWL](http://wordlist.aspell.net/) - Spell Checker Oriented Word Lists
- [Hunspell Dictionaries](https://github.com/wooorm/dictionaries)
- [WordNet](https://wordnet.princeton.edu/)

## Performance Considerations

### Large Wordlists

For wordlists with >100k words:
1. Enable caching to avoid rebuilding BK-Tree
2. Consider splitting into multiple specialized lists
3. Use memory-mapped files for very large datasets

### Caching

```toml
[cache]
enable = true
path = "~/.cache/zpell/cache.mdb"
```

First load builds the BK-Tree and caches it. Subsequent loads are instant.

## Creating Custom Wordlists

### From Text Corpus

```bash
# Extract unique words
cat corpus.txt | tr '[:space:]' '\n' | sort -u > wordlist.txt

# Filter by length
awk 'length($0) >= 3' wordlist.txt > filtered.txt

# Remove non-alphabetic
grep '^[a-zA-Z]*$' wordlist.txt > clean.txt
```

### Domain-Specific Lists

Create specialized wordlists for:
- Programming terms
- Medical terminology
- Legal vocabulary
- Technical jargon
- Proper names

## Wordlist Maintenance

### Updating

```bash
# Backup current
cp words.txt words.txt.bak

# Add new words
cat new_words.txt >> words.txt
sort -u words.txt -o words.txt

# Reload in ZPell
zpell load words.txt
```

### Validation

```bash
# Check for duplicates
sort words.txt | uniq -d

# Check for empty lines
grep -n '^$' words.txt

# Check encoding
file -i words.txt
```
