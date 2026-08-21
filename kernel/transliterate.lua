-- kernel/transliterate.lua
-- Transliterates text between scripts using ICU transliteration.

local kernel = {}

function kernel.advertise()
  return {
    name = "transliterate",
    description = "Transliterates text between scripts using ICU transliteration.",
    capabilities = {
      {
        name = "text.transliterate",
        version = "1.0.0",
        inputs = {
          ir = "table",
          transliterator_id = "string"
        },
        outputs = {
          ir = "table"
        },
        services = { "icu.translit" }
      }
    }
  }
end

local function transliterate_text(text, transliterator_id)
  transliterator_id = transliterator_id or "Any-Latin"

  if icu and icu.translit then
    local result = icu.translit(text, transliterator_id)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through
  return text
end

kernel["text.transliterate"] = function(inputs)
  local ir = inputs.ir
  local transliterator_id = inputs.transliterator_id or "Any-Latin"

  if not ir or not ir.nodes then
    return { ir = ir }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and node.content then
      node.content = transliterate_text(node.content, transliterator_id)
      node.attributes = node.attributes or {}
      node.attributes.transliterator = transliterator_id
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
