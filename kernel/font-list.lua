-- kernel/font-list.lua
-- Enumerates available fonts via fontconfig.
-- Lists fonts matching optional filter criteria.

local kernel = {}

function kernel.advertise()
  return {
    name = "font-list",
    description = "Enumerates available fonts via fontconfig.",
    capabilities = {
      {
        name = "font.list",
        version = "1.0.0",
        inputs = {
          filter = "table",
          objects = "table"
        },
        outputs = {
          fonts = "table"
        },
        services = { "fontconfig" }
      }
    }
  }
end

local function build_pattern(filter)
  if not filter or next(filter) == nil then
    return {}
  end
  local pattern = {}
  if filter.family then pattern.family = filter.family end
  if filter.style then pattern.style = filter.style end
  if filter.spacing then pattern.spacing = filter.spacing end
  if filter.scalable ~= nil then pattern.scalable = filter.scalable end
  if filter.outline ~= nil then pattern.outline = filter.outline end
  if filter.lang then pattern.lang = filter.lang end
  return pattern
end

local function build_objects(fields)
  local objects = {}
  if fields then
    for _, f in ipairs(fields) do
      objects[#objects + 1] = f
    end
  else
    objects = { "family", "style", "file", "index", "weight", "slant", "width", "scalable", "lang", "fontversion", "fullname", "foundry", "spacing", "outline" }
  end
  return objects
end

kernel["font.list"] = function(inputs)
  local filter = inputs.filter or {}
  local objects = inputs.objects
  local json = require("doxtk_ljson")

  local pattern = build_pattern(filter)
  local pattern_json = json.encode(pattern)
  local objects_arr = build_objects(objects)
  local objects_json = json.encode(objects_arr)

  local fonts = {}

  if fontconfig and fontconfig.list then
    local list_json = fontconfig.list(pattern_json, objects_json)
    if list_json and list_json ~= "" then
      local decoded = json.decode(list_json)
      if decoded then
        for _, v in pairs(decoded) do
          fonts[#fonts + 1] = v
        end
      end
    end
  end

  return { fonts = fonts }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
