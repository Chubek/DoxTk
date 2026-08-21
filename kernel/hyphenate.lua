-- kernel/hyphenate.lua
-- Inserts hyphenation opportunities into text nodes.

local kernel = {}

function kernel.advertise()
  return {
    name = "hyphenate",
    description = "Inserts hyphenation opportunities into text nodes.",
    capabilities = {
      {
        name = "text.hyphenate",
        version = "1.1.0",
        inputs = {
          ir = "table",
          language = "string"
        },
        outputs = {
          ir = "table"
        }
      }
    }
  }
end

local HYPHEN_PATTERNS = {
  "tion", "sion", "ment", "ness", "able", "ible", "tive", "sive",
  "ance", "ence", "ship", "hood", "less", "ful", "ous",
  "ing", "ture", "cial", "cian", "cious", "tious",
  "graph", "phone", "scope", "meter", "gram"
}

local function hyphenate_word(word)
  if #word <= 4 then
    return word
  end

  local result = word
  for _, pattern in ipairs(HYPHEN_PATTERNS) do
    local start_pos = 2
    while true do
      local pos = result:find(pattern, start_pos, true)
      if not pos then
        break
      end
      local before = result:sub(pos - 1, pos - 1)
      local after_pos = pos + #pattern
      local after = result:sub(after_pos, after_pos)
      if before:match("[a-z]") and after:match("[a-z]") then
        local insert_pos = pos + #pattern - 1
        if insert_pos < #result then
          result = result:sub(1, insert_pos) .. "\u{00AD}" .. result:sub(insert_pos + 1)
        end
      end
      start_pos = pos + #pattern + 1
    end
  end

  return result
end

local function hyphenate_text(text)
  local words = {}
  for word in text:gmatch("%S+") do
    words[#words + 1] = hyphenate_word(word)
  end

  local result = text
  local i = 1
  local function replacer(match)
    local w = words[i]
    i = i + 1
    return w
  end
  result = result:gsub("%S+", replacer)
  return result
end

local function process_node(node)
  if type(node) ~= "table" then
    return node
  end

  if node.content and node.type == "text" then
    node.content = hyphenate_text(node.content)
  end

  return node
end

kernel["text.hyphenate"] = function(inputs)
  local ir = inputs.ir
  local language = inputs.language or "en"

  if not ir or not ir.nodes then
    return { ir = ir }
  end

  for node_id, node in pairs(ir.nodes) do
    ir.nodes[node_id] = process_node(node)
  end

  return { ir = ir }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
