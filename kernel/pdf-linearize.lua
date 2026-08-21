-- kernel/pdf-linearize.lua
-- Optimizes and linearizes PDF output using qpdf.

local kernel = {}

function kernel.advertise()
  return {
    name = "pdf-linearize",
    description = "Optimizes and linearizes PDF output using qpdf.",
    capabilities = {
      {
        name = "pdf.optimize",
        version = "1.0.0",
        inputs = {
          pdf_data = "string",
          options = "table"
        },
        outputs = {
          optimized_pdf = "string",
          stats = "table"
        },
        services = { "qpdf.transform" }
      }
    }
  }
end

local function optimize_pdf(pdf_data, options)
  options = options or {}
  local linearize = options.linearize
  if linearize == nil then linearize = true end
  local compress = options.compress
  if compress == nil then compress = true end
  local object_streams = options.object_streams or "preserve"
  local normalize = options.normalize or false
  local remove_unused = options.remove_unused or true

  if qpdf and qpdf.transform then
    local result = qpdf.transform(pdf_data, {
      linearize = linearize,
      compress = compress,
      object_streams = object_streams,
      normalize = normalize,
      remove_unused = remove_unused
    })
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through with stats
  return {
    data = pdf_data,
    stats = {
      original_size = #pdf_data,
      optimized_size = #pdf_data,
      linearized = false,
      compressed = false,
      object_streams = object_streams,
      normalized = normalize,
      unused_removed = false
    }
  }
end

kernel["pdf.optimize"] = function(inputs)
  local pdf_data = inputs.pdf_data or ""
  local options = inputs.options or {}

  local result = optimize_pdf(pdf_data, options)

  return {
    optimized_pdf = result.data,
    stats = result.stats
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
