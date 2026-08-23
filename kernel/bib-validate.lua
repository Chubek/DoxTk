-- kernel/bib-validate.lua
-- Validates bibliography entries for required fields per entry type.

local kernel = {}

function kernel.advertise()
  return {
    name = "bib-validate",
    description = "Validates bibliography entries for required fields per entry type.",
    capabilities = {
      {
        name = "doc.bibcheck",
        version = "1.0.0",
        inputs = {
          bibliography = "table",
          options = "table"
        },
        outputs = {
          valid = "boolean",
          errors = "table",
          warnings = "table"
        }
      }
    }
  }
end

-- Required fields per entry type (BibTeX standard)
local REQUIRED_FIELDS = {
  article = { "author", "title", "journal", "year" },
  book = { "author", "title", "publisher", "year" },
  booklet = { "title" },
  inbook = { "author", "title", "chapter", "publisher", "year" },
  incollection = { "author", "title", "booktitle", "publisher", "year" },
  inproceedings = { "author", "title", "booktitle", "year" },
  manual = { "title" },
  mastersthesis = { "author", "title", "school", "year" },
  misc = {},
  phdthesis = { "author", "title", "school", "year" },
  proceedings = { "title", "year" },
  techreport = { "author", "title", "institution", "year" },
  unpublished = { "author", "title", "note" }
}

-- Optional but recommended fields
local RECOMMENDED_FIELDS = {
  article = { "volume", "number", "pages", "doi" },
  book = { "edition", "isbn", "address" },
  inproceedings = { "pages", "address", "doi" },
  phdthesis = { "address" },
  techreport = { "number", "address" }
}

local function validate_bibliography(bibliography, options)
  options = options or {}
  local strict = options.strict or false
  local errors = {}
  local warnings = {}

  if type(bibliography) ~= "table" then
    errors[#errors + 1] = "bibliography: expected table, got " .. type(bibliography)
    return errors, warnings
  end

  for key, entry in pairs(bibliography) do
    if type(entry) ~= "table" then
      errors[#errors + 1] = "entry '" .. tostring(key) .. "': expected table, got " .. type(entry)
    else
      local entry_type = entry.type or "misc"
      local fields = entry.fields or {}
      local entry_key = entry.key or key

      -- Check required fields
      local required = REQUIRED_FIELDS[entry_type] or {}
      for _, field in ipairs(required) do
        if not fields[field] or fields[field] == "" then
          if strict then
            errors[#errors + 1] = "entry '" .. tostring(entry_key) .. "': missing required field '" .. field .. "' for type '" .. entry_type .. "'"
          else
            warnings[#warnings + 1] = "entry '" .. tostring(entry_key) .. "': missing required field '" .. field .. "' for type '" .. entry_type .. "'"
          end
        end
      end

      -- Check recommended fields
      local recommended = RECOMMENDED_FIELDS[entry_type] or {}
      for _, field in ipairs(recommended) do
        if not fields[field] or fields[field] == "" then
          warnings[#warnings + 1] = "entry '" .. tostring(entry_key) .. "': missing recommended field '" .. field .. "' for type '" .. entry_type .. "'"
        end
      end

      -- Check year format
      if fields.year then
        local y = tonumber(fields.year)
        if not y or y < 1000 or y > 2100 then
          warnings[#warnings + 1] = "entry '" .. tostring(entry_key) .. "': suspicious year '" .. tostring(fields.year) .. "'"
        end
      end

      -- Check DOI format
      if fields.doi then
        if not fields.doi:match("^10%.") then
          warnings[#warnings + 1] = "entry '" .. tostring(entry_key) .. "': DOI does not start with '10.'"
        end
      end

      -- Check for unknown entry type
      if not REQUIRED_FIELDS[entry_type] then
        warnings[#warnings + 1] = "entry '" .. tostring(entry_key) .. "': unknown entry type '" .. entry_type .. "'"
      end
    end
  end

  return errors, warnings
end

kernel["doc.bibcheck"] = function(inputs)
  local bibliography = inputs.bibliography or {}
  local options = inputs.options or {}

  local errors, warnings = validate_bibliography(bibliography, options)

  return {
    valid = (#errors == 0),
    errors = errors,
    warnings = warnings
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
