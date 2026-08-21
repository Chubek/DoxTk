-- kernel/spellcheck.lua
-- Produces diagnostic spelling annotations. MUST NOT mutate text nodes.

local kernel = {}

function kernel.advertise()
  return {
    name = "spellcheck",
    description = "Produces diagnostic spelling annotations without mutating text nodes.",
    capabilities = {
      {
        name = "text.spellcheck",
        version = "1.0.0",
        inputs = {
          ir = "table",
          language = "string",
          dictionary = "string"
        },
        outputs = {
          ir = "table",
          diagnostics = "table"
        },
        services = { "hunspell.check" }
      }
    }
  }
end

local function extract_words(text)
  local words = {}
  local pos = 1
  for word in text:gmatch("%a+") do
    local start_pos = text:find(word, pos, true)
    if start_pos then
      words[#words + 1] = {
        word = word,
        start = start_pos,
        len = #word
      }
      pos = start_pos + #word
    end
  end
  return words
end

local function check_spelling(text, language, dictionary)
  language = language or "en_US"
  local words = extract_words(text)
  local misspelled = {}

  if hunspell and hunspell.check then
    for _, w in ipairs(words) do
      local result = hunspell.check(w.word, language, dictionary)
      if result and not result.correct then
        misspelled[#misspelled + 1] = {
          word = w.word,
          start = w.start,
          len = w.len,
          suggestions = result.suggestions or {}
        }
      end
    end
    return misspelled
  end

  -- Pure-Lua fallback: flag words not in common dictionary
  local common_words = {
    ["the"] = true, ["be"] = true, ["to"] = true, ["of"] = true, ["and"] = true,
    ["a"] = true, ["in"] = true, ["that"] = true, ["have"] = true, ["it"] = true,
    ["for"] = true, ["not"] = true, ["on"] = true, ["with"] = true, ["as"] = true,
    ["do"] = true, ["at"] = true, ["this"] = true, ["but"] = true, ["by"] = true,
    ["from"] = true, ["they"] = true, ["we"] = true, ["say"] = true, ["or"] = true,
    ["an"] = true, ["will"] = true, ["my"] = true, ["one"] = true, ["all"] = true,
    ["would"] = true, ["there"] = true, ["their"] = true, ["what"] = true, ["so"] = true,
    ["up"] = true, ["out"] = true, ["if"] = true, ["about"] = true, ["who"] = true,
    ["get"] = true, ["which"] = true, ["go"] = true, ["me"] = true, ["when"] = true,
    ["make"] = true, ["can"] = true, ["like"] = true, ["time"] = true, ["no"] = true,
    ["just"] = true, ["him"] = true, ["know"] = true, ["take"] = true, ["people"] = true,
    ["into"] = true, ["year"] = true, ["your"] = true, ["good"] = true, ["some"] = true,
    ["could"] = true, ["them"] = true, ["see"] = true, ["other"] = true, ["than"] = true,
    ["then"] = true, ["now"] = true, ["look"] = true, ["only"] = true, ["come"] = true,
    ["its"] = true, ["over"] = true, ["think"] = true, ["also"] = true, ["back"] = true,
    ["after"] = true, ["use"] = true, ["two"] = true, ["how"] = true, ["our"] = true,
    ["work"] = true, ["first"] = true, ["well"] = true, ["way"] = true, ["even"] = true,
    ["new"] = true, ["want"] = true, ["because"] = true, ["any"] = true, ["these"] = true,
    ["give"] = true, ["day"] = true, ["most"] = true, ["us"] = true
  }

  for _, w in ipairs(words) do
    local lower = w.word:lower()
    if not common_words[lower] then
      misspelled[#misspelled + 1] = {
        word = w.word,
        start = w.start,
        len = w.len,
        suggestions = {}
      }
    end
  end

  return misspelled
end

kernel["text.spellcheck"] = function(inputs)
  local ir = inputs.ir
  local language = inputs.language or "en_US"
  local dictionary = inputs.dictionary
  local diagnostics = {}

  if not ir or not ir.nodes then
    return { ir = ir, diagnostics = diagnostics }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and node.content then
      local misspelled = check_spelling(node.content, language, dictionary)
      if #misspelled > 0 then
        diagnostics[node_id] = {
          misspelled = misspelled,
          language = language
        }
      end
    end
  end

  return { ir = ir, diagnostics = diagnostics }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
