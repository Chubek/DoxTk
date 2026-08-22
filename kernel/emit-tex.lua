-- kernel/emit-tex.lua
-- Serializes an IR graph to a Plain TeX byte stream.
-- TeX command authority: third_party/TeXScrape/PlainTeX/PlainTeX.tex

local kernel = {}

function kernel.advertise()
  return {
    name = "emit-tex",
    description = "Serializes an IR graph to a Plain TeX byte stream.",
    capabilities = {
      {
        name = "emit.tex",
        version = "1.0.0",
        inputs = {
          ir = "table",
          resolved_styles = "table",
          pages = "table",
          toc_entries = "table"
        },
        outputs = {
          tex = "string"
        }
      }
    }
  }
end

-- TeX special characters that must be escaped in text content.
-- Source: PlainTeX.tex catcode definitions (lines 27-38).
local TEX_ESCAPE_MAP = {
  ["\\"] = "\\textbackslash{}",
  ["{"]  = "\\{",
  ["}"]  = "\\}",
  ["$"]  = "\\$",
  ["&"]  = "\\&",
  ["#"]  = "\\#",
  ["^"]  = "\\^{}",
  ["_"]  = "\\_",
  ["~"]  = "\\~{}",
  ["%"]  = "\\%",
}

local function escape_tex(text)
  if not text then return "" end
  return (text:gsub("([\\{}%$&#^_~%%])", TEX_ESCAPE_MAP))
end

-- Font switching commands from PlainTeX.tex lines 478-491.
-- \rm (roman), \bf (bold), \it (italic), \sl (slanted), \tt (typewriter)
local FONT_COMMANDS = {
  ["roman"]      = "\\rm",
  ["bold"]       = "\\bf",
  ["italic"]     = "\\it",
  ["slanted"]    = "\\sl",
  ["typewriter"] = "\\tt",
}

local function font_cmd(style)
  if not style or not style.font_family then return "" end
  return FONT_COMMANDS[style.font_family:lower()] or ""
end

-- Spacing commands from PlainTeX.tex lines 539-541.
local SPACING = {
  small = "\\smallskip",
  medium = "\\medskip",
  big = "\\bigskip",
}

