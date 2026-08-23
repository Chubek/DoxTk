-- kernel/emit-epub.lua
-- Serializes an IR graph to an EPUB 3 byte stream.
-- EPUB is a ZIP archive containing XHTML chapters, OPF package manifest,
-- NCX table of contents, and container.xml.
-- Kernels cannot write files or ZIP directly; this produces a structured
-- JSON representation that the Glue layer converts to a real EPUB archive.

local kernel = {}

function kernel.advertise()
  return {
    name = "emit-epub",
    description = "Serializes an IR graph to an EPUB 3 byte stream.",
    capabilities = {
      {
        name = "emit.epub",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          pages = "table",
          toc_entries = "table",
          metadata = "table"
        },
        outputs = {
          epub = "string"
        }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- XHTML escaping (same rules as HTML)
-- ---------------------------------------------------------------------------
local ESCAPE_MAP = {
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
  ['"'] = "&quot;",
  ["'"] = "&#39;"
}

local function escape_xml(text)
  if not text then return "" end
  return (text:gsub("[&<>\"]", ESCAPE_MAP))
end

-- ---------------------------------------------------------------------------
-- IR node → XHTML fragment (per-chapter content)
-- ---------------------------------------------------------------------------
local function render_node(node, ir, resolved_styles)
  if not node then return "" end

  local style = (resolved_styles and resolved_styles[node.id]) or {}
  local content = node.content and escape_xml(node.content) or ""

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
    local id_attr = node.id and ' id="' .. escape_xml(node.id) .. '"' or ""
    local parts = { "<" .. tag .. id_attr .. ">" .. escape_xml(title) .. "</" .. tag .. ">" }
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
    return '<img src="' .. escape_xml(src) .. '" alt="' .. escape_xml(alt) .. '" width="' .. tostring(w) .. '" height="' .. tostring(h) .. '"/>'

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
    return '<a href="' .. escape_xml(target) .. '.xhtml#' .. escape_xml(target) .. '">' .. escape_xml(label) .. '</a>'

  elseif node.type == "math" or node.type == "display_math" then
    if node.type == "display_math" then
      return '<div class="math display">\\[' .. escape_xml(content) .. '\\]</div>'
    else
      return '<span class="math inline">\\( ' .. escape_xml(content) .. ' \\)</span>'
    end

  elseif node.type == "footnote" then
    return '<sup class="footnote">' .. escape_xml(content) .. '</sup>'

  else
    return content
  end
end

-- ---------------------------------------------------------------------------
-- Build a single XHTML chapter document
-- ---------------------------------------------------------------------------
local function build_chapter_body(ir, resolved_styles, pages, page_index)
  local parts = {}
  local page = (pages and pages[page_index]) or {}

  for _, block_id in ipairs(page.blocks or {}) do
    local node = ir.nodes[block_id]
    if node then
      parts[#parts + 1] = render_node(node, ir, resolved_styles)
    end
  end

  if #parts == 0 and ir and ir.root then
    parts[#parts + 1] = render_node(ir.nodes[ir.root], ir, resolved_styles)
  end

  return table.concat(parts, "\n")
end

-- ---------------------------------------------------------------------------
-- Build a complete XHTML chapter file
-- ---------------------------------------------------------------------------
local function build_chapter_xhtml(ir, resolved_styles, pages, page_index, metadata)
  local title = (metadata and metadata.title) or "Untitled"
  local chapter_num = page_index or 1
  local chapter_title = "Chapter " .. chapter_num

  if pages and pages[page_index] and pages[page_index].title then
    chapter_title = pages[page_index].title
  end

  local body = build_chapter_body(ir, resolved_styles, pages, page_index)

  return table.concat({
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE html>',
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="en" lang="en">',
    "<head>",
    '<meta charset="UTF-8"/>',
    "<title>" .. escape_xml(title .. " - " .. chapter_title) .. "</title>",
    '<link rel="stylesheet" type="text/css" href="style.css"/>',
    "</head>",
    "<body>",
    '<section class="chapter" id="ch' .. chapter_num .. '">',
    body,
    "</section>",
    "</body>",
    "</html>"
  }, "\n")
end

-- ---------------------------------------------------------------------------
-- Build the OPF package document
-- ---------------------------------------------------------------------------
local function build_opf(metadata, toc_entries, num_chapters)
  local md = metadata or {}
  local title = escape_xml(md.title or "Untitled")
  local author = escape_xml(md.author or "Unknown")
  local language = escape_xml(md.language or "en")
  local identifier = escape_xml(md.identifier or "urn:uuid:" .. (md.uuid or "00000000-0000-0000-0000-000000000000"))
  local date = escape_xml(md.date or os.date("%Y-%m-%d"))

  local parts = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="book-id">',
    "<metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">",
    '<dc:identifier id="book-id">' .. identifier .. '</dc:identifier>',
    "<dc:title>" .. title .. "</dc:title>",
    "<dc:creator>" .. author .. "</dc:creator>",
    "<dc:language>" .. language .. "</dc:language>",
    "<dc:date>" .. date .. "</dc:date>",
    '<meta property="dcterms:modified">' .. date .. '</meta>',
    "</metadata>",
    "<manifest>",
    '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>',
    '<item id="css" href="style.css" media-type="text/css"/>',
  }

  for i = 1, num_chapters do
    parts[#parts + 1] = '<item id="ch' .. i .. '" href="ch' .. i .. '.xhtml" media-type="application/xhtml+xml"/>'
  end

  parts[#parts + 1] = "</manifest>"
  parts[#parts + 1] = '<spine toc="ncx">'

  for i = 1, num_chapters do
    parts[#parts + 1] = '<itemref idref="ch' .. i .. '"/>'
  end

  parts[#parts + 1] = "</spine>"
  parts[#parts + 1] = "</package>"

  return table.concat(parts, "\n")
end

-- ---------------------------------------------------------------------------
-- Build the NCX table of contents
-- ---------------------------------------------------------------------------
local function build_ncx(metadata, toc_entries, num_chapters)
  local md = metadata or {}
  local title = escape_xml(md.title or "Untitled")
  local identifier = escape_xml(md.identifier or "urn:uuid:" .. (md.uuid or "00000000-0000-0000-0000-000000000000"))

  local parts = {
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE ncx PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">',
    '<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">',
    "<head>",
    '<meta name="dtb:uid" content="' .. identifier .. '"/>',
    '<meta name="dtb:depth" content="2"/>',
    '<meta name="dtb:totalPageCount" content="0"/>',
    '<meta name="dtb:maxPageNumber" content="0"/>',
    "</head>",
    "<docTitle><text>" .. title .. "</text></docTitle>",
    "<navMap>",
  }

  if toc_entries and #toc_entries > 0 then
    for _, entry in ipairs(toc_entries) do
      local entry_id = escape_xml(entry.id or "")
      local entry_title = escape_xml(entry.title or "Untitled")
      local entry_number = escape_xml(entry.number or "")
      local play_order = entry.play_order or 1
      local src = "ch1.xhtml#" .. entry_id

      parts[#parts + 1] = '<navPoint id="nav-' .. entry_id .. '" playOrder="' .. play_order .. '">'
      parts[#parts + 1] = "<navLabel><text>" .. entry_number .. " " .. entry_title .. "</text></navLabel>"
      parts[#parts + 1] = '<content src="' .. src .. '"/>'
      parts[#parts + 1] = "</navPoint>"
    end
  else
    for i = 1, num_chapters do
      parts[#parts + 1] = '<navPoint id="nav-ch' .. i .. '" playOrder="' .. i .. '">'
      parts[#parts + 1] = "<navLabel><text>Chapter " .. i .. "</text></navLabel>"
      parts[#parts + 1] = '<content src="ch' .. i .. '.xhtml"/>'
      parts[#parts + 1] = "</navPoint>"
    end
  end

  parts[#parts + 1] = "</navMap>"
  parts[#parts + 1] = "</ncx>"

  return table.concat(parts, "\n")
end

-- ---------------------------------------------------------------------------
-- Build the container.xml
-- ---------------------------------------------------------------------------
local function build_container_xml()
  return table.concat({
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">',
    "<rootfiles>",
    '<rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>',
    "</rootfiles>",
    "</container>"
  }, "\n")
end

-- ---------------------------------------------------------------------------
-- Build the default CSS stylesheet
-- ---------------------------------------------------------------------------
local function build_css()
  return table.concat({
    "body {",
    "  font-family: 'Liberation Serif', serif;",
    "  margin: 5%;",
    "  line-height: 1.6;",
    "}",
    "h1, h2, h3, h4, h5, h6 {",
    "  margin-top: 1.5em;",
    "  margin-bottom: 0.5em;",
    "}",
    "p { margin: 0.5em 0; }",
    "table { border-collapse: collapse; width: 100%; }",
    "td { border: 1px solid #ccc; padding: 0.5em; }",
    "img { max-width: 100%; }",
    ".math { font-family: 'Liberation Serif', serif; }",
    ".math.display { display: block; margin: 1em 0; text-align: center; }",
    ".footnote { font-size: 0.8em; vertical-align: super; }",
    ".chapter { page-break-before: always; }"
  }, "\n")
end

-- ---------------------------------------------------------------------------
-- Assemble the full EPUB archive as a structured JSON representation
-- ---------------------------------------------------------------------------
local function build_epub_structure(ir, resolved_styles, pages, toc_entries, metadata)
  local num_chapters = 1
  if pages and #pages > 0 then
    num_chapters = #pages
  end

  local files = {
    mimetype = "application/epub+zip",
    ["META-INF/container.xml"] = build_container_xml(),
    ["OEBPS/content.opf"] = build_opf(metadata, toc_entries, num_chapters),
    ["OEBPS/toc.ncx"] = build_ncx(metadata, toc_entries, num_chapters),
    ["OEBPS/style.css"] = build_css(),
  }

  for i = 1, num_chapters do
    files["OEBPS/ch" .. i .. ".xhtml"] = build_chapter_xhtml(ir, resolved_styles, pages, i, metadata)
  end

  return {
    format = "epub",
    version = "3.0",
    files = files,
    spine_order = {},
  }
end

-- ---------------------------------------------------------------------------
-- Capability implementation: emit.epub
-- ---------------------------------------------------------------------------
kernel["emit.epub"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local pages = inputs.pages or {}
  local toc_entries = inputs.toc_entries or {}
  local metadata = inputs.metadata or {}

  local epub_structure = build_epub_structure(ir, resolved_styles, pages, toc_entries, metadata)

  -- Populate spine order
  for i, _ in ipairs(pages) do
    epub_structure.spine_order[#epub_structure.spine_order + 1] = "OEBPS/ch" .. i .. ".xhtml"
  end
  if #epub_structure.spine_order == 0 then
    epub_structure.spine_order[1] = "OEBPS/ch1.xhtml"
  end

  -- The Glue layer converts this JSON representation to an actual EPUB ZIP archive
  local json = require("doxtk_ljson")
  local epub = json.encode(epub_structure)

  return { epub = epub }
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
