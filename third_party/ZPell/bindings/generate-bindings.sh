#!/usr/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST_FILE="$PROJECT_ROOT/manifests/XFeats.json"

# Default values
LANGUAGE=""
BINDING_NAME=""
OUTPUT_DIR=""
XFEATS=()

# Usage function
usage() {
    cat << USAGE
Usage: $0 <language> [options]

Generate SWIG bindings for ZPell

Arguments:
    <language>          Target language (python, ruby, go, javascript, cpp)

Options:
    --name NAME         Name of the binding (default: <language>-zpell)
    --output DIR        Output directory (default: ./<binding-name>)
    --xfeats FEATURES   Comma-separated list of XFeats to enable
                        Prefix with + to enable (e.g., +context_manager)
                        Use 'all' to enable all features for the language

Examples:
    $0 python --name pyzpell --xfeats +context_manager,+decorators
    $0 ruby --name gemzpell --xfeats +block_syntax --output ~/gemzpell
    $0 go --xfeats all
    $0 javascript --name nodezpell --xfeats +promise_api,+typescript_defs

USAGE
    exit 1
}

# Parse arguments
if [[ $# -lt 1 ]]; then
    usage
fi

LANGUAGE="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            BINDING_NAME="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --xfeats)
            IFS=',' read -ra XFEATS <<< "$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            ;;
    esac
done

# Validate language
case "$LANGUAGE" in
    python|ruby|go|javascript|cpp)
        ;;
    *)
        echo -e "${RED}Error: Unsupported language '$LANGUAGE'${NC}"
        echo "Supported languages: python, ruby, go, javascript, cpp"
        exit 1
        ;;
esac

# Set default binding name
if [[ -z "$BINDING_NAME" ]]; then
    BINDING_NAME="${LANGUAGE}-zpell"
fi

# Set default output directory
if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(pwd)/$BINDING_NAME"
fi

# Check if manifest exists
if [[ ! -f "$MANIFEST_FILE" ]]; then
    echo -e "${RED}Error: XFeats manifest not found at $MANIFEST_FILE${NC}"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed${NC}"
    exit 1
fi

# Check if swig is available
if ! command -v swig &> /dev/null; then
    echo -e "${RED}Error: SWIG is required but not installed${NC}"
    exit 1
fi

echo -e "${GREEN}Generating $LANGUAGE bindings: $BINDING_NAME${NC}"
echo "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Parse XFeats from manifest
AVAILABLE_XFEATS=$(jq -r ".${LANGUAGE}[].name" "$MANIFEST_FILE" 2>/dev/null || echo "")

if [[ -z "$AVAILABLE_XFEATS" ]]; then
    echo -e "${YELLOW}Warning: No XFeats available for $LANGUAGE${NC}"
fi

# Process XFeats
ENABLED_XFEATS=()
SWIG_DEFINES=()
SWIG_EXTRA_FLAGS=()

if [[ ${#XFEATS[@]} -gt 0 ]]; then
    for xfeat in "${XFEATS[@]}"; do
        # Remove leading +
        xfeat="${xfeat#+}"
        
        if [[ "$xfeat" == "all" ]]; then
            echo "Enabling all XFeats for $LANGUAGE"
            while IFS= read -r feat; do
                ENABLED_XFEATS+=("$feat")
            done <<< "$AVAILABLE_XFEATS"
        else
            # Check if XFeat exists
            if echo "$AVAILABLE_XFEATS" | grep -q "^${xfeat}$"; then
                ENABLED_XFEATS+=("$xfeat")
            else
                echo -e "${YELLOW}Warning: XFeat '$xfeat' not available for $LANGUAGE${NC}"
            fi
        fi
    done
fi

# Build SWIG defines and flags
for xfeat in "${ENABLED_XFEATS[@]}"; do
    # Convert to uppercase for preprocessor define
    xfeat_upper=$(echo "$xfeat" | tr '[:lower:]' '[:upper:]')
    SWIG_DEFINES+=("-DXFEAT_${xfeat_upper}")
    
    # Get SWIG flags from manifest
    flags=$(jq -r ".${LANGUAGE}[] | select(.name==\"${xfeat}\") | .swig_flags[]" "$MANIFEST_FILE" 2>/dev/null || echo "")
    if [[ -n "$flags" ]]; then
        while IFS= read -r flag; do
            if [[ -n "$flag" ]]; then
                SWIG_EXTRA_FLAGS+=("$flag")
            fi
        done <<< "$flags"
    fi
done

# Remove duplicate flags
SWIG_EXTRA_FLAGS=($(printf "%s\n" "${SWIG_EXTRA_FLAGS[@]}" | sort -u))

echo "Enabled XFeats: ${ENABLED_XFEATS[*]:-none}"

# Language-specific SWIG options
case "$LANGUAGE" in
    python)
        SWIG_LANG="-python"
        SWIG_LANG_FLAGS=("-py3" "-c++")
        WRAPPER_EXT="cxx"
        ;;
    ruby)
        SWIG_LANG="-ruby"
        SWIG_LANG_FLAGS=("-c++")
        WRAPPER_EXT="cxx"
        ;;
    go)
        SWIG_LANG="-go"
        SWIG_LANG_FLAGS=("-c++" "-intgosize" "64")
        WRAPPER_EXT="cxx"
        ;;
    javascript)
        SWIG_LANG="-javascript"
        SWIG_LANG_FLAGS=("-node" "-c++")
        WRAPPER_EXT="cxx"
        ;;
    cpp)
        SWIG_LANG="-c++"
        SWIG_LANG_FLAGS=()
        WRAPPER_EXT="cxx"
        ;;
