-- kernel/paragraph-break.lua
-- Breaks measured text runs into lines (total-fit line breaking).

local kernel = {}

function kernel.advertise()
  return {
    name = "paragraph-break",
    description = "Breaks measured text runs into lines (total-fit line breaking).",
    capabilities = {
      {
        name = "layout.paragraph",
        version = "1.2.0",
        inputs = {
          ir = "table",
          measurements = "table",
          resolved_styles = "table",
          page_width = "number"
        },
        outputs = {
          ir = "table",
          lines = "table"
        }
      }
    }
  }
end

local function break_text_into_lines(text, measurements, max_width)
  local glyphs = measurements.glyphs
  local lines = {}
  local current_line = { glyphs = {}, width = 0, start_idx = 1 }

  if not glyphs then
    return lines
  end

  for i, glyph in ipairs(glyphs) do
    if current_line.width + glyph.width > max_width and #current_line.glyphs > 0 then
      current_line.end_idx = i - 1
      lines[#lines + 1] = current_line
      current_line = { glyphs = {}, width = 0, start_idx = i }
    end
    current_line.glyphs[#current_line.glyphs + 1] = glyph
    current_line.width = current_line.width + glyph.width
  end

  if #current_line.glyphs > 0 then
    current_line.end_idx = #glyphs
    lines[#lines + 1] = current_line
  end

  return lines
end

kernel["layout.paragraph"] = function(inputs)
  local ir = inputs.ir
  local measurements = inputs.measurements or {}
  local resolved_styles = inputs.resolved_styles or {}
  local page_width = inputs.page_width or 612

  local all_lines = {}

  if not ir or not ir.nodes then
    return { ir = ir, lines = all_lines }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and measurements[node_id] then
      local style = resolved_styles[node_id] or {}
      local margin_left = style.margin_left or 0
      local margin_right = style.margin_right or 0
      local avail_width = page_width - margin_left - margin_right

      local lines = break_text_into_lines(node.content, measurements[node_id], avail_width)
      all_lines[node_id] = lines

      node.attributes = node.attributes or {}
      node.attributes.line_count = #lines
      node.attributes.line_height = measurements[node_id].height
    end
  end

  return { ir = ir, lines = all_lines }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
