-- kernel/cite-style.lua
-- Generates citation markers and in-text citation formatting for
-- numeric, author-year, and other citation styles.

local kernel = {}

function kernel.advertise()
  return {
    name = "cite-style",
    description = "Generates citation markers and in-text citation formatting.",
    capabilities = {
      {
        name = "doc.citestyle",
        version = "1.0.0",
        inputs = {
          ir = "table",
          bibliography = "table",
          citation_map = "table",
          style = "string"
        },
        outputs = {
          ir = "table",
          styled_citations = "table"
        }
      }
    }
  }
end

local function get_author_short(entry)
  if not entry.authors or #entry.authors == 0 then
    return entry.fields and entry.fields.author or "Anonymous"
  end
  if #entry.authors == 1 then
    return entry.authors[1].last or entry.authors[1].name or "Anonymous"
  elseif #entry.authors == 2 then
    return (entry.authors[1].last or entry.authors[1].name or "") .. " and " .. (entry.authors[2].last or entry.authors[2].name or "")
  else
    return (entry.authors[1].last or entry.authors[1].name or "") .. " et al."
  end
end

local function get_year(entry)
  return entry.fields and entry.fields.year or "n.d."
end

local function generate_numeric_marker(numbers)
  if #numbers == 1 then
    return "[" .. numbers[1] .. "]"
  end
  -- Compact ranges: [1,2,3] -> [1-3]
  table.sort(numbers)
  local ranges = {}
  local start = numbers[1]
  local prev = numbers[1]
  for i = 2, #numbers + 1 do
    local n = numbers[i]
    if n and n == prev + 1 then
      prev = n
    else
      if start == prev then
        ranges[#ranges + 1] = tostring(start)
      else
        ranges[#ranges + 1] = tostring(start) .. "-" .. tostring(prev)
      end
      start = n
      prev = n or prev
    end
  end
  return "[" .. table.concat(ranges, ", ") .. "]"
end

local function generate_author_year_marker(keys, bibliography)
  local parts = {}
  for _, key in ipairs(keys) do
    local entry = bibliography[key]
    if entry then
      parts[#parts + 1] = get_author_short(entry) .. ", " .. get_year(entry)
    end
  end
  return "(" .. table.concat(parts, "; ") .. ")"
end

local function generate_superscript_marker(numbers)
  if #numbers == 1 then
    return "^{" .. numbers[1] .. "}"
  end
  table.sort(numbers)
  return "^{" .. table.concat(numbers, ",") .. "}"
end

local function generate_inline_marker(keys, bibliography)
  local parts = {}
  for _, key in ipairs(keys) do
    local entry = bibliography[key]
    if entry then
      parts[#parts + 1] = get_author_short(entry)
    end
  end
  return table.concat(parts, "; ") .. " (" .. (bibliography[keys[1]] and get_year(bibliography[keys[1]]) or "n.d.") .. ")"
end

local STYLE_GENERATORS = {
  numeric = generate_numeric_marker,
  "author-year" = generate_author_year_marker,
  superscript = generate_superscript_marker,
  inline = generate_inline_marker
}

local function apply_citation_style(ir, citation_map, bibliography, style)
  local styled = {}
  local generator = STYLE_GENERATORS[style] or STYLE_GENERATORS.numeric

  if not ir or not ir.nodes then
    return ir, styled
  end

  for node_id, cite_info in pairs(citation_map) do
    local node = ir.nodes[node_id]
    if node and node.type == "cite" then
      local marker
      if style == "numeric" or style == "superscript" then
        marker = generator(cite_info.numbers)
      elseif style == "author-year" or style == "inline" then
        marker = generator(cite_info.keys, bibliography)
      else
        marker = generator(cite_info.numbers)
      end

      node.attributes = node.attributes or {}
      node.attributes.citation_style = style
      node.attributes.citation_marker = marker
      node.content = marker

      styled[node_id] = {
        marker = marker,
        style = style,
        keys = cite_info.keys,
        numbers = cite_info.numbers
      }
    end
  end

  return ir, styled
end

kernel["doc.citestyle"] = function(inputs)
  local ir = inputs.ir
  local bibliography = inputs.bibliography or {}
  local citation_map = inputs.citation_map or {}
  local style = inputs.style or "numeric"

  local ir_out, styled = apply_citation_style(ir, citation_map, bibliography, style)

  return {
    ir = ir_out,
    styled_citations = styled
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
