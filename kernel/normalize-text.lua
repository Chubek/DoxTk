-- kernel/normalize-text.lua
-- Normalizes Unicode text using ICU normalization (NFC/NFD/NFKC/NFKD).

local kernel = {}

function kernel.advertise()
  return {
    name = "normalize-text",
    description = "Normalizes Unicode text using ICU normalization.",
    capabilities = {
      {
        name = "text.normalize",
        version = "1.0.0",
        inputs = {
          ir = "table",
          form = "string"
        },
        outputs = {
          ir = "table"
        },
        services = { "icu.norm" }
      }
    }
  }
end

local function normalize_text(text, form)
  form = form or "NFC"

  if icu and icu.norm then
    local result = icu.norm(text, form)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through
  -- Full Unicode normalization requires ICU tables; this is a stub
  return text
end

kernel["text.normalize"] = function(inputs)
  local ir = inputs.ir
  local form = inputs.form or "NFC"

  if not ir or not ir.nodes then
    return { ir = ir }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and node.content then
      node.content = normalize_text(node.content, form)
      node.attributes = node.attributes or {}
      node.attributes.normalization = form
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
