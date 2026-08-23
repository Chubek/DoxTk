-- kernel/cite-resolve.lua
-- Resolves citation keys in IR nodes against a bibliography, producing
-- numbered citation markers and a reference list.

local kernel = {}

function kernel.advertise()
  return {
    name = "cite-resolve",
    description = "Resolves citation keys in IR nodes against a bibliography.",
    capabilities = {
      {
        name = "doc.cite",
        version = "1.0.0",
        inputs = {
          ir = "table",
          bibliography = "table",
          style = "string"
        },
        outputs = {
          ir = "table",
          citation_map = "table",
          reference_order = "table"
        }
      }
    }
  }
end

local function collect_cite_nodes(ir)
  local cites = {}
  if not ir or not ir.nodes then
    return cites
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "cite" then
      local keys = {}
      if node.attributes and node.attributes.keys then
        if type(node.attributes.keys) == "string" then
          for key in node.attributes.keys:gmatch("[^,%s]+") do
            keys[#keys + 1] = key
          end
        elseif type(node.attributes.keys) == "table" then
          keys = node.attributes.keys
        end
      end
      cites[#cites + 1] = { node_id = node_id, keys = keys }
    end
  end

  return cites
end

local function build_reference_order(cites, bibliography)
  local seen = {}
  local order = {}

  for _, cite in ipairs(cites) do
    for _, key in ipairs(cite.keys) do
      if bibliography[key] and not seen[key] then
        seen[key] = true
        order[#order + 1] = key
      end
    end
  end

  return order
end

local function build_citation_map(cites, bibliography, reference_order)
  local number_map = {}
  for i, key in ipairs(reference_order) do
    number_map[key] = i
  end

  local citation_map = {}
  for _, cite in ipairs(cites) do
    local numbers = {}
    local keys = {}
    for _, key in ipairs(cite.keys) do
      if number_map[key] then
        numbers[#numbers + 1] = number_map[key]
        keys[#keys + 1] = key
      end
    end
    table.sort(numbers)
    citation_map[cite.node_id] = {
      numbers = numbers,
      keys = keys,
      marker = "[" .. table.concat(numbers, ", ") .. "]"
    }
  end

  return citation_map
end

local function resolve_cites(ir, citation_map)
  if not ir or not ir.nodes then
    return ir
  end

  for node_id, info in pairs(citation_map) do
    local node = ir.nodes[node_id]
    if node then
      node.attributes = node.attributes or {}
      node.attributes.citation_numbers = info.numbers
      node.attributes.citation_keys = info.keys
      node.attributes.citation_marker = info.marker
      node.content = info.marker
    end
  end

  return ir
end

kernel["doc.cite"] = function(inputs)
  local ir = inputs.ir
  local bibliography = inputs.bibliography or {}
  local style = inputs.style or "numeric"

  local cites = collect_cite_nodes(ir)
  local reference_order = build_reference_order(cites, bibliography)
  local citation_map = build_citation_map(cites, bibliography, reference_order)
  ir = resolve_cites(ir, citation_map)

  return {
    ir = ir,
    citation_map = citation_map,
    reference_order = reference_order
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
