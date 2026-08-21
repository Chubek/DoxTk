-- kernel/font-match.lua
-- Matches font specifications to available fonts using fontconfig.

local kernel = {}

function kernel.advertise()
  return {
    name = "font-match",
    description = "Matches font specifications to available fonts using fontconfig.",
    capabilities = {
      {
        name = "font.match",
        version = "1.0.0",
        inputs = {
          font_spec = "table",
          objects = "table"
        },
        outputs = {
          best_match = "table",
          sorted_matches = "table"
        },
        services = { "fontconfig.match" }
      }
    }
  }
end

local function build_pattern(spec)
  local pattern = {}
  if not spec then
    return pattern
  end
  if spec.family then pattern.family = spec.family end
  if spec.style then pattern.style = spec.style end
  if spec.weight then pattern.weight = spec.weight end
  if spec.slant then pattern.slant = spec.slant end
  if spec.width then pattern.width = spec.width end
  if spec.size then pattern.size = spec.size end
  if spec.spacing then pattern.spacing = spec.spacing end
  if spec.scalable ~= nil then pattern.scalable = spec.scalable end
  if spec.lang then pattern.lang = spec.lang end
  return pattern
end

local function build_objects(fields)
  if fields then
    return fields
  end
  return { "family", "style", "file", "index", "weight", "slant", "width", "scalable", "lang", "fontversion", "fullname", "foundry" }
end

kernel["font.match"] = function(inputs)
  local font_spec = inputs.font_spec or {}
  local objects = inputs.objects
  local json = require("doxtk_ljson")

  local pattern = build_pattern(font_spec)
  local pattern_json = json.encode(pattern)
  local objects_arr = build_objects(objects)
  local objects_json = json.encode(objects_arr)

  local best_match = {}
  local sorted_matches = {}

  if fontconfig and fontconfig.match then
    local match_json = fontconfig.match(pattern_json)
    if match_json and match_json ~= "" then
      best_match = json.decode(match_json) or {}
    end

    if fontconfig.sort then
      local sort_json = fontconfig.sort(pattern_json, objects_json)
      if sort_json and sort_json ~= "" then
        local decoded = json.decode(sort_json)
        if decoded then
          for _, v in ipairs(decoded) do
            sorted_matches[#sorted_matches + 1] = v
          end
        end
      end
    end
  end

  return {
    best_match = best_match,
    sorted_matches = sorted_matches
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
