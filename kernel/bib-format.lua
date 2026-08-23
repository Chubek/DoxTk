-- kernel/bib-format.lua
-- Formats bibliography entries under a named citation style.
-- Supports: apa, mla, chicago, ieee, vancouver, harvard, nature.

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

-- Author formatting helpers

local function fmt_author_last_first(authors)
  if not authors or #authors == 0 then return "" end
  local names = {}
  for _, a in ipairs(authors) do
    local last = a.last or a.name or ""
    local first = a.first or ""
    if #first > 0 then
      names[#names + 1] = last .. ", " .. first
    else
      names[#names + 1] = last
    end
  end
  return table.concat(names, ", ")
end

local function fmt_author_apa(authors)
  if not authors or #authors == 0 then return "" end
  if #authors == 1 then
    return (authors[1].last or authors[1].name or "")
  elseif #authors == 2 then
    return (authors[1].last or authors[1].name or "") .. " & " .. (authors[2].last or authors[2].name or "")
  else
    return (authors[1].last or authors[1].name or "") .. " et al."
  end
end

local function fmt_author_ieee(authors)
  if not authors or #authors == 0 then return "" end
  local names = {}
  for _, a in ipairs(authors) do
    local first = a.first or ""
    local last = a.last or a.name or ""
    if #first > 0 then
      names[#names + 1] = first:sub(1, 1) .. ". " .. last
    else
      names[#names + 1] = last
    end
  end
  return table.concat(names, ", ")
end

local function fmt_author_mla(authors)
  if not authors or #authors == 0 then return "" end
  if #authors == 1 then
    return (authors[1].last or authors[1].name or "") .. ", " .. (authors[1].first or "")
  elseif #authors == 2 then
    return (authors[1].last or authors[1].name or "") .. ", " .. (authors[1].first or "") .. ", and " .. (authors[2].first or "") .. " " .. (authors[2].last or "")
  else
    return (authors[1].last or authors[1].name or "") .. ", " .. (authors[1].first or "") .. ", et al."
  end
end

local function fmt_author_chicago(authors)
  if not authors or #authors == 0 then return "" end
  local names = {}
  for i, a in ipairs(authors) do
    local last = a.last or a.name or ""
    local first = a.first or ""
    if i > 1 and i == #authors then
      names[#names + 1] = "and " .. (first .. " " .. last):match("^%s*(.-)%s*$")
    else
      names[#names + 1] = (first .. " " .. last):match("^%s*(.-)%s*$")
    end
  end
  return table.concat(names, ", ")
end

local function fmt_year(entry)
  return entry.fields and entry.fields.year or "n.d."
end

local function fmt_title(entry, quoted)
  local title = entry.fields and entry.fields.title or ""
  if quoted then
    return '"' .. title .. '"'
  end
  return title
end

local function fmt_journal(entry)
  local j = entry.fields and entry.fields.journal or ""
  if #j > 0 then return "*" .. j .. "*" end
  return ""
end

local function fmt_volume_issue_pages(entry)
  local parts = {}
  local vol = entry.fields and entry.fields.volume
  local iss = entry.fields and entry.fields.number or entry.fields and entry.fields.issue
  local pages = entry.fields and entry.fields.pages
  if vol then parts[#parts + 1] = vol end
  if iss then parts[#parts] = (parts[#parts] or "") .. "(" .. iss .. ")" end
  if pages then parts[#parts + 1] = pages end
  return table.concat(parts, ", ")
end

local function fmt_publisher(entry)
  return entry.fields and entry.fields.publisher or ""
end

-- Style formatters

local FORMATTERS = {
  apa = {
    article = function(entry)
      return fmt_author_apa(entry.authors) .. " (" .. fmt_year(entry) .. "). "
        .. fmt_title(entry) .. ". " .. fmt_journal(entry) .. ", "
        .. fmt_volume_issue_pages(entry) .. "."
    end,
    book = function(entry)
      return fmt_author_apa(entry.authors) .. " (" .. fmt_year(entry) .. "). "
        .. "*" .. fmt_title(entry) .. "*. " .. fmt_publisher(entry) .. "."
    end,
    inproceedings = function(entry)
      return fmt_author_apa(entry.authors) .. " (" .. fmt_year(entry) .. "). "
        .. fmt_title(entry) .. ". In *" .. (entry.fields and entry.fields.booktitle or "") .. "*. "
        .. fmt_publisher(entry) .. "."
    end,
    default = function(entry)
      return fmt_author_apa(entry.authors) .. " (" .. fmt_year(entry) .. "). "
        .. fmt_title(entry) .. "."
    end
  },
  mla = {
    article = function(entry)
      return fmt_author_mla(entry.authors) .. '. "' .. fmt_title(entry) .. '." '
        .. (entry.fields and entry.fields.journal or "") .. ", "
        .. (entry.fields and entry.fields.volume or "") .. "."
        .. (entry.fields and entry.fields.number or "") .. " "
        .. "(" .. fmt_year(entry) .. "): " .. (entry.fields and entry.fields.pages or "") .. "."
    end,
    book = function(entry)
      return fmt_author_mla(entry.authors) .. ". *" .. fmt_title(entry) .. "*. "
        .. fmt_publisher(entry) .. ", " .. fmt_year(entry) .. "."
    end,
    default = function(entry)
      return fmt_author_mla(entry.authors) .. '. "' .. fmt_title(entry) .. '." '
        .. fmt_year(entry) .. "."
    end
  },
  chicago = {
    article = function(entry)
      return fmt_author_chicago(entry.authors) .. '. "' .. fmt_title(entry) .. '." '
        .. (entry.fields and entry.fields.journal or "") .. " "
        .. (entry.fields and entry.fields.volume or "") .. ", no. "
        .. (entry.fields and entry.fields.number or "") .. " "
        .. "(" .. fmt_year(entry) .. "): " .. (entry.fields and entry.fields.pages or "") .. "."
    end,
    book = function(entry)
      return fmt_author_chicago(entry.authors) .. ". *" .. fmt_title(entry) .. "*. "
        .. fmt_publisher(entry) .. ", " .. fmt_year(entry) .. "."
    end,
    default = function(entry)
      return fmt_author_chicago(entry.authors) .. '. "' .. fmt_title(entry) .. '." '
        .. fmt_year(entry) .. "."
    end
  },
  ieee = {
    article = function(entry)
      return fmt_author_ieee(entry.authors) .. ', "' .. fmt_title(entry) .. '," '
        .. (entry.fields and entry.fields.journal or "") .. ", vol. "
        .. (entry.fields and entry.fields.volume or "") .. ", no. "
        .. (entry.fields and entry.fields.number or "") .. ", pp. "
        .. (entry.fields and entry.fields.pages or "") .. ", "
        .. fmt_year(entry) .. "."
    end,
    book = function(entry)
      return fmt_author_ieee(entry.authors) .. ", *" .. fmt_title(entry) .. "*. "
        .. fmt_publisher(entry) .. ", " .. fmt_year(entry) .. "."
    end,
    inproceedings = function(entry)
      return fmt_author_ieee(entry.authors) .. ', "' .. fmt_title(entry) .. '," in '
        .. (entry.fields and entry.fields.booktitle or "") .. ", "
        .. fmt_year(entry) .. ", pp. " .. (entry.fields and entry.fields.pages or "") .. "."
    end,
    default = function(entry)
      return fmt_author_ieee(entry.authors) .. ', "' .. fmt_title(entry) .. '," '
        .. fmt_year(entry) .. "."
    end
  },
  vancouver = {
    article = function(entry)
      return fmt_author_ieee(entry.authors) .. ". " .. fmt_title(entry) .. ". "
        .. (entry.fields and entry.fields.journal or "") .. ". "
        .. fmt_year(entry) .. ";"
        .. (entry.fields and entry.fields.volume or "") .. "("
        .. (entry.fields and entry.fields.number or "") .. "):"
        .. (entry.fields and entry.fields.pages or "") .. "."
    end,
    book = function(entry)
      return fmt_author_ieee(entry.authors) .. ". " .. fmt_title(entry) .. ". "
        .. fmt_publisher(entry) .. "; " .. fmt_year(entry) .. "."
    end,
    default = function(entry)
      return fmt_author_ieee(entry.authors) .. ". " .. fmt_title(entry) .. ". "
        .. fmt_year(entry) .. "."
    end
  },
  harvard = {
    article = function(entry)
      return fmt_author_last_first(entry.authors) .. " (" .. fmt_year(entry) .. ") '"
        .. fmt_title(entry) .. "', " .. (entry.fields and entry.fields.journal or "") .. ", "
        .. (entry.fields and entry.fields.volume or "") .. "("
        .. (entry.fields and entry.fields.number or "") .. "), pp. "
        .. (entry.fields and entry.fields.pages or "") .. "."
    end,
    book = function(entry)
      return fmt_author_last_first(entry.authors) .. " (" .. fmt_year(entry) .. ") *"
        .. fmt_title(entry) .. "*. " .. fmt_publisher(entry) .. "."
    end,
    default = function(entry)
      return fmt_author_last_first(entry.authors) .. " (" .. fmt_year(entry) .. ") '"
        .. fmt_title(entry) .. "'."
    end
  },
  nature = {
    article = function(entry)
      return fmt_author_ieee(entry.authors) .. ". " .. fmt_title(entry) .. ". "
        .. (entry.fields and entry.fields.journal or "") .. " **"
        .. (entry.fields and entry.fields.volume or "") .. "**, "
        .. (entry.fields and entry.fields.pages or "") .. " (" .. fmt_year(entry) .. ")."
    end,
    book = function(entry)
      return fmt_author_ieee(entry.authors) .. ". *" .. fmt_title(entry) .. "*. "
        .. fmt_publisher(entry) .. " (" .. fmt_year(entry) .. ")."
    end,
    default = function(entry)
      return fmt_author_ieee(entry.authors) .. ". " .. fmt_title(entry) .. ". "
        .. "(" .. fmt_year(entry) .. ")."
    end
  }
}

local function format_entry(entry, style)
  style = style:lower()
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
