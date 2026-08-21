-- kernel/qr-encode.lua
-- Generates QR code images from text using libqrencode.

local kernel = {}

function kernel.advertise()
  return {
    name = "qr-encode",
    description = "Generates QR code images from text using libqrencode.",
    capabilities = {
      {
        name = "graphics.qr",
        version = "1.0.0",
        inputs = {
          content = "string",
          size = "number",
          margin = "number",
          ec_level = "string",
          foreground = "table",
          background = "table"
        },
        outputs = {
          qr_data = "table",
          dimensions = "table"
        },
        services = { "qrencode.gen" }
      }
    }
  }
end

local function generate_qr(content, size, margin, ec_level)
  size = size or 3
  margin = margin or 4
  ec_level = ec_level or "M"

  if qrencode and qrencode.gen then
    local result = qrencode.gen(content, size, margin, ec_level)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: return metadata, no actual QR generation
  local modules = math.ceil(math.sqrt(#content * 8 + 40))
  local total = modules + 2 * margin

  return {
    modules = modules,
    total_size = total,
    pixel_size = total * size,
    data = "",
    ec_level = ec_level,
    version = math.max(1, math.floor((modules - 17) / 4))
  }
end

kernel["graphics.qr"] = function(inputs)
  local content = inputs.content or ""
  local size = inputs.size or 3
  local margin = inputs.margin or 4
  local ec_level = inputs.ec_level or "M"
  local foreground = inputs.foreground or { r = 0, g = 0, b = 0, a = 1 }
  local background = inputs.background or { r = 1, g = 1, b = 1, a = 1 }

  local result = generate_qr(content, size, margin, ec_level)

  return {
    qr_data = {
      content = result.data,
      modules = result.modules,
      size = result.pixel_size,
      version = result.version,
      ec_level = result.ec_level,
      foreground = foreground,
      background = background
    },
    dimensions = {
      width = result.pixel_size,
      height = result.pixel_size,
      modules = result.modules,
      margin = margin
    }
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
