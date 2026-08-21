-- kernel/math-layout.lua
-- Lays out inline and display math into box trees.

local kernel = {}

function kernel.advertise()
  return {
    name = "math-layout",
    description = "Lays out inline and display math into box trees.",
    capabilities = {
      {
        name = "layout.math",
        version = "0.4.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          page_width = "number"
        },
        outputs = {
          ir = "table",
          math_boxes = "table"
        },
        services = { "haru.font" }
      }
    }
  }
end

local MATH_SYMBOL_WIDTHS = {
  ["="] = 0.8,
  ["+"] = 0.7,
  ["-"] = 0.5,
  ["x"] = 0.6,
  ["/"] = 0.4,
  ["("] = 0.4,
  [")"] = 0.4,
  ["["] = 0.4,
  ["]"] = 0.4,
  ["{"] = 0.4,
  ["}"] = 0.4,
  ["^"] = 0.4,
  ["_"] = 0.4,
  ["<"] = 0.7,
  [">"] = 0.7,
  ["*"] = 0.5,
  ["\\"] = 0.4,
  [","] = 0.3,
  ["."] = 0.3,
}

local function math_char_width(c, font_size)
  if MATH_SYMBOL_WIDTHS[c] then
    return MATH_SYMBOL_WIDTHS[c] * font_size
  end
  if c:match("[a-zA-Z]") then
    return 0.6 * font_size
  end
  if c:match("[0-9]") then
    return 0.55 * font_size
  end
  return 0.5 * font_size
end

local function layout_math_expr(expr, font_size, display_mode)
  local boxes = {}
  local total_width = 0
  local baseline = font_size * 0.4
  local max_above = baseline
  local max_below = font_size * 0.3

  local i = 1
  while i <= #expr do
    local c = expr:sub(i, i)

    if c == "^" and i < #expr then
      i = i + 1
      local c2 = expr:sub(i, i)
      local w = math_char_width(c2, font_size * 0.7)
      boxes[#boxes + 1] = {
        char = c2,
        x = total_width,
        y = -font_size * 0.3,
        width = w,
        height = font_size * 0.7,
        superscript = true
      }
      total_width = total_width + w
      max_above = math.max(max_above, font_size * 0.7 + font_size * 0.3)

    elseif c == "_" and i < #expr then
      i = i + 1
      local c2 = expr:sub(i, i)
      local w = math_char_width(c2, font_size * 0.7)
      boxes[#boxes + 1] = {
        char = c2,
        x = total_width,
        y = font_size * 0.2,
        width = w,
        height = font_size * 0.7,
        subscript = true
      }
      total_width = total_width + w
      max_below = math.max(max_below, font_size * 0.7 + font_size * 0.2)

    else
      local w = math_char_width(c, font_size)
      boxes[#boxes + 1] = {
        char = c,
        x = total_width,
        y = 0,
        width = w,
        height = font_size,
        baseline = baseline
      }
      total_width = total_width + w
    end

    i = i + 1
  end

  local total_height = max_above + max_below

  return {
    boxes = boxes,
    total_width = total_width,
    total_height = total_height,
    baseline = baseline,
    display_mode = display_mode
  }
end

kernel["layout.math"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local page_width = inputs.page_width or 612
  local math_boxes = {}

  if not ir or not ir.nodes then
    return { ir = ir, math_boxes = math_boxes }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and (node.type == "math" or node.type == "display_math") then
      local style = resolved_styles[node_id] or {}
      local font_size = style.font_size or 12
      local display_mode = (node.type == "display_math")
      local content = node.content or ""

      local layout = layout_math_expr(content, font_size, display_mode)

      node.attributes = node.attributes or {}
      node.attributes.math_width = layout.total_width
      node.attributes.math_height = layout.total_height

      math_boxes[node_id] = layout
    end
  end

  return { ir = ir, math_boxes = math_boxes }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
