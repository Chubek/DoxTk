-- kernel/shape-text.lua
-- Shapes text runs using HarfBuzz, producing positioned glyph sequences.

local kernel = {}

function kernel.advertise()
  return {
    name = "shape-text",
    description = "Shapes text runs using HarfBuzz, producing positioned glyph sequences.",
    capabilities = {
      {
        name = "text.shape",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          font_config = "table",
          language = "string",
          script = "string",
          direction = "string"
        },
        outputs = {
          ir = "table",
          glyph_runs = "table"
        },
        services = { "harfbuzz.shape" }
      }
    }
  }
end

local function build_hb_input(text, style, font_config)
  local font_size = (style and style.font_size) or 12
  local font_family = (style and style.font_family) or (font_config and font_config.default_family) or "Serif"
  local font_weight = (style and style.font_weight) or 400
  local font_style = (style and style.font_style) or "normal"
  return {
    text = text,
    font_family = font_family,
    font_size = font_size,
    font_weight = font_weight,
    font_style = font_style
  }
end

local function shape_text(text, style, font_config, language, script, direction)
  local hb_input = build_hb_input(text, style, font_config)

  if harfbuzz and harfbuzz.shape then
    local result = harfbuzz.shape(hb_input)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: simple glyph positioning
  local glyphs = {}
  local x_cursor = 0
  local font_size = hb_input.font_size
  local default_advance = font_size * 0.5

  for i = 1, #text do
    local c = text:sub(i, i)
    local byte_val = string.byte(c)
    local advance = default_advance
    if byte_val and byte_val <= 32 then
      advance = font_size * 0.25
    elseif byte_val and byte_val >= 0x80 then
      advance = font_size * 0.6
    end
    glyphs[#glyphs + 1] = {
      glyph = i,
      cluster = i - 1,
      x_offset = x_cursor,
      y_offset = 0,
      x_advance = advance,
      y_advance = 0
    }
    x_cursor = x_cursor + advance
  end

  return {
    glyphs = glyphs,
    total_width = x_cursor,
    total_height = font_size * 1.2
  }
end

kernel["text.shape"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local font_config = inputs.font_config or {}
  local language = inputs.language or "en"
  local script = inputs.script or "Latn"
  local direction = inputs.direction or "ltr"
  local glyph_runs = {}

  if not ir or not ir.nodes then
    return { ir = ir, glyph_runs = glyph_runs }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.content and node.type == "text" then
      local style = resolved_styles[node_id] or {}
      local shaped = shape_text(node.content, style, font_config, language, script, direction)
      glyph_runs[node_id] = shaped

      node.attributes = node.attributes or {}
      node.attributes.shaped_width = shaped.total_width
      node.attributes.shaped_height = shaped.total_height
    end
  end

  return { ir = ir, glyph_runs = glyph_runs }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
