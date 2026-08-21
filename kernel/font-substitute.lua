-- kernel/font-substitute.lua
-- Resolves font fallback chains via fontconfig substitution.
-- Given a font specification, finds the best fallback fonts when
-- the requested font is not available.

local kernel = {}

function kernel.advertise()
  return {
    name = "font-substitute",
    description = "Resolves font fallback chains via fontconfig substitution.",
    capabilities = {
      {
        name = "font.substitute",
        version = "1.0.0",
        inputs = {
          font_spec = "table",
          objects = "table"
        },
        outputs = {
          fonts = "table",
          best_match = "table"
        },
        services = { "fontconfig" }
      }
    }
  }
end

local function build_pattern(spec)
  local pattern = {}
  if spec.family then pattern.family = spec.family end
  if spec.style then pattern.style = spec.style end
  if spec.weight then pattern.weight = spec.weight end
  if spec.slant then pattern.slant = spec.slant end
  if spec.width then pattern.width = spec.width end
  if spec.size then pattern.size = spec.size end
  if spec.spacing then pattern.spacing = spec.spacing end
  if spec.lang then pattern.lang = spec.lang end
  if spec.scalable ~= nil then pattern.scalable = spec.scalable end
  return pattern
end

local function build_objects(fields)
  local objects = {}
  if fields then
    for _, f in ipairs(fields) do
      objects[#objects + 1] = f
    end
  else
    objects = { "family", "style", "file", "index", "weight", "slant", "width", "scalable", "lang", "fullname" }
  end
  return objects
end

kernel["font.substitute"] = function(inputs)
  local font_spec = inputs.font_spec or {}
  local objects = inputs.objects
  local json = require("doxtk_ljson")

  local pattern = build_pattern(font_spec)
  local pattern_json = json.encode(pattern)
  local objects_arr = build_objects(objects)
  local objects_json = json.encode(objects_arr)

  local best_match = nil
  local fonts = {}

  if fontconfig and fontconfig.substitute then
    local sub_json = fontconfig.substitute(pattern_json)
    if sub_json and sub_json ~= "" then
      local substituted = json.decode(sub_json)
      if substituted then
        local match_json = fontconfig.match(sub_json)
        if match_json and match_json ~= "" then
          best_match = json.decode(match_json)
        end
        if fontconfig.sort then
          local sort_json = fontconfig.sort(sub_json, objects_json)
          if sort_json and sort_json ~= "" then
            local decoded = json.decode(sort_json)
            if decoded then
              for _, v in pairs(decoded) do
                fonts[#fonts + 1] = v
              end
            end
          end
        end
      end
    end
  end

  return {
    fonts = fonts,
    best_match = best_match or {}
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
