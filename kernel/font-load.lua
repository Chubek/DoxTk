-- kernel/font-load.lua
-- Loads and inspects font metadata via FreeType face.

local kernel = {}

function kernel.advertise()
  return {
    name = "font-load",
    description = "Loads and inspects font metadata via FreeType face.",
    capabilities = {
      {
        name = "font.info",
        version = "1.0.0",
        inputs = {
          font_data = "string",
          font_index = "number"
        },
        outputs = {
          font_info = "table"
        },
        services = { "freetype.face" }
      }
    }
  }
end

local function parse_font_info(font_data, font_index)
  font_index = font_index or 0

  if freetype and freetype.face then
    local result = freetype.face(font_data, font_index)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: minimal font-info stub
  return {
    family_name = "Unknown",
    style_name = "Regular",
    num_glyphs = 0,
    units_per_em = 1000,
    ascender = 800,
    descender = -200,
    height = 1000,
    max_advance_width = 1000,
    max_advance_height = 1000,
    underline_position = -100,
    underline_thickness = 50,
    has_horizontal = true,
    has_vertical = false,
    has_kerning = true,
    is_scalable = true,
    is_fixed_width = false,
    glyph_names = {},
    index = font_index
  }
end

kernel["font.info"] = function(inputs)
  local font_data = inputs.font_data or ""
  local font_index = inputs.font_index or 0

  local font_info = parse_font_info(font_data, font_index)

  return { font_info = font_info }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
