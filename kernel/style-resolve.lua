-- kernel/style-resolve.lua
-- Resolves style attributes into computed per-node style records.

local kernel = {}

function kernel.advertise()
  return {
    name = "style-resolve",
    description = "Resolves style attributes into computed per-node style records.",
    capabilities = {
      {
        name = "style.resolve",
        version = "1.0.0",
        inputs = {
          ir = "table",
          stylesheet = "table"
        },
        outputs = {
          ir = "table",
          resolved_styles = "table"
        }
      }
    }
  }
end

local DEFAULT_STYLES = {
  font_family = "Liberation Serif",
  font_size = 12,
  line_height = 1.2,
  text_align = "left",
  color = "#000000",
  background = "transparent",
  margin_top = 0,
  margin_bottom = 0,
  margin_left = 0,
  margin_right = 0,
  padding_top = 0,
  padding_bottom = 0,
  padding_left = 0,
  padding_right = 0
}

local function merge_styles(base, override)
  local result = {}
  for k, v in pairs(base) do
    result[k] = v
  end
  if override then
    for k, v in pairs(override) do
      result[k] = v
    end
  end
  return result
end

local function resolve_node_style(node_type, node_attrs, stylesheet)
  local style = merge_styles(DEFAULT_STYLES)

  if stylesheet and stylesheet.defaults then
    style = merge_styles(style, stylesheet.defaults)
  end

  if stylesheet and stylesheet[node_type] then
    style = merge_styles(style, stylesheet[node_type])
  end

  if node_attrs and node_attrs.style then
    style = merge_styles(style, node_attrs.style)
  end

  return style
end

kernel["style.resolve"] = function(inputs)
  local ir = inputs.ir
  local stylesheet = inputs.stylesheet or {}
  local resolved = {}

  if not ir or not ir.nodes then
    return { ir = ir, resolved_styles = resolved }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" then
      resolved[node_id] = resolve_node_style(node.type, node.attributes, stylesheet)
    end
  end

  return { ir = ir, resolved_styles = resolved }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
