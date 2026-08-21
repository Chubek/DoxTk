-- kernel/page-break.lua
-- Assigns laid-out blocks to pages with penalty-based breaking.

local kernel = {}

function kernel.advertise()
  return {
    name = "page-break",
    description = "Assigns laid-out blocks to pages with penalty-based breaking.",
    capabilities = {
      {
        name = "layout.page",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          page_height = "number",
          page_width = "number"
        },
        outputs = {
          ir = "table",
          pages = "table"
        }
      }
    }
  }
end

local function estimate_block_height(node, resolved_styles)
  local style = resolved_styles[node.id] or {}
  local height = 0

  if node.type == "text" then
    local line_count = (node.attributes and node.attributes.line_count) or 1
    local line_height = (node.attributes and node.attributes.line_height) or 14.4
    height = line_count * line_height
  elseif node.type == "image" then
    height = (node.attributes and node.attributes.height) or 100
  elseif node.type == "section" or node.type == "paragraph" then
    height = (style.font_size or 12) * 1.2
  elseif node.type == "table" then
    height = (node.attributes and node.attributes.table_height) or 100
  else
    height = 20
  end

  height = height + (style.margin_top or 0) + (style.margin_bottom or 0)
  height = height + (style.padding_top or 0) + (style.padding_bottom or 0)

  return height
end

local function assign_blocks_to_pages(ir, resolved_styles, page_height)
  local pages = {}
  local current_page = { blocks = {}, used_height = 0, page_number = 1 }

  if not ir or not ir.nodes then
    return pages
  end

  local ordered_nodes = {}
  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" then
      ordered_nodes[#ordered_nodes + 1] = node
    end
  end

  table.sort(ordered_nodes, function(a, b)
    return (a.id or "") < (b.id or "")
  end)

  for _, node in ipairs(ordered_nodes) do
    local block_height = estimate_block_height(node, resolved_styles)

    if current_page.used_height + block_height > page_height and #current_page.blocks > 0 then
      pages[#pages + 1] = current_page
      current_page = { blocks = {}, used_height = 0, page_number = #pages + 2 }
    end

    current_page.blocks[#current_page.blocks + 1] = node.id
    current_page.used_height = current_page.used_height + block_height
  end

  if #current_page.blocks > 0 then
    pages[#pages + 1] = current_page
  end

  return pages
end

kernel["layout.page"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local page_height = inputs.page_height or 792
  local page_width = inputs.page_width or 612

  local pages = assign_blocks_to_pages(ir, resolved_styles, page_height)

  return { ir = ir, pages = pages }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
