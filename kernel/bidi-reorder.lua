-- kernel/bidi-reorder.lua
-- Reorders bidirectional text runs using FriBidi or ICU.

local kernel = {}

function kernel.advertise()
  return {
    name = "bidi-reorder",
    description = "Reorders bidirectional text runs using FriBidi or ICU.",
    capabilities = {
      {
        name = "text.bidi",
        version = "1.0.0",
        inputs = {
          ir = "table",
          paragraph_direction = "string"
        },
        outputs = {
          ir = "table",
          bidi_runs = "table"
        },
        services = { "fribidi.bidi" }
      }
    }
  }
end

local function reorder_text(text, base_dir)
  base_dir = base_dir or "auto"

  if fribidi and fribidi.bidi then
    local result = fribidi.bidi(text, base_dir)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through with metadata
  return {
    text = text,
    levels = {},
    base_direction = base_dir
  }
end

local function process_text_node(node, base_dir)
  if not node.content then
    return node
  end

  local bidi_result = reorder_text(node.content, base_dir)

  node.attributes = node.attributes or {}
  node.attributes.bidi_levels = bidi_result.levels
  node.attributes.bidi_direction = bidi_result.base_direction

  return bidi_result
end

kernel["text.bidi"] = function(inputs)
  local ir = inputs.ir
  local paragraph_direction = inputs.paragraph_direction or "auto"
  local bidi_runs = {}

  if not ir or not ir.nodes then
    return { ir = ir, bidi_runs = bidi_runs }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and node.content then
      local result = process_text_node(node, paragraph_direction)
      bidi_runs[node_id] = result
    end
  end

  return { ir = ir, bidi_runs = bidi_runs }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
