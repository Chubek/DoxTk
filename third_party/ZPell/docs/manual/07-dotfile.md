# Dotfile (.zpell)

## Overview

The `.zpell` dotfile defines pattern matching rules for spell checking. It uses regex patterns to include or exclude words.

## Syntax

### Basic Pattern

```
/pattern/
```

### Exclusion Pattern

```
!/pattern/
```

### Alternative Delimiter

```
|pattern|
```

## Examples

### Simple Patterns

```zpell
# Allow all test-related words
/test.*/

# Allow version numbers
/v\d+\.\d+\.\d+/

# Allow hex colors
/#[0-9a-fA-F]{6}/
```

### Exclusions

```zpell
# Allow all words
/.*/

# But exclude profanity
!/bad.*/
!/offensive.*/
```

### Comments

```zpell
# This is a comment
# Comments start with #

/pattern/  # Inline comments are also supported
```

## Use Cases

### Code Identifiers

```zpell
# Allow camelCase
/[a-z]+([A-Z][a-z]+)*/

# Allow snake_case
/[a-z]+(_[a-z]+)*/

# Allow SCREAMING_SNAKE_CASE
/[A-Z]+(_[A-Z]+)*/
```

### URLs and Emails

```zpell
# Allow URLs
|https?://[^\s]+|

# Allow email addresses
|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}|
```

### File Paths

```zpell
# Allow Unix paths
|/[a-zA-Z0-9/_.-]+|

# Allow Windows paths
|[A-Z]:\\[a-zA-Z0-9\\._-]+|
```

### Technical Terms

```zpell
# Allow common programming terms
/API|HTTP|JSON|XML|SQL/

# Allow version control terms
/git|commit|branch|merge|pull|push/
```

## Loading Dotfiles

### Via Configuration

```toml
dotfile_path = "~/.zpell"
```

### Programmatically

```cpp
zpell::ZPell zpell;
zpell.load_patterns("~/.zpell");
```

## Multiple Dotfiles

Load project-specific patterns:

```bash
# Global patterns
zpell --config ~/.config/zpell/Config.toml

# Project patterns
zpell load-patterns ./.zpell
```

## Pattern Priority

1. Exclusion patterns take precedence
2. Later patterns override earlier ones
3. More specific patterns override general ones

## Regex Syntax

ZPell uses Oniguruma regex engine, which supports:

- POSIX character classes: `[[:alpha:]]`, `[[:digit:]]`
- Unicode properties: `\p{L}`, `\p{N}`
- Lookahead/lookbehind: `(?=...)`, `(?<=...)`
- Named groups: `(?<name>...)`

## Best Practices

1. **Start Specific**: Begin with specific patterns, add general ones later
2. **Test Patterns**: Verify patterns match expected words
3. **Document**: Add comments explaining complex patterns
4. **Version Control**: Keep `.zpell` in version control
5. **Project-Specific**: Use per-project dotfiles for custom terms

## Example: Complete Dotfile

```zpell
# .zpell - Project spell checking rules

# Allow all dictionary words by default
/.*/

# Exclude common typos
!/teh/
!/recieve/
!/seperate/

# Allow project-specific terms
/ZPell/
/BKTree/
/libmdbx/

# Allow code identifiers
/[a-z]+([A-Z][a-z]+)*/
/[a-z]+(_[a-z]+)*/

# Allow version numbers
/v?\d+\.\d+(\.\d+)?/

# Allow URLs
|https?://[^\s]+|

# Allow file extensions
/\.[a-z]{2,4}$/
```
