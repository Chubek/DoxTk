-- kernel/emit-html.lua
-- Serializes an IR graph to a standalone HTML byte stream.

local kernel = {}

function kernel.advertise()
  return {
    name = "emit-html",
    description = "Serializes an IR graph to a standalone HTML byte stream.",
    capabilities = {
      {
        name = "emit.html",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          pages = "table",
          toc_entries = "table"
        },
        outputs = {
          html = "string"
        }
      }
    }
  }
end

local ESCAPE_MAP = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["'"] = "&#39;"
}

local function escape_html(text)
  if not text then return "" end
  return (text:gsub("[&<>\"]", ESCAPE_MAP))
end

local function render_node(node, ir, resolved_styles)
  if not node then return "" end

  local style = (resolved_styles and resolved_styles[node.id]) or {}
  local content = node.content and escape_html(node.content) or ""

  if node.type == "document" then
    local parts = { '<div class="document">' }
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    parts[#parts + 1] = "</div>"
    return table.concat(parts, "\n")

  elseif node.type == "section" then
    local level = (node.attributes and node.attributes.level) or 1
    local tag = "h" .. math.min(level + 1, 6)
    local title = node.attributes and node.attributes.title or content
    local id_attr = node.id and ' id="' .. escape_html(node.id) .. '"' or ""
    local parts = { "<" .. tag .. id_attr .. ">" .. escape_html(title) .. "</" .. tag .. ">" }
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    return table.concat(parts, "\n")

  elseif node.type == "paragraph" then
    local parts = { "<p>" }
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    if content ~= "" then
      parts[#parts + 1] = content
    end
    parts[#parts + 1] = "</p>"
    return table.concat(parts, "")

  elseif node.type == "text" then
    return content

  elseif node.type == "image" then
    local src = node.attributes and node.attributes.src or ""
    local alt = node.attributes and node.attributes.alt or ""
    local w = node.attributes and node.attributes.width or ""
    local h = node.attributes and node.attributes.height or ""
    return '<img src="' .. escape_html(src) .. '" alt="' .. escape_html(alt) .. '" width="' .. tostring(w) .. '" height="' .. tostring(h) .. '">'

  elseif node.type == "table" then
    local parts = { "<table>" }
    local rows = node.attributes and node.attributes.rows or 1
    local cols = node.attributes and node.attributes.columns or 1
    for r = 1, rows do
      parts[#parts + 1] = "<tr>"
      for c = 1, cols do
        parts[#parts + 1] = "<td></td>"
      end
      parts[#parts + 1] = "</tr>"
    end
    parts[#parts + 1] = "</table>"
    return table.concat(parts, "\n")

  elseif node.type == "xref" then
    local target = node.attributes and node.attributes.target or ""
    local label = node.attributes and node.attributes.resolved_number or content
    return '<a href="#' .. escape_html(target) .. '">' .. escape_html(label) .. '</a>'

  elseif node.type == "math" or node.type == "display_math" then
    if node.type == "display_math" then
      return '<div class="math display">\\[' .. escape_html(content) .. '\\]</div>'
    else
      return '<span class="math inline">\\( ' .. escape_html(content) .. ' \\)</span>'
    end

  elseif node.type == "footnote" then
    return '<sup class="footnote">' .. escape_html(content) .. '</sup>'

  else
    return content
  end
end

local function generate_html(ir, resolved_styles, pages, toc_entries)
  local parts = {
    "<!DOCTYPE html>",
    "<html lang=\"en\">",
    "<head>",
    '<meta charset="UTF-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    "<title>Document</title>",
    "<style>",
    "body { font-family: 'Liberation Serif', serif; max-width: 800px; margin: 0 auto; padding: 2em; line-height: 1.6; }",
    "h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; }",
    "p { margin: 0.5em 0; }",
    "table { border-collapse: collapse; width: 100%; }",
    "td { border: 1px solid #ccc; padding: 0.5em; }",
    "img { max-width: 100%; }",
    ".math { font-family: 'Liberation Serif', serif; }",
    ".math.display { display: block; margin: 1em 0; text-align: center; }",
    ".footnote { font-size: 0.8em; vertical-align: super; }",
    "</style>",
    "</head>",
    "<body>"
  }

  if ir and ir.root then
    parts[#parts + 1] = render_node(ir.nodes[ir.root], ir, resolved_styles)
  end

  if toc_entries and #toc_entries > 0 then
    parts[#parts + 1] = "<hr><nav><h2>Table of Contents</h2><ul>"
    for _, entry in ipairs(toc_entries) do
      parts[#parts + 1] = '<li><a href="#' .. escape_html(entry.id) .. '">' .. escape_html(entry.number) .. " " .. escape_html(entry.title) .. '</a></li>'
    end
    parts[#parts + 1] = "</ul></nav>"
  end

  parts[#parts + 1] = "</body>"
  parts[#parts + 1] = "</html>"

  return table.concat(parts, "\n")
end

kernel["emit.html"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local pages = inputs.pages or {}
  local toc_entries = inputs.toc_entries or {}

  local html = generate_html(ir, resolved_styles, pages, toc_entries)

  return { html = html }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
