-- kernel/md-parse.lua
-- Parses Markdown input into DoxTk IR using cmark-gfm.

local kernel = {}

function kernel.advertise()
  return {
    name = "md-parse",
    description = "Parses Markdown input into DoxTk IR using cmark-gfm.",
    capabilities = {
      {
        name = "parse.markdown",
        version = "1.0.0",
        inputs = {
          source = "string",
          options = "table"
        },
        outputs = {
          ir = "table"
        },
        services = { "cmark.parse" }
      }
    }
  }
end

local function generate_node_id(counter)
  return "md_" .. tostring(counter)
end

local function parse_markdown(source, options)
  options = options or {}
  local smart = options.smart or false
  local safe = options.safe or false
  local sourcepos = options.sourcepos or false

  if cmark and cmark.parse then
    local result = cmark.parse(source, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: basic Markdown-to-IR parser
  local ir = { root = "md_doc", nodes = {} }
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

  -- Document root
  local doc_id = add_node("document", nil, { format = "markdown" })

  -- Split into blocks by double newlines
  local blocks = {}
  for block in source:gmatch("[^\n]+") do
    local trimmed = block:match("^%s*(.-)%s*$")
    if trimmed ~= "" then
      blocks[#blocks + 1] = trimmed
    end
  end

  for _, block in ipairs(blocks) do
    -- Headers
    local level = block:match("^(#+)%s+(.+)")
    if level then
      local hash_count = #level:match("^(#+)")
      local text = block:match("^#+%s+(.+)")
      local heading_id = add_node("heading", text, { level = hash_count })
      table.insert(ir.nodes[doc_id].children, heading_id)
    -- Code blocks
    elseif block:match("^```") then
      local lang = block:match("^```(%w*)") or ""
      local code_id = add_node("code_block", nil, { language = lang })
      table.insert(ir.nodes[doc_id].children, code_id)
    -- Unordered list item
    elseif block:match("^[-*+]%s+") then
      local text = block:match("^[-*+]%s+(.+)")
      local item_id = add_node("list_item", nil, { list_type = "unordered" })
      local text_id = add_node("text", text, {})
      table.insert(ir.nodes[item_id].children, text_id)
      table.insert(ir.nodes[doc_id].children, item_id)
    -- Ordered list item
    elseif block:match("^%d+%.%s+") then
      local text = block:match("^%d+%.%s+(.+)")
      local item_id = add_node("list_item", nil, { list_type = "ordered" })
      local text_id = add_node("text", text, {})
      table.insert(ir.nodes[item_id].children, text_id)
      table.insert(ir.nodes[doc_id].children, item_id)
    -- Regular paragraph
    else
      local para_id = add_node("paragraph", nil, {})
      local text_id = add_node("text", block, {})
      table.insert(ir.nodes[para_id].children, text_id)
      table.insert(ir.nodes[doc_id].children, para_id)
    end
  end

  return ir
end

kernel["parse.markdown"] = function(inputs)
  local source = inputs.source or ""
  local options = inputs.options or {}

  local ir = parse_markdown(source, options)

  return { ir = ir }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
