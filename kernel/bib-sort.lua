-- kernel/bib-sort.lua
-- Sorts bibliography entries by author, year, title, or custom criteria.

local kernel = {}

function kernel.advertise()
  return {
    name = "bib-sort",
    description = "Sorts bibliography entries by author, year, title, or custom criteria.",
    capabilities = {
      {
        name = "doc.bibsort",
        version = "1.0.0",
        inputs = {
          bibliography = "table",
          criteria = "table",
          order = "string"
        },
        outputs = {
          sorted_keys = "table",
          sorted_entries = "table"
        }
      }
    }
  }
end

local function get_primary_author(entry)
  if entry.authors and #entry.authors > 0 then
    return (entry.authors[1].last or entry.authors[1].name or ""):lower()
  end
  if entry.fields then
    return (entry.fields.author or ""):lower()
  end
  return ""
end

local function get_year(entry)
  if entry.fields and entry.fields.year then
    return tonumber(entry.fields.year) or 0
  end
  return 0
end

local function get_title(entry)
  if entry.fields and entry.fields.title then
    return entry.fields.title:lower()
  end
  return ""
end

local function get_type(entry)
  return entry.type or ""
end

local function compare_entries(a, b, criteria, order)
  order = order or "asc"

  for _, criterion in ipairs(criteria) do
    local va, vb

    if criterion == "author" then
      va = get_primary_author(a)
      vb = get_primary_author(b)
    elseif criterion == "year" then
      va = get_year(a)
      vb = get_year(b)
    elseif criterion == "title" then
      va = get_title(a)
      vb = get_title(b)
    elseif criterion == "type" then
      va = get_type(a)
      vb = get_type(b)
    else
      va = tostring(a[criterion] or "")
      vb = tostring(b[criterion] or "")
    end

    if va ~= vb then
      if order == "desc" then
        return vb < va
      else
        return va < vb
      end
    end
  end

  return false
end

local function sort_bibliography(bibliography, criteria, order)
  criteria = criteria or { "author", "year", "title" }
  order = order or "asc"

  local keys = {}
  for key in pairs(bibliography) do
    keys[#keys + 1] = key
  end

  table.sort(keys, function(ka, kb)
    return compare_entries(bibliography[ka], bibliography[kb], criteria, order)
  end)

  local sorted_entries = {}
  for _, key in ipairs(keys) do
    sorted_entries[key] = bibliography[key]
  end

  return keys, sorted_entries
end

kernel["doc.bibsort"] = function(inputs)
  local bibliography = inputs.bibliography or {}
  local criteria = inputs.criteria or { "author", "year", "title" }
  local order = inputs.order or "asc"

  local sorted_keys, sorted_entries = sort_bibliography(bibliography, criteria, order)

  return {
    sorted_keys = sorted_keys,
    sorted_entries = sorted_entries
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
