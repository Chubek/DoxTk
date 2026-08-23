-- kernel/css-parse.lua
-- Parses CSS stylesheets into structured data using libcss.

local kernel = {}

function kernel.advertise()
  return {
    name = "css-parse",
    description = "Parses CSS stylesheets into structured data using libcss.",
    capabilities = {
      {
        name = "parse.css",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          stylesheet = "table"
        },
        services = { "libcss.parse" }
      }
    }
  }
end

local function strip_comments(source)
  return source:gsub("/%*.-%*/", "")
end

local function parse_value(value_str)
  value_str = value_str:match("^%s*(.-)%s*$")
  if tonumber(value_str) then
    return tonumber(value_str)
  end
  if value_str:match("^[\"'].*[\"']$") then
    return value_str:sub(2, -2)
  end
  return value_str
end

local function parse_rule_block(block_str)
  local declarations = {}
  for decl in block_str:gmatch("[^;]+") do
    local prop, val = decl:match("^%s*(.-)%s*:%s*(.+)")
    if prop and val then
      prop = prop:match("^%s*(.-)%s*$")
      declarations[prop] = parse_value(val)
    end
  end
  return declarations
end

local function parse_css(source, options)
  options = options or {}

  if libcss and libcss.parse then
    local result = libcss.parse(source, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: basic CSS parser
  local stylesheet = {
    rules = {},
    media_queries = {},
    font_face = {},
    keyframes = {}
  }

  local cleaned = strip_comments(source)

  -- Extract @media blocks
  cleaned = cleaned:gsub("@media%s+([^{]+)%s*{(.-)}%s*}", function(query, body)
    local rules = {}
    for selector, block in body:gmatch("([^{]+)%s*{(.-)}") do
      rules[#rules + 1] = {
        selector = selector:match("^%s*(.-)%s*$"),
        declarations = parse_rule_block(block)
      }
    end
    stylesheet.media_queries[#stylesheet.media_queries + 1] = {
      query = query:match("^%s*(.-)%s*$"),
      rules = rules
    }
    return ""
  end)

  -- Extract @font-face blocks
  cleaned = cleaned:gsub("@font%-face%s*{(.-)}%s*", function(body)
    stylesheet.font_face[#stylesheet.font_face + 1] = parse_rule_block(body)
    return ""
  end)

  -- Extract @keyframes blocks
  cleaned = cleaned:gsub("@keyframes%s+([%w%-]+)%s*{(.-)}%s*}", function(name, body)
    local keyframes = { name = name, stops = {} }
    for stop_selector, block in body:gmatch("([^{]+)%s*{(.-)}") do
      keyframes.stops[#keyframes.stops + 1] = {
        selector = stop_selector:match("^%s*(.-)%s*$"),
        declarations = parse_rule_block(block)
      }
    end
    stylesheet.keyframes[#stylesheet.keyframes + 1] = keyframes
    return ""
  end)

  -- Parse remaining rule sets
  for selector, block in cleaned:gmatch("([^{]+)%s*{(.-)}") do
    local sel = selector:match("^%s*(.-)%s*$")
    if sel and #sel > 0 then
      stylesheet.rules[#stylesheet.rules + 1] = {
        selector = sel,
        declarations = parse_rule_block(block)
      }
    end
  end

  return stylesheet
end

kernel["parse.css"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local stylesheet = parse_css(source, options)

  return { stylesheet = stylesheet }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
