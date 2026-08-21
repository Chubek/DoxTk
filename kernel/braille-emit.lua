-- kernel/braille-emit.lua
-- Translates text into Braille using liblouis.

local kernel = {}

function kernel.advertise()
  return {
    name = "braille-emit",
    description = "Translates text into Braille using liblouis.",
    capabilities = {
      {
        name = "emit.braille",
        version = "1.0.0",
        inputs = {
          ir = "table",
          braille_table = "string",
          language = "string"
        },
        outputs = {
          ir = "table",
          braille_output = "table"
        },
        services = { "liblouis.translate" }
      }
    }
  }
end

local function translate_to_braille(text, braille_table, language)
  braille_table = braille_table or "en-ueb-g2.ctb"
  language = language or "en"

  if liblouis and liblouis.translate then
    local result = liblouis.translate(text, braille_table)
    if result then
      return result
    end
  end

  -- Pure-Lua fallback: Grade 1 English Braille mapping
  local braille_map = {
    ["a"] = "\u{2801}", ["b"] = "\u{2803}", ["c"] = "\u{2809}",
    ["d"] = "\u{2819}", ["e"] = "\u{2811}", ["f"] = "\u{280B}",
    ["g"] = "\u{281B}", ["h"] = "\u{2813}", ["i"] = "\u{280A}",
    ["j"] = "\u{281A}", ["k"] = "\u{2805}", ["l"] = "\u{2807}",
    ["m"] = "\u{280D}", ["n"] = "\u{281D}", ["o"] = "\u{2815}",
    ["p"] = "\u{280F}", ["q"] = "\u{281F}", ["r"] = "\u{2817}",
    ["s"] = "\u{280E}", ["t"] = "\u{281E}", ["u"] = "\u{2825}",
    ["v"] = "\u{2827}", ["w"] = "\u{283A}", ["x"] = "\u{282D}",
    ["y"] = "\u{283D}", ["z"] = "\u{2835}",
    [" "] = "\u{2800}", ["."] = "\u{2832}", [","] = "\u{2802}",
    ["?"] = "\u{2822}", ["!"] = "\u{2816}", ["-"] = "\u{2824}",
    ["'"] = "\u{2804}", ["\""] = "\u{2826}", [";"] = "\u{2806}",
    [":"] = "\u{2812}", ["("] = "\u{2836}", [")"] = "\u{2836}",
    ["/"] = "\u{280C}", ["#"] = "\u{283C}", ["0"] = "\u{281A}",
    ["1"] = "\u{2801}", ["2"] = "\u{2803}", ["3"] = "\u{2809}",
    ["4"] = "\u{2819}", ["5"] = "\u{2811}", ["6"] = "\u{280B}",
    ["7"] = "\u{281B}", ["8"] = "\u{2813}", ["9"] = "\u{280A}"
  }

  local result = ""
  local lower = text:lower()
  for i = 1, #lower do
    local c = lower:sub(i, i)
    result = result .. (braille_map[c] or c)
  end

  return {
    text = result,
    table = braille_table,
    language = language
  }
end

kernel["emit.braille"] = function(inputs)
  local ir = inputs.ir
  local braille_table = inputs.braille_table or "en-ueb-g2.ctb"
  local language = inputs.language or "en"
  local braille_output = {}

  if not ir or not ir.nodes then
    return { ir = ir, braille_output = braille_output }
  end

  for node_id, node in pairs(ir.nodes) do
    if type(node) == "table" and node.type == "text" and node.content then
      local translated = translate_to_braille(node.content, braille_table, language)
      braille_output[node_id] = translated
    end
  end

  return { ir = ir, braille_output = braille_output }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
