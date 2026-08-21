-- kernel/font-subset.lua
-- Creates a font subset containing only the glyphs used in a document.

local kernel = {}

function kernel.advertise()
  return {
    name = "font-subset",
    description = "Creates a font subset containing only glyphs used in a document.",
    capabilities = {
      {
        name = "font.subset",
        version = "1.0.0",
        inputs = {
          ir = "table",
          font_data = "string",
          font_index = "number"
        },
        outputs = {
          subset_data = "string",
          glyph_map = "table"
        },
        services = { "harfbuzz.subset" }
      },
      limits = {
        memory_mb = 128
      }
    }
  }
end

local function collect_used_glyphs(ir)
  local used_chars = {}
  local seen = {}

  if not ir or not ir.nodes then
    return used_chars
  end

  for _, node in pairs(ir.nodes) do
    if type(node) == "table" and node.content and node.type == "text" then
      for i = 1, #node.content do
        local c = node.content:sub(i, i)
        if not seen[c] then
          seen[c] = true
          used_chars[#used_chars + 1] = c
        end
      end
    end
  end

  return used_chars
end

local function subset_font(ir, font_data, font_index)
  font_index = font_index or 0

  if harfbuzz and harfbuzz.subset then
    local used_chars = collect_used_glyphs(ir)
    local result = harfbuzz.subset(font_data, used_chars, font_index)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: return input as-is with a glyph map
  local used_chars = collect_used_glyphs(ir)
  local glyph_map = {}
  for i, c in ipairs(used_chars) do
    glyph_map[c] = i
  end

  return {
    subset_data = font_data,
    glyph_map = glyph_map
  }
end

kernel["font.subset"] = function(inputs)
  local ir = inputs.ir
  local font_data = inputs.font_data or ""
  local font_index = inputs.font_index or 0

  local result = subset_font(ir, font_data, font_index)

  return {
    subset_data = result.subset_data,
    glyph_map = result.glyph_map
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
