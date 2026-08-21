-- kernel/unicode-break.lua
-- Computes Unicode line-break opportunities using ICU BreakIterator.

local kernel = {}

function kernel.advertise()
  return {
    name = "unicode-break",
    description = "Computes Unicode line-break opportunities using ICU BreakIterator.",
    capabilities = {
      {
        name = "text.linebreak",
        version = "1.0.0",
        inputs = {
          ir = "table",
          locale = "string"
        },
        outputs = {
          ir = "table",
          break_points = "table"
        },
        services = { "icu.break" }
      }
    }
  }
end

local function find_break_points(text, locale)
  locale = locale or "en"

  if icu and icu["break"] then
    local result = icu["break"](text, locale)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: break at spaces and CJK boundaries
  local breaks = {}
  local len = #text
  breaks[0] = true

  for i = 1, len do
    local c = text:sub(i, i)
    local byte_val = string.byte(c)

    if c == " " then
      breaks[i] = true
    elseif byte_val and byte_val >= 0x80 then
      -- Assume CJK: break before and after
      breaks[i - 1] = true
      breaks[i] = true
    end
  end

  breaks[len] = true

  return {
    breaks = breaks,
    locale = locale
  }
end

local function process_text_node(node, locale)
  if not node.content then
    return node
  end

  local break_result = find_break_points(node.content, locale)

  node.attributes = node.attributes or {}
  node.attributes.break_points = break_result.breaks
  node.attributes.break_locale = locale

  return break_result
end

kernel["text.linebreak"] = function(inputs)
  local ir = inputs.ir
  local locale = inputs.locale or "en"
  local break_points = {}

  if not ir or not ir.nodes then
    return { ir = ir, break_points = break_points }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and node.content then
      local result = process_text_node(node, locale)
      break_points[node_id] = result
    end
  end

  return { ir = ir, break_points = break_points }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
