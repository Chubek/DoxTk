-- kernel/toc-collect.lua
-- Collects heading nodes into a table-of-contents subgraph.

local kernel = {}

function kernel.advertise()
  return {
    name = "toc-collect",
    description = "Collects heading nodes into a table-of-contents subgraph.",
    capabilities = {
      {
        name = "doc.toc",
        version = "1.0.0",
        inputs = {
          ir = "table",
          pages = "table",
          max_depth = "number"
        },
        outputs = {
          ir = "table",
          toc_entries = "table"
        }
      }
    }
  }
end

local function collect_headings(ir, pages, max_depth)
  local entries = {}
  local counter = {}

  if not ir or not ir.nodes then
    return entries
  end

  local ordered_nodes = {}
  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "section" then
      ordered_nodes[#ordered_nodes + 1] = node
    end
  end

  table.sort(ordered_nodes, function(a, b)
    return (a.id or "") < (b.id or "")
  end)

  for _, node in ipairs(ordered_nodes) do
    local level = node.attributes and node.attributes.level or 1
    if level <= max_depth then
      counter[level] = (counter[level] or 0) + 1
      for l = level + 1, 6 do
        counter[l] = 0
      end

      local section_num = {}
      for l = 1, level do
        section_num[#section_num + 1] = tostring(counter[l] or 1)
      end

      local title = node.attributes and node.attributes.title or node.content or ""
      local page_num = nil
      for _, page in ipairs(pages) do
        for _, block_id in ipairs(page.blocks) do
          if block_id == node.id then
            page_num = page.page_number
            break
          end
        end
        if page_num then break end
      end

      entries[#entries + 1] = {
        id = node.id,
        title = title,
        number = table.concat(section_num, "."),
        level = level,
        page = page_num
      }
    end
  end

  return entries
end

kernel["doc.toc"] = function(inputs)
  local ir = inputs.ir
  local pages = inputs.pages or {}
  local max_depth = inputs.max_depth or 3

  local toc_entries = collect_headings(ir, pages, max_depth)

  return { ir = ir, toc_entries = toc_entries }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
