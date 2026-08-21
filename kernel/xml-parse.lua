-- kernel/xml-parse.lua
-- Parses XML input into DoxTk IR using libxml2.

local kernel = {}

function kernel.advertise()
  return {
    name = "xml-parse",
    description = "Parses XML input into DoxTk IR using libxml2.",
    capabilities = {
      {
        name = "parse.xml",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          ir = "table"
        },
        services = { "libxml2.parse" }
      }
    }
  }
end

local function generate_node_id(counter)
  return "xml_" .. tostring(counter)
end

local function parse_xml(source, options)
  options = options or {}

  if libxml2 and libxml2.parse then
    local result = libxml2.parse(source, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: basic XML-to-IR parser
  local ir = { root = "xml_doc", nodes = {} }
  local counter = 0

  local function add_node(nodetype, content, attrs, children)
    counter = counter + 1
    local id = generate_node_id(counter)
    local node = {
      id = id,
      type = nodetype,
      attributes = attrs or {},
      children = children or {}
    }
    if content then
      node.content = content
    end
    ir.nodes[id] = node
    return id
  end

  local doc_id = add_node("document", nil, { format = "xml" })

  -- Parse XML elements
  local pos = 1
  local len = #source

  while pos <= len do
    -- Skip XML declaration and processing instructions
    if source:sub(pos, pos + 1) == "<?" then
      local close_pos = source:find("?>", pos, true)
      if close_pos then
        pos = close_pos + 2
      else
        pos = pos + 1
      end
    -- Skip comments
    elseif source:sub(pos, pos + 3) == "<!--" then
      local close_pos = source:find("-->", pos, true)
      if close_pos then
        pos = close_pos + 3
      else
        pos = pos + 1
      end
    -- Self-closing tag
    elseif source:sub(pos, pos) == "<" then
      local tag_end = source:find(">", pos, true)
      if not tag_end then
        pos = pos + 1
      else
        local tag_content = source:sub(pos + 1, tag_end - 1)
        local is_self_closing = tag_content:sub(-1) == "/"
        if is_self_closing then
          tag_content = tag_content:sub(1, -2)
        end
        local tag_name = tag_content:match("^(%w+)")
        local close_tag = "</" .. (tag_name or "") .. ">"
        local close_pos = source:find(close_tag, tag_end, true)

        if is_self_closing or not close_pos then
          local elem_id = add_node(tag_name or "element", nil, {})
          table.insert(ir.nodes[doc_id].children, elem_id)
          pos = tag_end + 1
        else
          local inner = source:sub(tag_end + 1, close_pos - 1)
          local elem_id = add_node(tag_name or "element", nil, {})
          local text_id = add_node("text", inner:match("^%s*(.-)%s*$"), {})
          table.insert(ir.nodes[elem_id].children, text_id)
          table.insert(ir.nodes[doc_id].children, elem_id)
          pos = close_pos + #close_tag
        end
      end
    else
      pos = pos + 1
    end
  end

  return ir
end

kernel["parse.xml"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local ir = parse_xml(source, options)

  return { ir = ir }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
