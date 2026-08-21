-- kernel/stream-compress.lua
-- Compresses or decompresses byte streams using zlib/zstd/brotli.

local kernel = {}

function kernel.advertise()
  return {
    name = "stream-compress",
    description = "Compresses or decompresses byte streams using zlib/zstd/brotli.",
    capabilities = {
      {
        name = "codec.compress",
        version = "1.0.0",
        inputs = {
          data = "string",
          algorithm = "string",
          level = "number",
          action = "string"
        },
        outputs = {
          result_data = "string",
          compression_info = "table"
        },
        services = { "codec.compress" }
      }
    }
  }
end

local function process_stream(data, algorithm, level, action)
  algorithm = algorithm or "zlib"
  level = level or 6
  action = action or "compress"

  if codec and codec.compress then
    local result = codec.compress(data, algorithm, level, action)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through
  return {
    data = data,
    info = {
      algorithm = algorithm,
      level = level,
      action = action,
      original_size = #data,
      processed_size = #data,
      ratio = 1.0,
      applied = false
    }
  }
end

kernel["codec.compress"] = function(inputs)
  local data = inputs.data or ""
  local algorithm = inputs.algorithm or "zlib"
  local level = inputs.level or 6
  local action = inputs.action or "compress"

  local result = process_stream(data, algorithm, level, action)

  return {
    result_data = result.data,
    compression_info = result.info
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