local function render_node(node, ir, resolved_styles)
  if not node then return "" end

  local style = (resolved_styles and resolved_styles[node.id]) or {}
  local content = node.content and escape_tex(node.content) or ""
  local font = font_cmd(style)

  if node.type == "document" then
    local parts = {}
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    parts[#parts + 1] = "\\bye"
    return table.concat(parts, "\n\n")

  -- Sections: use \beginsection from PlainTeX.tex line 640.
  elseif node.type == "section" then
    local level = (node.attributes and node.attributes.level) or 1
    local title = node.attributes and node.attributes.title or content
    local escaped_title = escape_tex(title)
    local parts = {}

    if level == 1 then
      parts[#parts + 1] = "\\beginsection{" .. escaped_title .. "}\\par"
    elseif level == 2 then
      parts[#parts + 1] = "\\medskip"
      parts[#parts + 1] = "{\\bf " .. escaped_title .. "}\\par"
      parts[#parts + 1] = "\\smallskip\\noindent"
    else
      parts[#parts + 1] = "\\smallskip"
      parts[#parts + 1] = "{\\it " .. escaped_title .. "}\\par"
      parts[#parts + 1] = "\\noindent"
    end

    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    return table.concat(parts, "\n")

  -- Paragraphs: Plain TeX uses \par or blank lines.
  elseif node.type == "paragraph" then
    local parts = {}
    local indent = (node.attributes and node.attributes.indent) or true
    if not indent then
      parts[#parts + 1] = "\\noindent"
    end

    local body = {}
    if font ~= "" then
      body[#body + 1] = "{"
      body[#body + 1] = font .. " "
    end
    for _, child_id in ipairs(node.children or {}) do
      body[#body + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    if content ~= "" then
      body[#body + 1] = content
    end
    if font ~= "" then
      body[#body + 1] = "}"
    end
    parts[#parts + 1] = table.concat(body, "")
    parts[#parts + 1] = "\\par"
    return table.concat(parts, "\n")

  -- Text nodes: inline content with optional font.
  elseif node.type == "text" then
    if font ~= "" then
      return "{" .. font .. " " .. content .. "}"
    else
      return content
    end

  -- Emphasis variants: use Plain TeX font commands.
  elseif node.type == "bold" then
    return "{\\bf " .. escape_tex(content) .. "}"

  elseif node.type == "italic" or node.type == "emphasis" then
    return "{\\it " .. escape_tex(content) .. "}"

  elseif node.type == "code" or node.type == "monospace" then
    return "{\\tt " .. escape_tex(content) .. "}"

  -- Math: inline ($...$) and display ($$...$$) from PlainTeX.tex math section.
  elseif node.type == "math" then
    return "$" .. content .. "$"

  elseif node.type == "display_math" then
    return "$$" .. content .. "$$"

  -- Lists: use \item from PlainTeX.tex line 637.
  elseif node.type == "itemize" or node.type == "enumerate" then
    local parts = {}
    for _, child_id in ipairs(node.children or {}) do
      local child = ir.nodes[child_id]
      if child then
        if child.type == "item" then
          local item_content = child.content and escape_tex(child.content) or ""
          local item_body = {}
          for _, gc_id in ipairs(child.children or {}) do
            item_body[#item_body + 1] = render_node(ir.nodes[gc_id], ir, resolved_styles)
          end
          if item_content ~= "" then
            item_body[#item_body + 1] = item_content
          end
          parts[#parts + 1] = "\\item{" .. table.concat(item_body, "") .. "}"
        else
          parts[#parts + 1] = render_node(child, ir, resolved_styles)
        end
      end
    end
    return table.concat(parts, "\n")

  -- Tables: use \halign from PlainTeX.tex.
  elseif node.type == "table" then
    local rows = node.attributes and node.attributes.rows or 1
    local cols = node.attributes and node.attributes.columns or 1
    local parts = {}

    parts[#parts + 1] = "\\medskip"
    parts[#parts + 1] = "\\vbox{\\offinterlineskip"
    parts[#parts + 1] = "\\halign{\\strut\\hfil#\\hfil&" .. string.rep("\\hfil#\\hfil&", cols - 1) .. "\\hfil#\\hfil\\cr"

    for r = 1, rows do
      local row_cells = {}
      for c = 1, cols do
        row_cells[#row_cells + 1] = ""
      end
      parts[#parts + 1] = "\\noalign{\\hrule}"
      parts[#parts + 1] = table.concat(row_cells, "&") .. "\\cr"
    end
    parts[#parts + 1] = "\\noalign{\\hrule}"
    parts[#parts + 1] = "}}"
    parts[#parts + 1] = "\\medskip"
    return table.concat(parts, "\n")

  -- Images: use \vbox and \hbox for placement.
  elseif node.type == "image" then
    local src = node.attributes and node.attributes.src or ""
    local alt = node.attributes and node.attributes.alt or ""
    local parts = {
      "\\medskip",
      "\\centerline{\\vbox{",
      "  \\hbox{" .. escape_tex("[Image: " .. src .. "]") .. "}",
      "  \\hbox{\\it " .. escape_tex(alt) .. "}",
      "}}",
      "\\medskip"
    }
    return table.concat(parts, "\n")

  -- Horizontal rules: \hrulefill from PlainTeX.tex line 703.
  elseif node.type == "rule" or node.type == "horizontal_rule" then
    return "\\medskip\\hrulefill\\medskip"

  -- Footnotes: \footnote from PlainTeX.tex line 810.
  elseif node.type == "footnote" then
    local mark = escape_tex(content)
    return "\\footnote{" .. mark .. "}{" .. mark .. "}"

  -- Cross-references.
  elseif node.type == "xref" then
    local target = node.attributes and node.attributes.target or ""
    local label = node.attributes and node.attributes.resolved_number or content
    return "{\\it " .. escape_tex(label) .. "}"

  -- Block quotes: use \narrower from PlainTeX.tex line 638.
  elseif node.type == "blockquote" then
    local parts = { "\\medskip", "{\\narrower" }
    for _, child_id in ipairs(node.children or {}) do
      parts[#parts + 1] = render_node(ir.nodes[child_id], ir, resolved_styles)
    end
    if content ~= "" then
      parts[#parts + 1] = content
    end
    parts[#parts + 1] = "}"
    parts[#parts + 1] = "\\medskip"
    return table.concat(parts, "\n")

  -- Verbatim: use \tt and \obeyspaces/\obeylines from PlainTeX.tex lines 519-524.
  elseif node.type == "verbatim" or node.type == "code_block" then
    local parts = {
      "\\medskip",
      "{\\tt",
      content,
      "}",
      "\\medskip"
    }
    return table.concat(parts, "\n")

  -- Line breaks.
  elseif node.type == "linebreak" or node.type == "break" then
    return "\\break"

  -- Centered text.
  elseif node.type == "center" then
    return "\\centerline{" .. escape_tex(content) .. "}"

  else
    return content
  end
end

local function generate_tex(ir, resolved_styles, pages, toc_entries)
  local parts = {}

  -- TeX preamble: document setup per PlainTeX conventions.
  parts[#parts + 1] = "% DoxTk emit-tex output"
  parts[#parts + 1] = "% Generated from IR via Plain TeX format"
  parts[#parts + 1] = "\\input plain"
  parts[#parts + 1] = ""
  parts[#parts + 1] = "\\nopagenumbers"
  parts[#parts + 1] = ""

  -- Table of contents if present.
  if toc_entries and #toc_entries > 0 then
    parts[#parts + 1] = "\\beginsection{Contents}\\par"
    for _, entry in ipairs(toc_entries) do
      parts[#parts + 1] = "\\item{" .. escape_tex(entry.number) .. " " .. escape_tex(entry.title) .. "}"
    end
    parts[#parts + 1] = "\\bigskip"
    parts[#parts + 1] = ""
  end

  -- Render the IR body.
  if ir and ir.root then
    parts[#parts + 1] = render_node(ir.nodes[ir.root], ir, resolved_styles)
  end

  return table.concat(parts, "\n")
end

kernel["emit.tex"] = function(inputs)
  local ir = inputs.ir
  local resolved_styles = inputs.resolved_styles or {}
  local pages = inputs.pages or {}
  local toc_entries = inputs.toc_entries or {}

  local tex = generate_tex(ir, resolved_styles, pages, toc_entries)

  return { tex = tex }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
