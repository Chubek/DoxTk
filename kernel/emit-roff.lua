-- kernel/emit-roff.lua
-- Serializes an IR graph to roff source for man-page output.

local kernel = {}

function kernel.advertise()
  return {
    name = "emit-roff",
    description = "Serializes an IR graph to roff source for man-page output.",
    capabilities = {
      {
        name = "emit.roff",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          title = "string",
          section = "string"
        },
        outputs = {
          roff = "string"
        }
      }
    }
  }
end

local function escape_roff(text)
  if not text then return "" end
  text = text:gsub("\\", "\\e")
  text = text:gsub("^%.", "\\&.")
  return text
end

local function render_node_roff(node, ir, resolved_styles)
  if not node then return "" end

  local content = node.content and escape_roff(node.content) or ""

  if node.type == "document" then
    local parts = {}
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node_roff(ir.nodes[child_id], ir, resolved_styles)
    end
    return table.concat(parts, "\n")

  elseif node.type == "section" then
    local level = (node.attributes and node.attributes.level) or 1
    local title = node.attributes and node.attributes.title or content
    local parts = {}
    if level == 1 then
      parts[#parts + 1] = ".SH " .. escape_roff(title)
    elseif level == 2 then
      parts[#parts + 1] = ".SS " .. escape_roff(title)
    else
      parts[#parts + 1] = ".PP"
      parts[#parts + 1] = "\\fB" .. escape_roff(title) .. "\\fP"
    end
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node_roff(ir.nodes[child_id], ir, resolved_styles)
    end
    return table.concat(parts, "\n")

  elseif node.type == "paragraph" then
    local parts = { ".PP" }
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node_roff(ir.nodes[child_id], ir, resolved_styles)
    end
    if content ~= "" then
      parts[#parts + 1] = content
    end
    return table.concat(parts, "\n")

  elseif node.type == "text" then
    return content

  elseif node.type == "table" then
    local parts = { ".TS", "allbox;", "l" .. string.rep(" l", (node.attributes and node.attributes.columns or 2) - 1) .. ".", ".TE" }
    return table.concat(parts, "\n")

  elseif node.type == "xref" then
    local label = node.attributes and node.attributes.resolved_number or content
    return "\\fI" .. escape_roff(label) .. "\\fP"

  elseif node.type == "image" then
    return "[IMAGE: " .. (node.attributes and node.attributes.src or "") .. "]"

  elseif node.type == "math" or node.type == "display_math" then
    return "\\fI" .. escape_roff(content) .. "\\fP"

  elseif node.type == "footnote" then
    return "\\*(" .. escape_roff(content) .. ")"

  else
    return content
  end
end

local function generate_roff(ir, resolved_styles, title, section)
  local parts = {}

  parts[#parts + 1] = '.TH "' .. escape_roff(title or "UNTITLED") .. '" "' .. escape_roff(section or "1") .. '"'
  parts[#parts + 1] = ".SH NAME"
  parts[#parts + 1] = escape_roff(title or "UNTITLED")

  if ir and ir.root then
    parts[#parts + 1] = render_node_roff(ir.nodes[ir.root], ir, resolved_styles)
  end

  return table.concat(parts, "\n")
end

kernel["emit.roff"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local title = inputs.title or "UNTITLED"
  local section = inputs.section or "1"

  local roff = generate_roff(ir, resolved_styles, title, section)

  return { roff = roff }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
