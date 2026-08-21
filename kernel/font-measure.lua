-- kernel/font-measure.lua
-- Measures glyph advances and text extents for a resolved font set.

local kernel = {}

function kernel.advertise()
  return {
    name = "font-measure",
    description = "Measures glyph advances and text extents for a resolved font set.",
    capabilities = {
      {
        name = "text.measure",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          font_config = "table"
        },
        outputs = {
          ir = "table",
          measurements = "table"
        },
        services = { "haru.font" }
      }
    }
  }
end

local CHAR_WIDTHS = {
  default = 0.5,
  thin = 0.3,
  wide = 0.8,
}

local function classify_char(c)
  local code = string.byte(c)
  if not code then
    return "default"
  end
  if code <= 32 then
    return "thin"
  end
  if code >= 0x4E00 and code <= 0x9FFF then
    return "wide"
  end
  if code >= 0x3040 and code <= 0x30FF then
    return "wide"
  end
  if c == "i" or c == "l" or c == "I" or c == "1" or c == "|" or c == ":" or c == ";" or c == "." or c == "," or c == "'" then
    return "thin"
  end
  if c == "m" or c == "w" or c == "M" or c == "W" or c == "@" or c == "#" then
    return "wide"
  end
  return "default"
end

local function measure_text(text, font_size)
  local total_width = 0
  local glyphs = {}

  for i = 1, #text do
    local c = text:sub(i, i)
    local char_class = classify_char(c)
    local width = (CHAR_WIDTHS[char_class] or 0.5) * font_size
    total_width = total_width + width
    glyphs[#glyphs + 1] = {
      char = c,
      width = width,
      advance = width
    }
  end

  return {
    glyphs = glyphs,
    total_width = total_width,
    height = font_size * 1.2,
    font_size = font_size
  }
end

local function measure_text_run(text, style)
  local font_size = (style and style.font_size) or 12
  return measure_text(text, font_size)
end

kernel["text.measure"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local font_config = inputs.font_config or {}
  local measurements = {}

  if not ir or not ir.nodes then
    return { ir = ir, measurements = measurements }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.content and node.type == "text" then
      local style = resolved_styles[node_id] or {}
      measurements[node_id] = measure_text_run(node.content, style)
      node.attributes = node.attributes or {}
      node.attributes.measured_width = measurements[node_id].total_width
      node.attributes.measured_height = measurements[node_id].height
    end
  end

  return { ir = ir, measurements = measurements }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
