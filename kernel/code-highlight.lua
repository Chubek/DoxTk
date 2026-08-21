-- kernel/code-highlight.lua
-- Syntax-highlights code blocks using tree-sitter.

local kernel = {}

function kernel.advertise()
  return {
    name = "code-highlight",
    description = "Syntax-highlights code blocks using tree-sitter.",
    capabilities = {
      {
        name = "text.highlight",
        version = "1.0.0",
        inputs = {
          ir = "table",
          theme = "string"
        },
        outputs = {
          ir = "table"
        },
        services = { "treesitter.parse" }
      }
    }
  }
end

local function highlight_code(source, language, theme)
  theme = theme or "default"

  if treesitter and treesitter.parse then
    local result = treesitter.parse(source, language)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: keyword-based highlighting
  local keywords = {
    lua = { "function", "end", "if", "then", "else", "elseif", "for", "while", "do", "return", "local", "nil", "true", "false", "and", "or", "not", "break", "goto", "repeat", "until", "in" },
    python = { "def", "class", "if", "elif", "else", "for", "while", "return", "import", "from", "as", "try", "except", "finally", "raise", "with", "yield", "lambda", "pass", "break", "continue", "and", "or", "not", "is", "in", "None", "True", "False" },
    javascript = { "function", "var", "let", "const", "if", "else", "for", "while", "do", "return", "class", "new", "this", "try", "catch", "finally", "throw", "async", "await", "import", "export", "default", "from", "typeof", "instanceof", "null", "undefined", "true", "false" },
    c = { "if", "else", "for", "while", "do", "return", "switch", "case", "break", "continue", "goto", "int", "float", "double", "char", "void", "struct", "union", "enum", "typedef", "static", "const", "extern", "sizeof", "NULL", "true", "false" },
    cpp = { "if", "else", "for", "while", "do", "return", "switch", "case", "break", "continue", "goto", "class", "namespace", "template", "typename", "virtual", "override", "public", "private", "protected", "static", "const", "constexpr", "auto", "nullptr", "true", "false" }
  }

  local lang_keywords = keywords[language:lower()] or keywords.lua

  local tokens = {}
  local pos = 1
  local len = #source

  while pos <= len do
    -- Strings
    local quote = source:sub(pos, pos)
    if quote == '"' or quote == "'" then
      local end_pos = pos + 1
      while end_pos <= len do
        if source:sub(end_pos, end_pos) == "\\" then
          end_pos = end_pos + 2
        elseif source:sub(end_pos, end_pos) == quote then
          break
        else
          end_pos = end_pos + 1
        end
      end
      if end_pos > len then end_pos = len end
      tokens[#tokens + 1] = { type = "string", start = pos, len = end_pos - pos + 1 }
      pos = end_pos + 1
    -- Comments
    elseif source:sub(pos, pos + 1) == "--" then
      local end_pos = source:find("\n", pos, true)
      if not end_pos then end_pos = len end
      tokens[#tokens + 1] = { type = "comment", start = pos, len = end_pos - pos + 1 }
      pos = end_pos + 1
    elseif source:sub(pos, pos + 1) == "//" then
      local end_pos = source:find("\n", pos, true)
      if not end_pos then end_pos = len end
      tokens[#tokens + 1] = { type = "comment", start = pos, len = end_pos - pos + 1 }
      pos = end_pos + 1
    -- Numbers
    elseif source:sub(pos, pos):match("%d") then
      local end_pos = pos
      while end_pos <= len and source:sub(end_pos, end_pos):match("[%d%.xXa-fA-F]") do
        end_pos = end_pos + 1
      end
      tokens[#tokens + 1] = { type = "number", start = pos, len = end_pos - pos }
      pos = end_pos
    -- Identifiers/keywords
    elseif source:sub(pos, pos):match("[%a_]") then
      local end_pos = pos
      while end_pos <= len and source:sub(end_pos, end_pos):match("[%w_]") do
        end_pos = end_pos + 1
      end
      local word = source:sub(pos, end_pos - 1)
      local is_keyword = false
      for _, kw in ipairs(lang_keywords) do
        if word == kw then
          is_keyword = true
          break
        end
      end
      tokens[#tokens + 1] = { type = is_keyword and "keyword" or "identifier", start = pos, len = end_pos - pos }
      pos = end_pos
    else
      pos = pos + 1
    end
  end

  return { tokens = tokens, language = language, theme = theme }
end

kernel["text.highlight"] = function(inputs)
  local ir = inputs.ir
  local theme = inputs.theme or "default"

  if not ir or not ir.nodes then
    return { ir = ir }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "code_block" and node.content then
      local language = (node.attributes and node.attributes.language) or "lua"
      local tokens = highlight_code(node.content, language, theme)
      node.attributes = node.attributes or {}
      node.attributes.highlight_tokens = tokens.tokens
      node.attributes.highlight_language = tokens.language
    end
  end

  return { ir = ir }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
