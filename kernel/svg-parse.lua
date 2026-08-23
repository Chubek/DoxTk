-- kernel/svg-parse.lua
-- Parses SVG input into structured shape data using nanosvg.

local kernel = {}

function kernel.advertise()
  return {
    name = "svg-parse",
    description = "Parses SVG input into structured shape data using nanosvg.",
    capabilities = {
      {
        name = "parse.svg",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          shapes = "table"
        },
        services = { "nanosvg.parse" }
      }
    }
  }
end

local function parse_svg(source, options)
  options = options or {}
  local units = options.units or "px"
  local dpi = options.dpi or 96

  if nanosvg and nanosvg.parse then
    local result = nanosvg.parse(source, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: basic SVG-to-shapes parser
  local shapes = {
    width = 0,
    height = 0,
    viewBox = nil,
    paths = {},
    groups = {},
    defs = {},
    metadata = {}
  }

  -- Extract viewBox
  local vb = source:match('viewBox%s*=%s*["\']([^"\']+)["\']')
  if vb then
    local parts = {}
    for part in vb:gmatch("[%d.-]+") do
      parts[#parts + 1] = tonumber(part)
    end
    if #parts == 4 then
      shapes.viewBox = {
        x = parts[1],
        y = parts[2],
        width = parts[3],
        height = parts[4]
      }
    end
  end

  -- Extract width/height
  local w = source:match('width%s*=%s*["\']([%d.]+)')
  local h = source:match('height%s*=%s*["\']([%d.]+)')
  if w then shapes.width = tonumber(w) end
  if h then shapes.height = tonumber(h) end

  -- Parse <path> elements
  for d_attr in source:gmatch('<path[^>]*d%s*=%s*["\']([^"\']+)["\']') do
    shapes.paths[#shapes.paths + 1] = {
      type = "path",
      d = d_attr
    }
  end

  -- Parse <rect> elements
  for rx, ry, rw, rh in source:gmatch('<rect[^>]*x%s*=%s*["\']([%d.]+)["\'][^>]*y%s*=%s*["\']([%d.]+)["\'][^>]*width%s*=%s*["\']([%d.]+)["\'][^>]*height%s*=%s*["\']([%d.]+)["\']') do
    shapes.paths[#shapes.paths + 1] = {
      type = "rect",
      x = tonumber(rx),
      y = tonumber(ry),
      width = tonumber(rw),
      height = tonumber(rh)
    }
  end

  -- Parse <circle> elements
  for cx, cy, cr in source:gmatch('<circle[^>]*cx%s*=%s*["\']([%d.]+)["\'][^>]*cy%s*=%s*["\']([%d.]+)["\'][^>]*r%s*=%s*["\']([%d.]+)["\']') do
    shapes.paths[#shapes.paths + 1] = {
      type = "circle",
      cx = tonumber(cx),
      cy = tonumber(cy),
      r = tonumber(cr)
    }
  end

  -- Parse <ellipse> elements
  for cx, cy, rx, ry in source:gmatch('<ellipse[^>]*cx%s*=%s*["\']([%d.]+)["\'][^>]*cy%s*=%s*["\']([%d.]+)["\'][^>]*rx%s*=%s*["\']([%d.]+)["\'][^>]*ry%s*=%s*["\']([%d.]+)["\']') do
    shapes.paths[#shapes.paths + 1] = {
      type = "ellipse",
      cx = tonumber(cx),
      cy = tonumber(cy),
      rx = tonumber(rx),
      ry = tonumber(ry)
    }
  end

  -- Parse <line> elements
  for x1, y1, x2, y2 in source:gmatch('<line[^>]*x1%s*=%s*["\']([%d.]+)["\'][^>]*y1%s*=%s*["\']([%d.]+)["\'][^>]*x2%s*=%s*["\']([%d.]+)["\'][^>]*y2%s*=%s*["\']([%d.]+)["\']') do
    shapes.paths[#shapes.paths + 1] = {
      type = "line",
      x1 = tonumber(x1),
      y1 = tonumber(y1),
      x2 = tonumber(x2),
      y2 = tonumber(y2)
    }
  end

  -- Parse <polygon> and <polyline> elements
  for points_attr in source:gmatch('<poly[^>]*points%s*=%s*["\']([^"\']+)["\']') do
    local points = {}
    for px, py in points_attr:gmatch("([%d.]+),([%d.]+)") do
      points[#points + 1] = { x = tonumber(px), y = tonumber(py) }
    end
    if #points > 0 then
      shapes.paths[#shapes.paths + 1] = {
        type = "polygon",
        points = points
      }
    end
  end

  shapes.metadata.units = units
  shapes.metadata.dpi = dpi

  return shapes
end

kernel["parse.svg"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local shapes = parse_svg(source, options)

  return { shapes = shapes }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
