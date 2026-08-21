-- kernel/pdf-sign.lua
-- Cryptographically signs a PDF document using OpenSSL.

local kernel = {}

function kernel.advertise()
  return {
    name = "pdf-sign",
    description = "Cryptographically signs a PDF document using OpenSSL.",
    capabilities = {
      {
        name = "pdf.sign",
        version = "1.0.0",
        inputs = {
          pdf_data = "string",
          key_handle = "string",
          options = "table"
        },
        outputs = {
          signed_pdf = "string",
          signature_info = "table"
        },
        services = { "crypto.sign" }
      }
    }
  }
end

local function sign_pdf(pdf_data, key_handle, options)
  options = options or {}
  local reason = options.reason or "Document signing"
  local location = options.location or ""
  local contact = options.contact or ""
  local visible = options.visible or false
  local cert_level = options.cert_level or "not-certified"

  if crypto and crypto.sign then
    local result = crypto.sign(pdf_data, key_handle, {
      reason = reason,
      location = location,
      contact = contact,
      visible = visible,
      cert_level = cert_level
    })
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through with signing metadata
  -- NOTE: In production, this MUST go through the Glue crypto.sign service
  -- which enforces key-access: handle (never kernel-visible key material)
  return {
    data = pdf_data,
    info = {
      signed = false,
      reason = reason,
      location = location,
      contact = contact,
      algorithm = "SHA-256",
      cert_level = cert_level,
      key_handle = key_handle,
      warning = "signature not applied (crypto.sign service unavailable)"
    }
  }
end

kernel["pdf.sign"] = function(inputs)
  local pdf_data = inputs.pdf_data or ""
  local key_handle = inputs.key_handle or ""
  local options = inputs.options or {}

  local result = sign_pdf(pdf_data, key_handle, options)

  return {
    signed_pdf = result.data,
    signature_info = result.info
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