esac

# Build SWIG command
SWIG_CMD=(
    swig
    "$SWIG_LANG"
    "${SWIG_LANG_FLAGS[@]}"
    "${SWIG_EXTRA_FLAGS[@]}"
    "${SWIG_DEFINES[@]}"
    -DZPELL_MODULE_NAME="$BINDING_NAME"
    -I"$PROJECT_ROOT/include"
    -outdir "$OUTPUT_DIR"
    -o "$OUTPUT_DIR/${BINDING_NAME}_wrap.${WRAPPER_EXT}"
    "$SCRIPT_DIR/ZPell.i"
)

echo -e "${GREEN}Running SWIG...${NC}"
echo "Command: ${SWIG_CMD[*]}"

if "${SWIG_CMD[@]}"; then
    echo -e "${GREEN}✓ SWIG wrapper generated successfully${NC}"
else
    echo -e "${RED}✗ SWIG generation failed${NC}"
    exit 1
fi

# Generate installation machinery
echo -e "${GREEN}Generating installation machinery...${NC}"

case "$LANGUAGE" in
    python)
        cat > "$OUTPUT_DIR/setup.py" << PYSETUP
#!/usr/bin/env python3
from setuptools import setup, Extension
import os

# Get the project root
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))

module = Extension(
    '_${BINDING_NAME}',
    sources=['${BINDING_NAME}_wrap.cxx'],
    include_dirs=[
        os.path.join(project_root, 'include'),
        os.path.join(project_root, 'third_party'),
    ],
    library_dirs=[
        os.path.join(project_root, 'build'),
    ],
    libraries=['zpelltree'],
    extra_compile_args=['-std=c++20'],
    language='c++'
)

setup(
    name='${BINDING_NAME}',
    version='0.1.0',
    description='Python bindings for ZPell spellchecker',
    author='ZPell Contributors',
    ext_modules=[module],
    py_modules=['${BINDING_NAME}'],
    python_requires='>=3.7',
)
PYSETUP
        
        cat > "$OUTPUT_DIR/README.md" << PYREADME
# ${BINDING_NAME}

Python bindings for ZPell spellchecker.

## Installation

