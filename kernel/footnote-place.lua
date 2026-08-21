-- kernel/footnote-place.lua
-- Places footnote bodies against their anchors within page columns.

local kernel = {}

function kernel.advertise()
  return {
    name = "footnote-place",
    description = "Places footnote bodies against their anchors within page columns.",
    capabilities = {
      {
        name = "layout.footnote",
        version = "1.0.0",
        inputs = {
          ir = "table",
          pages = "table",
          page_height = "number",
          page_width = "number"
        },
        outputs = {
          ir = "table",
          footnote_placements = "table"
        }
      }
    }
  }
end

local function collect_footnotes(ir)
  local footnotes = {}

  if not ir or not ir.nodes then
    return footnotes
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "footnote" then
      footnotes[#footnotes + 1] = {
        id = node_id,
        anchor = node.attributes and node.attributes.anchor,
        content = node.content,
        children = node.children
      }
    end
  end

  return footnotes
end

local function allocate_footnote_space(pages, footnotes, page_height)
  local placements = {}
  local footnote_idx = 1
  local footnote_reserve = page_height * 0.15

  for pi, page in ipairs(pages) do
    local y_offset = page_height - footnote_reserve
    local page_footnotes = {}

    for _, block_id in ipairs(page.blocks) do
      for _, fn in ipairs(footnotes) do
        if fn.anchor == block_id and footnote_idx <= #footnotes then
          page_footnotes[#page_footnotes + 1] = {
            id = fn.id,
            y = y_offset,
            page = pi,
            anchor = fn.anchor
          }
          y_offset = y_offset - 20
          footnote_idx = footnote_idx + 1
        end
      end
    end

    if #page_footnotes > 0 then
      placements[pi] = page_footnotes
    end
  end

  return placements
end

kernel["layout.footnote"] = function(inputs)
  local ir = inputs.ir
  local pages = inputs.pages or {}
  local page_height = inputs.page_height or 792
  local page_width = inputs.page_width or 612

  local footnotes_list = collect_footnotes(ir)
  local placements = allocate_footnote_space(pages, footnotes_list, page_height)

  return { ir = ir, footnote_placements = placements }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
