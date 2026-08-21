-- kernel/bib-format.lua
-- Formats bibliography entries under a named citation style.

local kernel = {}

function kernel.advertise()
  return {
    name = "bib-format",
    description = "Formats bibliography entries under a named citation style.",
    capabilities = {
      {
        name = "doc.bibliography",
        version = "1.0.0",
        inputs = {
          ir = "table",
          bibliography = "table",
          style = "string"
        },
        outputs = {
          ir = "table",
          formatted_entries = "table"
        }
      }
    }
  }
end

local function format_author_apa(authors)
  if not authors or #authors == 0 then
    return ""
  end
  if #authors == 1 then
    return authors[1].last or authors[1].name or ""
  end
  if #authors == 2 then
    return (authors[1].last or authors[1].name or "") .. " & " .. (authors[2].last or authors[2].name or "")
  end
  return (authors[1].last or authors[1].name or "") .. " et al."
end

local function format_author_ieee(authors)
  if not authors or #authors == 0 then
    return ""
  end
  local names = {}
  for _, a in ipairs(authors) do
    local first = a.first or ""
    local last = a.last or a.name or ""
    if #first > 0 then
      names[#names + 1] = first:sub(1,1) .. ". " .. last
    else
      names[#names + 1] = last
    end
  end
  return table.concat(names, ", ")
end

local FORMATTERS = {
  apa = {
    article = function(entry)
      local parts = {}
      parts[#parts + 1] = format_author_apa(entry.authors)
      parts[#parts + 1] = "(" .. (entry.year or "n.d.") .. ")"
      parts[#parts + 1] = entry.title or ""
      parts[#parts + 1] = "*" .. (entry.journal or "") .. "*"
      parts[#parts + 1] = entry.volume or ""
      if entry.issue then
        parts[#parts] = parts[#parts] .. "(" .. entry.issue .. ")"
      end
      parts[#parts + 1] = entry.pages or ""
      return table.concat(parts, ". ") .. "."
    end,
    book = function(entry)
      local parts = {}
      parts[#parts + 1] = format_author_apa(entry.authors)
      parts[#parts + 1] = "(" .. (entry.year or "n.d.") .. ")"
      parts[#parts + 1] = "*" .. (entry.title or "") .. "*"
      parts[#parts + 1] = entry.publisher or ""
      return table.concat(parts, ". ") .. "."
    end,
    default = function(entry)
      local parts = {}
      parts[#parts + 1] = format_author_apa(entry.authors)
      parts[#parts + 1] = "(" .. (entry.year or "n.d.") .. ")"
      parts[#parts + 1] = entry.title or ""
      return table.concat(parts, ". ") .. "."
    end
  },
  ieee = {
    default = function(entry)
      local parts = {}
      parts[#parts + 1] = format_author_ieee(entry.authors)
      parts[#parts + 1] = '"' .. (entry.title or "") .. '"'
      if entry.journal then
        parts[#parts + 1] = "*" .. entry.journal .. "*"
      end
      if entry.volume then
        parts[#parts + 1] = "vol. " .. entry.volume
      end
      if entry.issue then
        parts[#parts] = parts[#parts] .. ", no. " .. entry.issue
      end
      parts[#parts + 1] = "pp. " .. (entry.pages or "1")
      parts[#parts + 1] = entry.year or "n.d."
      return "[" .. (entry.key or "?") .. "] " .. table.concat(parts, ", ") .. "."
    end
  }
}

local function format_entry(entry, style)
  style = style or "apa"
  local formatters = FORMATTERS[style] or FORMATTERS.apa
  local fmt = formatters[entry.type] or formatters.default
  return fmt(entry)
end

kernel["doc.bibliography"] = function(inputs)
  local ir = inputs.ir
  local bibliography = inputs.bibliography or {}
  local style = inputs.style or "apa"
  local formatted = {}

  if type(bibliography) == "table" then
    for key, entry in pairs(bibliography) do
      if type(entry) == "table" then
        formatted[key] = format_entry(entry, style)
      end
    end
  end

  return { ir = ir, formatted_entries = formatted }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
