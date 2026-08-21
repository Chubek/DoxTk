-- kernel/xref-resolve.lua
-- Resolves cross-reference targets to numbers and page anchors.

local kernel = {}

function kernel.advertise()
  return {
    name = "xref-resolve",
    description = "Resolves cross-reference targets to numbers and page anchors.",
    capabilities = {
      {
        name = "doc.xref",
        version = "1.0.0",
        inputs = {
          ir = "table",
          pages = "table"
        },
        outputs = {
          ir = "table",
          xref_map = "table"
        }
      }
    }
  }
end

local function build_target_map(ir, pages)
  local target_map = {}

  if not ir or not ir.nodes then
    return target_map
  end

  local counter = {}
  for _, page in ipairs(pages) do
    for _, block_id in ipairs(page.blocks) do
      local node = ir.nodes[block_id]
      if node and node.type == "section" then
        local level = node.attributes and node.attributes.level or 1
        counter[level] = (counter[level] or 0) + 1
        for l = level + 1, 6 do
          counter[l] = 0
        end
        local section_num = {}
        for l = 1, level do
          section_num[#section_num + 1] = tostring(counter[l] or 1)
        end
        target_map[block_id] = {
          number = table.concat(section_num, "."),
          page = page.page_number
        }
      end
    end
  end

  return target_map
end

local function resolve_xrefs(ir, target_map)
  if not ir or not ir.nodes then
    return ir
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "xref" then
      local target = node.attributes and node.attributes.target
      if target and target_map[target] then
        node.attributes = node.attributes or {}
        node.attributes.resolved_number = target_map[target].number
        node.attributes.resolved_page = target_map[target].page
      end
    end
  end

  return ir
end

kernel["doc.xref"] = function(inputs)
  local ir = inputs.ir
  local pages = inputs.pages or {}

  local target_map = build_target_map(ir, pages)
  ir = resolve_xrefs(ir, target_map)

  return { ir = ir, xref_map = target_map }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
