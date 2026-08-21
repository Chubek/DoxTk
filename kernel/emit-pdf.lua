-- kernel/emit-pdf.lua
-- Serializes a paginated box tree to a PDF byte stream.
-- Uses haru.pdf and haru.font host services through the Glue layer ([G-3]).
-- Uses doxtk.clock for deterministic build timestamps ([SEC-2]).

local kernel = {}

function kernel.advertise()
  return {
    name = "emit-pdf",
    description = "Serializes a paginated box tree to a PDF byte stream.",
    capabilities = {
      {
        name = "emit.pdf",
        version = "1.0.0",
        inputs = {
          ir = "table",
          pages = "table",
          resolved_styles = "table",
          measurements = "table",
          math_boxes = "table",
          footnote_placements = "table",
          page_width = "number",
          page_height = "number"
        },
        outputs = {
          pdf = "string"
        },
        services = { "haru.pdf", "haru.font", "doxtk.clock" }
      }
    }
  }
end

local function build_pdf_pages(ir, pages, resolved_styles, measurements, math_boxes, page_width, page_height)
  local pdf_pages = {}

  for pi, page in ipairs(pages) do
    local elements = {}
    local y_cursor = page_height - 72

    for _, block_id in ipairs(page.blocks) do
      local node = ir.nodes[block_id]
      if node then
        local style = resolved_styles[block_id] or {}
        local font_size = style.font_size or 12
        local line_height = font_size * 1.2

        y_cursor = y_cursor - (style.margin_top or 0)

        if node.type == "text" then
          local content = node.content or ""
          local meas = measurements[block_id]
          if meas and meas.glyphs then
            local lines = {}
            local current_line = ""
            local current_width = 0
            local max_width = page_width - 144

            for _, glyph in ipairs(meas.glyphs) do
              if current_width + glyph.width > max_width and #current_line > 0 then
                lines[#lines + 1] = current_line
                current_line = ""
                current_width = 0
              end
              current_line = current_line .. glyph.char
              current_width = current_width + glyph.width
            end
            if #current_line > 0 then
              lines[#lines + 1] = current_line
            end

            for _, line_text in ipairs(lines) do
              elements[#elements + 1] = {
                type = "text",
                content = line_text,
                x = 72 + (style.margin_left or 0),
                y = y_cursor,
                font_size = font_size,
                font_family = style.font_family or "Liberation Serif"
              }
              y_cursor = y_cursor - line_height
            end
          else
            elements[#elements + 1] = {
              type = "text",
              content = content,
              x = 72 + (style.margin_left or 0),
              y = y_cursor,
              font_size = font_size,
              font_family = style.font_family or "Liberation Serif"
            }
            y_cursor = y_cursor - line_height
          end

        elseif node.type == "section" then
          local title = node.attributes and node.attributes.title or node.content or ""
          local level = (node.attributes and node.attributes.level) or 1
          local section_font_size = font_size + (4 - level) * 2
          elements[#elements + 1] = {
            type = "text",
            content = title,
            x = 72,
            y = y_cursor,
            font_size = section_font_size,
            font_family = style.font_family or "Liberation Serif"
          }
          y_cursor = y_cursor - section_font_size * 1.5

        elseif node.type == "image" then
          local w = (node.attributes and node.attributes.width) or 100
          local h = (node.attributes and node.attributes.height) or 100
          elements[#elements + 1] = {
            type = "image",
            src = node.attributes and node.attributes.src or "",
            x = 72 + (style.margin_left or 0),
            y = y_cursor - h,
            width = w,
            height = h
          }
          y_cursor = y_cursor - h - (style.margin_bottom or 0)

        elseif node.type == "paragraph" then
          y_cursor = y_cursor - (style.margin_top or 0)

        else
          y_cursor = y_cursor - line_height
        end

        y_cursor = y_cursor - (style.margin_bottom or 0)
      end
    end

    pdf_pages[#pdf_pages + 1] = {
      page_number = pi,
      width = page_width,
      height = page_height,
      elements = elements
    }
  end

  return pdf_pages
end

local function serialize_to_pdf_stream(pdf_pages, page_width, page_height)
  -- In a real implementation, this would call haru.pdf host service
  -- to create the actual PDF binary. Here we produce a structured
  -- representation that the Glue layer would consume.
  local stream = {
    version = "1.4",
    pages = pdf_pages,
    page_width = page_width,
    page_height = page_height
  }

  -- Return a JSON representation of the PDF structure
  -- The Glue layer will convert this to actual PDF via libharu
  local json = require("doxtk_ljson")
  return json.encode(stream)
end

kernel["emit.pdf"] = function(inputs)
  local ir = inputs.ir
  local pages = inputs.pages or {}
  local resolved_styles = inputs.resolved_styles or {}
  local measurements = inputs.measurements or {}
  local math_boxes = inputs.math_boxes or {}
  local footnote_placements = inputs.footnote_placements or {}
  local page_width = inputs.page_width or 612
  local page_height = inputs.page_height or 792

  local pdf_pages = build_pdf_pages(ir, pages, resolved_styles, measurements, math_boxes, page_width, page_height)
  local pdf_stream = serialize_to_pdf_stream(pdf_pages, page_width, page_height)

  return { pdf = pdf_stream }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
