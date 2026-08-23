-- kernel/bib-parse.lua
-- Parses BibTeX/BibLaTeX bibliography files into structured entries.

local kernel = {}

function kernel.advertise()
  return {
    name = "bib-parse",
    description = "Parses BibTeX/BibLaTeX bibliography files into structured entries.",
    capabilities = {
      {
        name = "parse.bib",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          entries = "table",
          strings = "table",
          preamble = "string"
        }
      }
    }
  }
end

local function parse_bibtex(source, options)
  options = options or {}

  -- Strip comments
  source = source:gsub("@[Cc][Oo][Mm][Mm][Ee][Nn][Tt]%b{}", "")
  source = source:gsub("@[Cc][Oo][Mm][Mm][Ee][Nn][Tt]%b()", "")

  local entries = {}
  local strings = {}
  local preamble = ""

  -- Extract @string definitions
  source = source:gsub("@[Ss][Tt][Rr][Ii][Nn][Gg]%s*{%s*(%w+)%s*=%s*(.-)}%s*", function(name, value)
    value = value:match('^%s*(.-)%s*$')
    value = value:gsub('^["\']', ''):gsub('["\']$', '')
    value = value:gsub("%s*#%s*", "")
    strings[name] = value
    return ""
  end)

  -- Extract @preamble
  source = source:gsub("@[Pp][Rr][Ee][Aa][Mm][Bb][Ll][Ee]%s*{(.-)}%s*", function(body)
    preamble = body:gsub('^["\']', ''):gsub('["\']$', '')
    return ""
  end)

  -- Parse entry types
  for entry_type, cite_key, body in source:gmatch("@(%w+)%s*{%s*([^,]+),(.-)}%s*") do
    local entry = {
      type = entry_type:lower(),
      key = cite_key:match("^%s*(.-)%s*$"),
      fields = {}
    }

    -- Parse field-value pairs
    local pos = 1
    local blen = #body

    while pos <= blen do
      local remaining = body:sub(pos)
      local field_name = remaining:match("^%s*(%w+)%s*=")
      if not field_name then
        pos = pos + 1
      else
        pos = pos + remaining:find("=")
        local after_eq = body:sub(pos):match("^%s*(.*)")
        if not after_eq then break end

        local value = ""
        if after_eq:sub(1, 1) == "{" then
          -- Brace-delimited value
          local depth = 0
          local i = 1
          while i <= #after_eq do
            local ch = after_eq:sub(i, i)
            if ch == "{" then
              if depth > 0 then value = value .. ch end
              depth = depth + 1
            elseif ch == "}" then
              depth = depth - 1
              if depth == 0 then break
              else value = value .. ch end
            else
              if depth > 0 then value = value .. ch end
            end
            i = i + 1
          end
          pos = pos + i + 1
        elseif after_eq:sub(1, 1) == '"' then
          -- Quote-delimited value
          local i = 2
          while i <= #after_eq do
            local ch = after_eq:sub(i, i)
            if ch == '"' then break end
            if ch == "\\" and after_eq:sub(i + 1, i + 1) == '"' then
              value = value .. '"'
              i = i + 2
            else
              value = value .. ch
              i = i + 1
            end
          end
          pos = pos + i + 1
        else
          -- Numeric or abbreviation value
          local val = after_eq:match("^(%S+)")
          if val then
            val = val:gsub("[,}]$", "")
            value = strings[val] or val
            pos = pos + #val + 1
          else
            pos = pos + 1
          end
        end

        field_name = field_name:lower()
        entry.fields[field_name] = value:match("^%s*(.-)%s*$")
      end
    end

    -- Normalize common fields
    if entry.fields.author then
      local authors = {}
      for author in entry.fields.author:gmatch("[^%s][^%a][n][d]") do
        -- This is a simplified approach; real BibTeX author parsing is complex
        author = author:match("^%s*(.-)%s*$")
        author = author:gsub("%s+", " ")
        if #author > 0 then
          local last, first = author:match("^([^,]+),%s*(.+)$")
          if last then
            authors[#authors + 1] = { first = first, last = last }
          else
            local parts = {}
            for part in author:gmatch("%S+") do
              parts[#parts + 1] = part
            end
            if #parts > 1 then
              authors[#authors + 1] = {
                first = table.concat(parts, " ", 1, #parts - 1),
                last = parts[#parts]
              }
            else
              authors[#authors + 1] = { name = author }
            end
          end
        end
      end
      entry.authors = authors
      entry.fields.author = nil
    end

    entries[entry.key] = entry
  end

  return { entries = entries, strings = strings, preamble = preamble }
end

kernel["parse.bib"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local result = parse_bibtex(source, options)

  return {
    entries = result.entries,
    strings = result.strings,
    preamble = result.preamble
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