\`\`\`bash
python setup.py build
python setup.py install
\`\`\`

## Usage

\`\`\`python
import ${BINDING_NAME}

# Create ZPell instance
zpell = ${BINDING_NAME}.ZPell()
zpell.load_wordlist("/usr/share/dict/words")

# Check spelling
if zpell.check("hello"):
    print("Correct!")

# Get suggestions
suggestions = zpell.suggest("helo", 5)
for word, distance in suggestions:
    print(f"{word} (distance: {distance})")
\`\`\`

## Enabled XFeats

${ENABLED_XFEATS[*]:-none}
PYREADME
        ;;
        
    ruby)
        cat > "$OUTPUT_DIR/extconf.rb" << RBCONF
require 'mkmf'

project_root = File.expand_path('..', __dir__)

\$CXXFLAGS << ' -std=c++20'
\$INCFLAGS << " -I#{project_root}/include"
\$INCFLAGS << " -I#{project_root}/third_party"

dir_config('zpell', "#{project_root}/include", "#{project_root}/build")

have_library('zpelltree') or raise 'libzpelltree not found'

create_makefile('${BINDING_NAME}')
RBCONF

        cat > "$OUTPUT_DIR/${BINDING_NAME}.gemspec" << GEMSPEC
Gem::Specification.new do |s|
  s.name        = '${BINDING_NAME}'
  s.version     = '0.1.0'
  s.summary     = 'Ruby bindings for ZPell spellchecker'
  s.description = 'Fast spellchecking using BK-trees'
  s.authors     = ['ZPell Contributors']
  s.files       = ['${BINDING_NAME}_wrap.cxx', 'extconf.rb']
  s.extensions  = ['extconf.rb']
  s.required_ruby_version = '>= 2.5'
end
GEMSPEC

        cat > "$OUTPUT_DIR/README.md" << RBREADME
# ${BINDING_NAME}

Ruby bindings for ZPell spellchecker.

## Installation

\`\`\`bash
gem build ${BINDING_NAME}.gemspec
gem install ${BINDING_NAME}-0.1.0.gem
\`\`\`

## Usage

\`\`\`ruby
require '${BINDING_NAME}'

zpell = ${BINDING_NAME}::ZPell.new
zpell.load_wordlist("/usr/share/dict/words")

puts zpell.check("hello") ? "Correct!" : "Incorrect"

suggestions = zpell.suggest("helo", 5)
suggestions.each do |s|
  puts "#{s[:word]} (distance: #{s[:distance]})"
end
\`\`\`

## Enabled XFeats

${ENABLED_XFEATS[*]:-none}
RBREADME
        ;;
        
    go)
        cat > "$OUTPUT_DIR/go.mod" << GOMOD
module ${BINDING_NAME}

go 1.18
GOMOD

        cat > "$OUTPUT_DIR/README.md" << GOREADME
# ${BINDING_NAME}

Go bindings for ZPell spellchecker.

## Installation

\`\`\`bash
go build
\`\`\`

## Usage

\`\`\`go
package main

import (
    "${BINDING_NAME}"
)

func main() {
    zpell := ${BINDING_NAME}.NewZPell()
    zpell.Load_wordlist("/usr/share/dict/words")
    
    if zpell.Check("hello") {
        println("Correct!")
    }
    
    suggestions := zpell.Suggest("helo", 5)
    // Process suggestions
}
\`\`\`

## Enabled XFeats

${ENABLED_XFEATS[*]:-none}
GOREADME
        ;;
        
    javascript)
        cat > "$OUTPUT_DIR/package.json" << JSPACKAGE
{
  "name": "${BINDING_NAME}",
  "version": "0.1.0",
  "description": "Node.js bindings for ZPell spellchecker",
  "main": "${BINDING_NAME}.node",
  "scripts": {
    "install": "node-gyp rebuild"
  },
  "gypfile": true,
  "dependencies": {
    "node-gyp": "^9.0.0"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
JSPACKAGE

        cat > "$OUTPUT_DIR/binding.gyp" << GYP
{
  "targets": [
    {
      "target_name": "${BINDING_NAME}",
      "sources": ["${BINDING_NAME}_wrap.cxx"],
      "include_dirs": [
        "../include",
        "../third_party"
      ],
      "libraries": [
        "-L../build",
        "-lzpelltree"
      ],
      "cflags_cc": ["-std=c++20"],
      "xcode_settings": {
        "OTHER_CFLAGS": ["-std=c++20"]
      }
    }
  ]
}
GYP

        cat > "$OUTPUT_DIR/README.md" << JSREADME
# ${BINDING_NAME}

Node.js bindings for ZPell spellchecker.

## Installation

\`\`\`bash
npm install
\`\`\`

## Usage

\`\`\`javascript
const zpell = require('${BINDING_NAME}');

const checker = new zpell.ZPell();
checker.load_wordlist('/usr/share/dict/words');

if (checker.check('hello')) {
    console.log('Correct!');
}

const suggestions = checker.suggest('helo', 5);
suggestions.forEach(([word, distance]) => {
    console.log(\`\${word} (distance: \${distance})\`);
});
\`\`\`

## Enabled XFeats

${ENABLED_XFEATS[*]:-none}
JSREADME
        ;;
        
    cpp)
        cat > "$OUTPUT_DIR/CMakeLists.txt" << CMAKEFILE
cmake_minimum_required(VERSION 3.15)
project(${BINDING_NAME})

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include_directories(
    \${CMAKE_SOURCE_DIR}/../include
    \${CMAKE_SOURCE_DIR}/../third_party
)

add_library(${BINDING_NAME} SHARED
    ${BINDING_NAME}_wrap.cxx
)

target_link_libraries(${BINDING_NAME}
    zpelltree
)
CMAKEFILE

        cat > "$OUTPUT_DIR/README.md" << CPPREADME
# ${BINDING_NAME}

C++ bindings for ZPell spellchecker.

## Building

\`\`\`bash
mkdir build && cd build
cmake ..
make
\`\`\`

## Usage

\`\`\`cpp
#include "${BINDING_NAME}.h"

int main() {
    zpell::ZPell checker;
    checker.load_wordlist("/usr/share/dict/words");
    
    if (checker.check("hello")) {
        std::cout << "Correct!" << std::endl;
    }
    
    auto suggestions = checker.suggest("helo", 5);
    for (const auto& [word, distance] : suggestions) {
        std::cout << word << " (distance: " << distance << ")" << std::endl;
    }
    
    return 0;
}
\`\`\`

## Enabled XFeats

${ENABLED_XFEATS[*]:-none}
CPPREADME
        ;;
esac

echo -e "${GREEN}✓ Installation machinery generated${NC}"
echo ""
echo -e "${GREEN}Binding generation complete!${NC}"
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Next steps:"
case "$LANGUAGE" in
    python)
        echo "  cd $OUTPUT_DIR"
        echo "  python setup.py build"
        echo "  python setup.py install"
        ;;
    ruby)
        echo "  cd $OUTPUT_DIR"
        echo "  gem build ${BINDING_NAME}.gemspec"
        echo "  gem install ${BINDING_NAME}-0.1.0.gem"
        ;;
    go)
        echo "  cd $OUTPUT_DIR"
        echo "  go build"
        ;;
    javascript)
        echo "  cd $OUTPUT_DIR"
        echo "  npm install"
        ;;
    cpp)
        echo "  cd $OUTPUT_DIR"
        echo "  mkdir build && cd build"
        echo "  cmake .. && make"
        ;;
esac
