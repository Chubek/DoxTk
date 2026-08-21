-- kernel/ir-validate.lua
-- Validates an IR graph against the DoxTk IR JSON Schema ([I-2], [I-3]).

local kernel = {}

function kernel.advertise()
  return {
    name = "ir-validate",
    description = "Validates an IR graph against the IR JSON Schema.",
    capabilities = {
      {
        name = "ir.validate",
        version = "1.0.0",
        inputs = {
          ir = "table",
          schema = "table"
        },
        outputs = {
          valid = "boolean",
          errors = "table"
        },
        services = { "doxtk.json" }
      }
    }
  }
end

local function validate_node(node, node_id)
  local errors = {}

  if type(node.id) ~= "string" then
    errors[#errors + 1] = "node." .. node_id .. ".id: expected string, got " .. type(node.id)
  end
  if type(node.type) ~= "string" then
    errors[#errors + 1] = "node." .. node_id .. ".type: expected string, got " .. type(node.type)
  end
  if type(node.attributes) ~= "table" then
    errors[#errors + 1] = "node." .. node_id .. ".attributes: expected table, got " .. type(node.attributes)
  end
  if type(node.children) ~= "table" then
    errors[#errors + 1] = "node." .. node_id .. ".children: expected table, got " .. type(node.children)
  end
  if node.content ~= nil and type(node.content) ~= "string" then
    errors[#errors + 1] = "node." .. node_id .. ".content: expected string or nil, got " .. type(node.content)
  end

  return errors
end

local function validate_ir(ir)
  local errors = {}

  if type(ir) ~= "table" then
    errors[#errors + 1] = "ir: expected table, got " .. type(ir)
    return errors
  end

  if type(ir.root) ~= "string" then
    errors[#errors + 1] = "ir.root: expected string, got " .. type(ir.root)
  end

  if type(ir.nodes) ~= "table" then
    errors[#errors + 1] = "ir.nodes: expected table, got " .. type(ir.nodes)
    return errors
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) ~= "table" then
      errors[#errors + 1] = "ir.nodes." .. tostring(node_id) .. ": expected table, got " .. type(node)
    else
      local node_errors = validate_node(node, node_id)
      for _, err in ipairs(node_errors) do
        errors[#errors + 1] = err
      end
    end
  end

  if ir.root and ir.nodes and not ir.nodes[ir.root] then
    errors[#errors + 1] = "ir.root: '" .. ir.root .. "' not found in ir.nodes"
  end

  if ir.nodes then
    for node_id, node in pairs(ir.nodes) do
      if type(node) == "table" and type(node.children) == "table" then
        for _, child_id in ipairs(node.children) do
          if not ir.nodes[child_id] then
            errors[#errors + 1] = "node." .. node_id .. ".children: '" .. child_id .. "' not found in ir.nodes"
          end
        end
      end
    end
  end

  return errors
end

kernel["ir.validate"] = function(inputs)
  local ir = inputs.ir
  local errors = validate_ir(ir)

  return {
    valid = (#errors == 0),
    errors = errors
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
