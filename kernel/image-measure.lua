-- kernel/image-measure.lua
-- Derives intrinsic and scaled dimensions for image nodes.

local kernel = {}

function kernel.advertise()
  return {
    name = "image-measure",
    description = "Derives intrinsic and scaled dimensions for image nodes.",
    capabilities = {
      {
        name = "layout.image",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          page_width = "number"
        },
        outputs = {
          ir = "table",
          image_metrics = "table"
        }
      }
    }
  }
end

local DEFAULT_IMAGE_DIMS = {
  width = 300,
  height = 200,
  aspect_ratio = 1.5
}

local function compute_image_dimensions(node, resolved_styles, page_width)
  local style = resolved_styles[node.id] or {}
  local attrs = node.attributes or {}

  local intrinsic_width = attrs.width or DEFAULT_IMAGE_DIMS.width
  local intrinsic_height = attrs.height or DEFAULT_IMAGE_DIMS.height
  local aspect_ratio = intrinsic_width / intrinsic_height

  local margin_left = style.margin_left or 0
  local margin_right = style.margin_right or 0
  local max_width = page_width - margin_left - margin_right

  local display_width = intrinsic_width
  local display_height = intrinsic_height

  if display_width > max_width then
    display_width = max_width
    display_height = display_width / aspect_ratio
  end

  if attrs.scale then
    display_width = display_width * attrs.scale
    display_height = display_height * attrs.scale
  end

  return {
    intrinsic_width = intrinsic_width,
    intrinsic_height = intrinsic_height,
    display_width = display_width,
    display_height = display_height,
    aspect_ratio = aspect_ratio
  }
end

kernel["layout.image"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local page_width = inputs.page_width or 612
  local image_metrics = {}

  if not ir or not ir.nodes then
    return { ir = ir, image_metrics = image_metrics }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "image" then
      local dims = compute_image_dimensions(node, resolved_styles, page_width)

      node.attributes = node.attributes or {}
      node.attributes.width = dims.display_width
      node.attributes.height = dims.display_height

      image_metrics[node_id] = dims
    end
  end

  return { ir = ir, image_metrics = image_metrics }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
