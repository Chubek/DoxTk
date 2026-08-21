-- kernel/svg-rasterize.lua
-- Rasterizes SVG content to a pixel buffer using resvg.

local kernel = {}

function kernel.advertise()
  return {
    name = "svg-rasterize",
    description = "Rasterizes SVG content to a pixel buffer using resvg.",
    capabilities = {
      {
        name = "image.svg",
        version = "1.0.0",
        inputs = {
          svg_data = "string",
          width = "number",
          height = "number",
          dpi = "number",
          background = "string"
        },
        outputs = {
          raster_data = "string",
          raster_info = "table"
        },
        services = { "resvg.render" }
      }
    }
  }
end

local function rasterize_svg(svg_data, width, height, dpi, background)
  dpi = dpi or 96
  background = background or "#FFFFFF"

  if resvg and resvg.render then
    local result = resvg.render(svg_data, width, height, dpi, background)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: return SVG as-is with metadata
  return {
    raster = svg_data,
    info = {
      width = width or 0,
      height = height or 0,
      dpi = dpi,
      format = "svg",
      background = background
    }
  }
end

kernel["image.svg"] = function(inputs)
  local svg_data = inputs.svg_data or ""
  local width = inputs.width
  local height = inputs.height
  local dpi = inputs.dpi or 96
  local background = inputs.background or "#FFFFFF"

  local result = rasterize_svg(svg_data, width, height, dpi, background)

  return {
    raster_data = result.raster,
    raster_info = result.info
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
