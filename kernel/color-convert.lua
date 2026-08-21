-- kernel/color-convert.lua
-- Converts colors between ICC profiles using lcms2.

local kernel = {}

function kernel.advertise()
  return {
    name = "color-convert",
    description = "Converts colors between ICC profiles using lcms2.",
    capabilities = {
      {
        name = "color.icc",
        version = "1.0.0",
        inputs = {
          ir = "table",
          source_profile = "string",
          target_profile = "string",
          rendering_intent = "string"
        },
        outputs = {
          ir = "table"
        },
        services = { "lcms2.transform" }
      }
    }
  }
end

local function convert_color(r, g, b, a, source_profile, target_profile, intent)
  intent = intent or "perceptual"

  if lcms2 and lcms2.transform then
    local result = lcms2.transform({ r = r, g = g, b = b, a = a }, source_profile, target_profile, intent)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through
  return { r = r, g = g, b = b, a = a }
end

local function convert_node_colors(node, source_profile, target_profile, intent)
  local attrs = node.attributes
  if not attrs then
    return
  end

  if attrs.color then
    local c = attrs.color
    local converted = convert_color(c.r or 0, c.g or 0, c.b or 0, c.a or 1, source_profile, target_profile, intent)
    attrs.color = converted
  end

  if attrs.background_color then
    local c = attrs.background_color
    local converted = convert_color(c.r or 0, c.g or 0, c.b or 0, c.a or 1, source_profile, target_profile, intent)
    attrs.background_color = converted
  end

  if attrs.border_color then
    local c = attrs.border_color
    local converted = convert_color(c.r or 0, c.g or 0, c.b or 0, c.a or 1, source_profile, target_profile, intent)
    attrs.border_color = converted
  end
end

kernel["color.icc"] = function(inputs)
  local ir = inputs.ir
  local source_profile = inputs.source_profile or "sRGB"
  local target_profile = inputs.target_profile or "sRGB"
  local rendering_intent = inputs.rendering_intent or "perceptual"

  if not ir or not ir.nodes then
    return { ir = ir }
  end

  for _, node in pairs(ir.nodes) do
    if type(node) == "table" then
      convert_node_colors(node, source_profile, target_profile, rendering_intent)
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
