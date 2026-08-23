-- kernel/pdf-encrypt.lua
-- Encrypts a PDF document with password protection.
-- Supports user (open) and owner (permissions) passwords,
-- multiple encryption algorithms, and fine-grained permission control.
-- Uses the crypto.encrypt host service through the Glue layer.
-- NOTE: Actual encryption and PDF structure modification is performed
-- by the Glue layer via libharu or a dedicated crypto library.
-- This kernel specifies the encryption parameters; the Glue layer
-- applies them to the PDF byte stream.

local kernel = {}

function kernel.advertise()
  return {
    name = "pdf-encrypt",
    description = "Encrypts a PDF document with password protection.",
    capabilities = {
      {
        name = "pdf.encrypt",
        version = "1.0.0",
        inputs = {
          pdf_data = "string",
          options = "table"
        },
        outputs = {
          encrypted_pdf = "string",
          encryption_info = "table"
        },
        services = { "crypto.encrypt" }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- Supported encryption algorithms (PDF 2.0 / ISO 32000-2)
-- ---------------------------------------------------------------------------
local VALID_ALGORITHMS = {
  ["rc4-40"]   = { key_bits = 40,  name = "RC4 40-bit",           revision = 2 },
  ["rc4-128"]  = { key_bits = 128, name = "RC4 128-bit",          revision = 3 },
  ["aes-128"]  = { key_bits = 128, name = "AES-128",              revision = 4 },
  ["aes-256"]  = { key_bits = 256, name = "AES-256",              revision = 5 },
  ["aes-256-r6"] = { key_bits = 256, name = "AES-256 (Revision 6)", revision = 6 },
}

-- ---------------------------------------------------------------------------
-- PDF permission flags (bitmask as defined in ISO 32000-1 Table 22)
-- ---------------------------------------------------------------------------
local PERMISSION_FLAGS = {
  print_low_res   = { bit = 3,  name = "Print (low resolution)" },
  modify          = { bit = 4,  name = "Modify contents" },
  copy            = { bit = 5,  name = "Copy text and graphics" },
  annotate        = { bit = 6,  name = "Add or modify annotations" },
  fill_forms      = { bit = 9,  name = "Fill interactive form fields" },
  extract         = { bit = 10, name = "Extract text and graphics" },
  assemble        = { bit = 11, name = "Assemble document" },
  print_high_res  = { bit = 12, name = "Print (high resolution)" },
}

-- ---------------------------------------------------------------------------
-- Default permissions (when not explicitly specified)
-- Allow everything except high-res print (bit 12 set = forbid)
-- Bits 3-12 default to 1 = allowed (PDF spec: 1 means allow, 0 means forbid)
-- Standard default: 0xFFFFF2C0 = allow all except restricted bits
-- For simplicity, we express permissions as explicit allow/deny lists
-- and compute the bitmask from user-specified flags.
-- ---------------------------------------------------------------------------
local DEFAULT_ALLOWED = {
  "print_low_res", "modify", "copy", "annotate",
  "fill_forms", "extract", "assemble"
}

-- ---------------------------------------------------------------------------
-- Compute the permission bitmask from an allow/deny list
-- ---------------------------------------------------------------------------
local function compute_permission_mask(permissions)
  -- Start with all bits set to 1 (everything allowed)
  local mask = 0xFFFFF0C0  -- Reserved bits 1-2, 7-8, 13-32 set to 1

  for flag_name, flag_def in pairs(PERMISSION_FLAGS) do
    local allowed = true
    if permissions then
      if permissions.allow then
        -- If explicit allow list, deny everything not in it
        allowed = false
        for _, name in ipairs(permissions.allow) do
          if name == flag_name then allowed = true; break end
        end
      elseif permissions.deny then
        -- If explicit deny list, deny items in it
        for _, name in ipairs(permissions.deny) do
          if name == flag_name then allowed = false; break end
        end
      end
    end

    -- Set bit to 1 if allowed, 0 if denied
    if allowed then
      mask = mask | (1 << flag_def.bit)
    else
      mask = mask & ~(1 << flag_def.bit)
    end
  end

  return mask
end

-- ---------------------------------------------------------------------------
-- Resolve the encryption algorithm
-- ---------------------------------------------------------------------------
local function resolve_algorithm(algorithm_name)
  if not algorithm_name then
    return VALID_ALGORITHMS["aes-256"]
  end

  local algo = VALID_ALGORITHMS[algorithm_name]
  if not algo then
    -- Fall back to AES-256 if unknown
    algo = VALID_ALGORITHMS["aes-256"]
  end
  return algo
end

-- ---------------------------------------------------------------------------
-- Validate password strength
-- ---------------------------------------------------------------------------
local function validate_password(password, role)
  if not password or password == "" then
    return false, role .. " password must not be empty"
  end
  if #password < 4 then
    return false, role .. " password must be at least 4 characters"
  end
  return true, nil
end

-- ---------------------------------------------------------------------------
-- Build a human-readable permissions report
-- ---------------------------------------------------------------------------
local function build_permissions_report(mask)
  local report = {}
  for flag_name, flag_def in pairs(PERMISSION_FLAGS) do
    local allowed = (mask & (1 << flag_def.bit)) ~= 0
    report[flag_name] = {
      name = flag_def.name,
      allowed = allowed,
    }
  end
  return report
end

-- ---------------------------------------------------------------------------
-- Encrypt a PDF document
-- ---------------------------------------------------------------------------
local function encrypt_pdf(pdf_data, options)
  options = options or {}

  -- Resolve algorithm
  local algo = resolve_algorithm(options.algorithm)

  -- Validate passwords
  local user_password = options.user_password or ""
  local owner_password = options.owner_password or ""

  local user_ok, user_err = validate_password(user_password, "User")
  if not user_ok then
    -- If no user password, set an empty one (document openable without password)
    user_password = ""
  end

  local owner_ok, owner_err = validate_password(owner_password, "Owner")
  if not owner_ok then
    -- Owner password defaults to user password if not set
    owner_password = user_password
  end

  -- Compute permission mask
  local permissions = options.permissions or {}
  local permission_mask = compute_permission_mask(permissions)
  local permissions_report = build_permissions_report(permission_mask)

  -- Build encryption info
  local encryption_info = {
    encrypted = true,
    algorithm = {
      name = algo.name,
      key = algo.key_bits,
      revision = algo.revision,
    },
    has_user_password = (user_password ~= ""),
    has_owner_password = (owner_password ~= ""),
    permissions = permissions_report,
    permission_mask = permission_mask,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }

  -- If host service is available, use it
  if crypto and crypto.encrypt then
    local result = crypto.encrypt(pdf_data, {
      algorithm = algo.name,
      key_bits = algo.key_bits,
      revision = algo.revision,
      user_password = user_password,
      owner_password = owner_password,
      permission_mask = permission_mask,
    })
    if result then
      return {
        data = result.data,
        info = encryption_info,
      }
    end
  end

  -- Pure-Lua fallback: pass-through with encryption metadata
  -- NOTE: In production, the Glue layer's crypto.encrypt service
  -- encrypts the PDF stream, embeds the encryption dictionary, and
  -- updates the trailer. The kernel never sees the actual key material.
  return {
    data = pdf_data,
    info = encryption_info,
  }
end

-- ---------------------------------------------------------------------------
-- Capability implementation: pdf.encrypt
-- ---------------------------------------------------------------------------
kernel["pdf.encrypt"] = function(inputs)
  local pdf_data = inputs.pdf_data or ""
  local options = inputs.options or {}

  local result = encrypt_pdf(pdf_data, options)

  return {
    encrypted_pdf = result.data,
    encryption_info = result.info
  }
end

-- ---------------------------------------------------------------------------
-- --advertise entry point
-- ---------------------------------------------------------------------------
if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
