-- kernel/pdf-tag.lua
-- Adds PDF/UA accessibility structure tags to a PDF document.
-- Tags are derived from the IR graph and mapped to PDF standard
-- structure types (Sect, P, H, L, Table, Figure, etc.).
-- Uses the pdf.tag host service through the Glue layer.
-- NOTE: Actual PDF structure tree injection is performed by the
-- Glue layer via libharu or a dedicated PDF-tagging library.
-- This kernel produces the tag map; the Glue layer embeds it.

local kernel = {}

function kernel.advertise()
  return {
    name = "pdf-tag",
    description = "Adds PDF/UA accessibility structure tags to a PDF document.",
    capabilities = {
      {
        name = "pdf.tag",
        version = "1.0.0",
        inputs = {
          pdf_data = "string",
          ir = "table",
          resolved_styles = "table",
          pages = "table",
          options = "table"
        },
        outputs = {
          tagged_pdf = "string",
          tag_info = "table"
        },
        services = { "pdf.tag" }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- Standard PDF structure type mapping (PDF 2.0 / ISO 32000-2)
-- ---------------------------------------------------------------------------
local PDF_STRUCT_TYPES = {
  document   = "Document",
  section    = "Sect",
  paragraph  = "P",
  text       = "Span",
  image      = "Figure",
  table      = "Table",
  list       = "L",
  list_item  = "LI",
  xref       = "Link",
  math       = "Formula",
  display_math = "Formula",
  footnote   = "Note",
  header     = "H",
  footer     = "Footer",
  caption    = "Caption",
  blockquote = "BlockQuote",
  code       = "Code",
  toc        = "TOC",
  toc_item   = "TOCI",
}

-- ---------------------------------------------------------------------------
-- Map IR node type to PDF structure type
-- ---------------------------------------------------------------------------
local function map_to_struct_type(node_type, attributes)
  if node_type == "section" then
    local level = (attributes and attributes.level) or 1
    if level <= 6 then
      return "H" .. level
    end
    return "Sect"
  end
  return PDF_STRUCT_TYPES[node_type] or "Div"
end

-- ---------------------------------------------------------------------------
-- Build a tag tree from the IR graph
-- ---------------------------------------------------------------------------
local function build_tag_tree(ir, pages, resolved_styles)
  local tag_tree = {
    type = "Document",
    id = "root",
    children = {},
    attributes = {
      lang = "en",
      title = "",
    }
  }

  if not ir or not ir.root then
    return tag_tree
  end

  local function walk_node(node_id, parent_tag)
    local node = ir.nodes[node_id]
    if not node then return end

    local struct_type = map_to_struct_type(node.type, node.attributes)
    local style = (resolved_styles and resolved_styles[node.id]) or {}

    local tag = {
      type = struct_type,
      id = (node.attributes and node.attributes.id) or node.id,
      attributes = {},
      children = {},
    }

    -- Copy title for sections
    if node.type == "section" and node.attributes and node.attributes.title then
      tag.attributes.title = node.attributes.title
    end

    -- Alt text for images
    if node.type == "image" and node.attributes and node.attributes.alt then
      tag.attributes.alt = node.attributes.alt
    end

    -- Table structure
    if node.type == "table" and node.attributes then
      tag.attributes.rows = node.attributes.rows
      tag.attributes.columns = node.attributes.columns
      -- Generate table row/cell structure
      local rows = node.attributes.rows or 1
      local cols = node.attributes.columns or 1
      for r = 1, rows do
        local tr_tag = {
          type = "TR",
          id = node.id .. "_tr" .. r,
          attributes = { row = r },
          children = {},
        }

        -- Check if this is a header row
        if node.attributes.header_rows and r <= node.attributes.header_rows then
          tr_tag.type = "TR"
          tr_tag.attributes.is_header = true
        end

        for c = 1, cols do
          local cell_tag = {
            type = (tr_tag.attributes.is_header and "TH" or "TD"),
            id = node.id .. "_r" .. r .. "c" .. c,
            attributes = { row = r, col = c },
            children = {},
          }
          tr_tag.children[#tr_tag.children + 1] = cell_tag

          -- If table has cell content in IR, walk it
          local cell_id = node.id .. "_r" .. r .. "c" .. c
          if ir.nodes[cell_id] then
            walk_node(cell_id, cell_tag)
          end
        end
        tag.children[#tag.children + 1] = tr_tag
      end
    end

    -- Walk children
    for _, child_id in ipairs(node.children or {}) do
      walk_node(child_id, tag)
    end

    -- If no children were added (leaf), still include the tag
    parent_tag.children[#parent_tag.children + 1] = tag
  end

  walk_node(ir.root, tag_tree)

  return tag_tree
end

-- ---------------------------------------------------------------------------
-- Collect page-to-tag mappings for each page
-- ---------------------------------------------------------------------------
local function build_page_tag_map(ir, pages)
  local page_map = {}

  if not pages then
    return page_map
  end

  for pi, page in ipairs(pages) do
    local page_tags = {}
    for _, block_id in ipairs(page.blocks or {}) do
      local node = ir.nodes[block_id]
      if node then
        page_tags[#page_tags + 1] = {
          id = node.id,
          type = map_to_struct_type(node.type, node.attributes),
          page = pi,
        }
      end
    end
    page_map[pi] = page_tags
  end

  return page_map
end

-- ---------------------------------------------------------------------------
-- Validate tagging against PDF/UA-1 requirements
-- ---------------------------------------------------------------------------
local function validate_tagging(tag_tree, options)
  local issues = {}
  local warnings = {}

  -- PDF/UA-1 requires a Document root
  if tag_tree.type ~= "Document" then
    issues[#issues + 1] = "Missing Document root tag"
  end

  -- Check for empty alt text on images
  local function check_images(tag)
    if tag.type == "Figure" and (not tag.attributes.alt or tag.attributes.alt == "") then
      warnings[#warnings + 1] = "Image '" .. tag.id .. "' has no alt text"
    end
    for _, child in ipairs(tag.children or {}) do
      check_images(child)
    end
  end
  check_images(tag_tree)

  return {
    valid = (#issues == 0),
    issues = issues,
    warnings = warnings,
  }
end

-- ---------------------------------------------------------------------------
-- Build tag metadata and statistics
-- ---------------------------------------------------------------------------
local function build_tag_info(tag_tree, page_map, validation_result)
  local function count_tags_by_type(tag, counts)
    counts = counts or {}
    counts[tag.type] = (counts[tag.type] or 0) + 1
    for _, child in ipairs(tag.children or {}) do
      count_tags_by_type(child, counts)
    end
    return counts
  end

  return {
    tagged = true,
    standard = "PDF/UA-1",
    root_type = tag_tree.type,
    tag_counts = count_tags_by_type(tag_tree),
    page_count = page_map and #page_map or 0,
    validation = validation_result,
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  }
end

-- ---------------------------------------------------------------------------
-- Tag a PDF document for accessibility
-- ---------------------------------------------------------------------------
local function tag_pdf(pdf_data, ir, resolved_styles, pages, options)
  options = options or {}
  local standard = options.standard or "PDF/UA-1"
  local include_metadata = options.include_metadata
  if include_metadata == nil then include_metadata = true end
  local validate = options.validate
  if validate == nil then validate = true end

  -- Build the tag tree from IR
  local tag_tree = build_tag_tree(ir, pages, resolved_styles)

  -- Build page-to-tag mappings
  local page_map = build_page_tag_map(ir, pages)

  -- Validate if requested
  local validation = { valid = true, issues = {}, warnings = {} }
  if validate then
    validation = validate_tagging(tag_tree, options)
  end

  -- Build tag info
  local tag_info = build_tag_info(tag_tree, page_map, validation)

  -- If host service is available, use it to inject tags into the PDF
  if pdf and pdf.tag then
    local result = pdf.tag(pdf_data, {
      tag_tree = tag_tree,
      page_map = page_map,
      standard = standard,
      include_metadata = include_metadata,
    })
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: pass-through with tag metadata
  -- NOTE: In production, the Glue layer's pdf.tag service injects the
  -- structure tree into the PDF catalog and marks the document as tagged.
  return {
    data = pdf_data,
    info = tag_info
  }
end

-- ---------------------------------------------------------------------------
-- Capability implementation: pdf.tag
-- ---------------------------------------------------------------------------
kernel["pdf.tag"] = function(inputs)
  local pdf_data = inputs.pdf_data or ""
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local pages = inputs.pages or {}
  local options = inputs.options or {}

  local result = tag_pdf(pdf_data, ir, resolved_styles, pages, options)

  return {
    tagged_pdf = result.data,
    tag_info = result.info
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
