-- kernel/graph-render.lua
-- Renders graph descriptions into diagrams using Graphviz.

local kernel = {}

function kernel.advertise()
  return {
    name = "graph-render",
    description = "Renders graph descriptions into diagrams using Graphviz.",
    capabilities = {
      {
        name = "graphics.diagram",
        version = "1.0.0",
        inputs = {
          graph_source = "string",
          format = "string",
          engine = "string",
          options = "table"
        },
        outputs = {
          diagram_data = "string",
          diagram_info = "table"
        },
        services = { "graphviz.layout" }
      }
    }
  }
end

local function render_graph(graph_source, format, engine, options)
  format = format or "svg"
  engine = engine or "dot"
  options = options or {}

  if graphviz and graphviz.layout then
    local result = graphviz.layout(graph_source, format, engine, options)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: return source as-is
  return {
    data = graph_source,
    format = format,
    engine = engine,
    bounding_box = { x = 0, y = 0, width = 0, height = 0 },
    node_count = 0,
    edge_count = 0
  }
end

kernel["graphics.diagram"] = function(inputs)
  local graph_source = inputs.graph_source or ""
  local format = inputs.format or "svg"
  local engine = inputs.engine or "dot"
  local options = inputs.options or {}

  local result = render_graph(graph_source, format, engine, options)

  return {
    diagram_data = result.data,
    diagram_info = {
      format = result.format,
      engine = result.engine,
      bounding_box = result.bounding_box,
      node_count = result.node_count,
      edge_count = result.edge_count
    }
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
