-- kernel/image-decode.lua
-- Probes and decodes raster images to extract metadata and pixel data.

local kernel = {}

function kernel.advertise()
  return {
    name = "image-decode",
    description = "Probes and decodes raster images to extract metadata and pixel data.",
    capabilities = {
      {
        name = "image.probe",
        version = "1.0.0",
        inputs = {
          image_data = "string",
          format = "string"
        },
        outputs = {
          image_info = "table",
          decoded_data = "string"
        },
        services = { "image.probe" }
      }
    }
  }
end

local function probe_image(image_data, format)
  format = format or "auto"

  if image_probe and image_probe.decode then
    local result = image_probe.decode(image_data, format)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: minimal image-info stub
  return {
    info = {
      width = 0,
      height = 0,
      channels = 3,
      bit_depth = 8,
      format = format,
      has_alpha = false,
      dpi_x = 72,
      dpi_y = 72,
      color_space = "sRGB"
    },
    decoded = image_data
  }
end

kernel["image.probe"] = function(inputs)
  local image_data = inputs.image_data or ""
  local format = inputs.format or "auto"

  local result = probe_image(image_data, format)

  return {
    image_info = result.info,
    decoded_data = result.decoded
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
