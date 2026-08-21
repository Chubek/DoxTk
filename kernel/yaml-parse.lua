-- kernel/yaml-parse.lua
-- Parses YAML input into structured data using libyaml.

local kernel = {}

function kernel.advertise()
  return {
    name = "yaml-parse",
    description = "Parses YAML input into structured data using libyaml.",
    capabilities = {
      {
        name = "parse.yaml",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          data = "table"
        },
        services = { "libyaml.parse" }
      }
    }
  }
end

local function parse_yaml(source, options)
  options = options or {}

  if libyaml and libyaml.parse then
    local result = libyaml.parse(source, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: basic YAML parser
  -- Supports scalars, mappings, sequences, and simple nesting
  local function parse_value(lines, start_idx)
    local idx = start_idx
    local indent = nil
    local result = nil

    while idx <= #lines do
      local line = lines[idx]
      if line:match("^%s*$") or line:match("^%s*#") then
        idx = idx + 1
      else
        local current_indent = #line:match("^(%s*)")
        if indent == nil then
          indent = current_indent
        end

        if current_indent < (indent or 0) then
          break
        end

        local stripped = line:sub(current_indent + 1)

        -- Sequence item
        if stripped:match("^%-%s") then
          if result == nil then
            result = {}
          end
          local val = stripped:sub(3)
          local nested = lines[idx + 1]
          if nested and #nested:match("^(%s*)") > current_indent then
            local nested_result, new_idx = parse_value(lines, idx + 1)
            result[#result + 1] = nested_result
            idx = new_idx
          elseif val:match("^[\"'].*[\"']$") then
            result[#result + 1] = val:sub(2, -2)
          elseif val == "true" then
            result[#result + 1] = true
          elseif val == "false" then
            result[#result + 1] = false
          elseif val == "null" or val == "~" then
            result[#result + 1] = nil
          elseif tonumber(val) then
            result[#result + 1] = tonumber(val)
          else
            result[#result + 1] = val
          end
          idx = idx + 1
        -- Mapping key: value
        elseif stripped:match("^[%w_]+%s*:") then
          if result == nil then
            result = {}
          end
          local key = stripped:match("^([%w_]+)%s*:")
          local val = stripped:match(":%s*(.+)")

          if val then
            if val:match("^[\"'].*[\"']$") then
              result[key] = val:sub(2, -2)
            elseif val == "true" then
              result[key] = true
            elseif val == "false" then
              result[key] = false
            elseif val == "null" or val == "~" then
              result[key] = nil
            elseif tonumber(val) then
              result[key] = tonumber(val)
            else
              result[key] = val
            end
            idx = idx + 1
          else
            -- Nested mapping or sequence
            local nested = lines[idx + 1]
            if nested then
              local nested_indent = #nested:match("^(%s*)")
              if nested_indent > current_indent then
                local nested_result, new_idx = parse_value(lines, idx + 1)
                result[key] = nested_result
                idx = new_idx
              else
                idx = idx + 1
              end
            else
              idx = idx + 1
            end
          end
        else
          idx = idx + 1
        end
      end
    end

    return result, idx
  end

  local lines = {}
  for line in source:gmatch("[^\n\r]+") do
    lines[#lines + 1] = line
  end

  local data = parse_value(lines, 1)
  return data or {}
end

kernel["parse.yaml"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local data = parse_yaml(source, options)

  return { data = data }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
