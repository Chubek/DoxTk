-- kernel/table-layout.lua
-- Computes column widths and cell boxes for table nodes.

local kernel = {}

function kernel.advertise()
  return {
    name = "table-layout",
    description = "Computes column widths and cell boxes for table nodes.",
    capabilities = {
      {
        name = "layout.table",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          page_width = "number"
        },
        outputs = {
          ir = "table",
          table_layouts = "table"
        }
      }
    }
  }
end

local function compute_column_widths(table_node, resolved_styles, page_width)
  local col_count = table_node.attributes and table_node.attributes.columns or 1
  local style = resolved_styles[table_node.id] or {}
  local margin_left = style.margin_left or 0
  local margin_right = style.margin_right or 0
  local avail_width = page_width - margin_left - margin_right

  local col_widths = {}
  local default_width = avail_width / col_count

  for i = 1, col_count do
    col_widths[i] = default_width
  end

  return col_widths
end

local function compute_cell_boxes(table_node, col_widths, resolved_styles)
  local cell_boxes = {}
  local rows = table_node.attributes and table_node.attributes.rows or 1
  local cols = table_node.attributes and table_node.attributes.columns or 1
  local style = resolved_styles[table_node.id] or {}
  local row_height = (style.font_size or 12) * 1.5

  for r = 1, rows do
    for c = 1, cols do
      local x = 0
      for k = 1, c - 1 do
        x = x + (col_widths[k] or 0)
      end
      local y = (r - 1) * row_height
      cell_boxes[#cell_boxes + 1] = {
        row = r,
        col = c,
        x = x,
        y = y,
        width = col_widths[c] or 0,
        height = row_height
      }
    end
  end

  return cell_boxes
end

kernel["layout.table"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local page_width = inputs.page_width or 612
  local table_layouts = {}

  if not ir or not ir.nodes then
    return { ir = ir, table_layouts = table_layouts }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "table" then
      local col_widths = compute_column_widths(node, resolved_styles, page_width)
      local cell_boxes = compute_cell_boxes(node, col_widths, resolved_styles)
      local total_height = (node.attributes.rows or 1) * ((resolved_styles[node_id] and resolved_styles[node_id].font_size or 12) * 1.5)

      node.attributes = node.attributes or {}
      node.attributes.column_widths = col_widths
      node.attributes.table_height = total_height

      table_layouts[node_id] = {
        column_widths = col_widths,
        cell_boxes = cell_boxes,
        total_height = total_height
      }
    end
  end

  return { ir = ir, table_layouts = table_layouts }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
