-- kernel/csv-parse.lua
-- Parses CSV input into structured data using csv-parser.

local kernel = {}

function kernel.advertise()
  return {
    name = "csv-parse",
    description = "Parses CSV input into structured data using csv-parser.",
    capabilities = {
      {
        name = "parse.csv",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          data = "table"
        },
        services = { "csv-parser.parse" }
      }
    }
  }
end

local function parse_csv(source, options)
  options = options or {}
  local delimiter = options.delimiter or ","
  local quote_char = options.quote_char or '"'
  local has_header = options.has_header
  local skip_empty = options.skip_empty or false
  local trim = options.trim or false

  if csv_parser and csv_parser.parse then
    local result = csv_parser.parse(source, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: RFC 4180-compliant CSV parser
  local rows = {}
  local row = {}
  local field = ""
  local pos = 1
  local len = #source
  local in_quoted = false

  while pos <= len do
    local ch = source:sub(pos, pos)

    if in_quoted then
      if ch == quote_char then
        local next_ch = source:sub(pos + 1, pos + 1)
        if next_ch == quote_char then
          -- Escaped quote
          field = field .. quote_char
          pos = pos + 2
        else
          -- End of quoted field
          in_quoted = false
          pos = pos + 1
        end
      else
        field = field .. ch
        pos = pos + 1
      end
    elseif ch == quote_char then
      in_quoted = true
      pos = pos + 1
    elseif ch == delimiter then
      if trim then
        field = field:match("^%s*(.-)%s*$")
      end
      row[#row + 1] = field
      field = ""
      pos = pos + 1
    elseif ch == "\n" then
      if trim then
        field = field:match("^%s*(.-)%s*$")
      end
      row[#row + 1] = field
      if not skip_empty or #row > 0 then
        rows[#rows + 1] = row
      end
      row = {}
      field = ""
      pos = pos + 1
    elseif ch == "\r" then
      local next_ch = source:sub(pos + 1, pos + 1)
      if next_ch == "\n" then
        pos = pos + 2
      else
        pos = pos + 1
      end
      if trim then
        field = field:match("^%s*(.-)%s*$")
      end
      row[#row + 1] = field
      if not skip_empty or #row > 0 then
        rows[#rows + 1] = row
      end
      row = {}
      field = ""
    else
      field = field .. ch
      pos = pos + 1
    end
  end

  -- Handle trailing field without newline
  if #field > 0 or #row > 0 then
    if trim then
      field = field:match("^%s*(.-)%s*$")
    end
    row[#row + 1] = field
    if not skip_empty or #row > 0 then
      rows[#rows + 1] = row
    end
  end

  -- Build result
  local result = { rows = rows, columns = {} }

  -- Determine headers
  local header_row = nil
  if has_header == nil then
    -- Auto-detect: first row is header if it looks like one
    if #rows > 0 then
      local first = rows[1]
      local all_strings = true
      for _, v in ipairs(first) do
        if v == "" or tonumber(v) then
          all_strings = false
          break
        end
      end
      if all_strings then
        has_header = true
      end
    end
  end

  if has_header and #rows > 0 then
    header_row = rows[1]
    result.header = header_row
    result.rows = {}
    for i = 2, #rows do
      result.rows[i - 1] = rows[i]
    end
    -- Build column-oriented access
    for i, col_name in ipairs(header_row) do
      local col = {}
      for _, row_data in ipairs(result.rows) do
        col[#col + 1] = row_data[i]
      end
      result.columns[col_name] = col
    end
  else
    -- Build positional column access
    for i = 1, (#rows[1] or 0) do
      local col = {}
      for _, row_data in ipairs(rows) do
        col[#col + 1] = row_data[i]
      end
      result.columns[i] = col
    end
  end

  return result
end

kernel["parse.csv"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local data = parse_csv(source, options)

  return { data = data }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
