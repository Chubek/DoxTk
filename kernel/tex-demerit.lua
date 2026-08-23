-- kernel/tex-demerit.lua
-- Implements TeX's demerit calculation for the total-fit line breaking
-- algorithm. Demerits are the cost function that TeX minimises when
-- choosing optimal breakpoints for a paragraph.
--
-- Reference: TeX: The Program, §851–§859.
-- Reference: The TeXbook, Chapter 14 (How TeX Breaks Paragraphs into Lines).
-- Reference: Knuth & Plass (1981), "Breaking Paragraphs into Lines",
--   Software—Practice and Experience, Vol. 11, 1119–1184.
--
-- Core demerit formula (§858):
--   d = (l + b)^2 + p + a
--
--   l = line penalty (\linepenalty, default 10)
--   b = badness of the line (0–10000)
--   p = penalty at the breakpoint (e.g., hyphen penalty)
--   a = additional demerits for adjacency, double hyphens, final hyphens
--
-- Capability: tex.demerit — compute demerits for a single line/breakpoint.
-- Capability: tex.demerit.adjacent — compute adjacent-line demerits.
-- Capability: tex.demerit.fitness — classify fitness of a line from its ratio.

local kernel = {}

function kernel.advertise()
  return {
    name = "tex-demerit",
    description = "Implements TeX's demerit calculation for total-fit line breaking.",
    capabilities = {
      {
        name = "tex.demerit",
        version = "1.0.0",
        inputs = {
          badness = "number",
          line_penalty = "number",
          break_penalty = "number",
          adj_demerits = "number",
          double_hyphen_demerits = "number",
          final_hyphen_demerits = "number",
          is_hyphenated = "boolean",
          prev_hyphenated = "boolean",
          is_final_line = "boolean",
          current_fitness = "number",
          prev_fitness = "number"
        },
        outputs = {
          demerits = "number",
          component_breakdown = "table"
        }
      },
      {
        name = "tex.demerit.adjacent",
        version = "1.0.0",
        inputs = {
          current_fitness = "number",
          prev_fitness = "number",
          adj_demerits = "number"
        },
        outputs = {
          demerits = "number",
          is_incompatible = "boolean"
        }
      },
      {
        name = "tex.demerit.fitness",
        version = "1.0.0",
        inputs = {
          glue_ratio = "number"
        },
        outputs = {
          fitness_class = "number",
          fitness_name = "string",
          description = "string"
        }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- Fitness classification (TeX §533, §858)
--
-- TeX classifies each line into one of four fitness classes based on the
-- glue set ratio r:
--   Class 0 (tight):       r <= -0.5
--   Class 1 (decent):      -0.5 < r <= 0.5
--   Class 2 (loose):       0.5 < r <= 1.0
--   Class 3 (very_loose):   r > 1.0
--
-- Adjacent demerits are incurred when the fitness classes of consecutive
-- lines differ by more than 1. This penalises visual inconsistency.
-- ---------------------------------------------------------------------------

local FITNESS = {
  TIGHT       = 0,
  DECENT      = 1,
  LOOSE       = 2,
  VERY_LOOSE  = 3,
}

local FITNESS_NAMES = {
  [0] = "tight",
  [1] = "decent",
  [2] = "loose",
  [3] = "very_loose",
}

local function classify_fitness(glue_ratio)
  if glue_ratio <= -0.5 then
    return FITNESS.TIGHT, "tight",
      "Stretch ratio <= -0.5: line is shrinking significantly"
  elseif glue_ratio <= 0.5 then
    return FITNESS.DECENT, "decent",
      "Stretch ratio between -0.5 and 0.5: line is close to natural width"
  elseif glue_ratio <= 1.0 then
    return FITNESS.LOOSE, "loose",
      "Stretch ratio between 0.5 and 1.0: line is stretching moderately"
  else
    return FITNESS.VERY_LOOSE, "very_loose",
      "Stretch ratio > 1.0: line is stretching significantly"
  end
end

-- ---------------------------------------------------------------------------
-- Adjacent demerits (§858)
--
--   a = adj_demerits  if |f_curr - f_prev| > 1
--   a = 0             otherwise
-- ---------------------------------------------------------------------------

local function compute_adjacent_demerits(curr_fitness, prev_fitness, adj_demerits)
  if math.abs(curr_fitness - prev_fitness) > 1 then
    return adj_demerits, true
  end
  return 0, false
end

-- ---------------------------------------------------------------------------
-- Core demerit calculation (§858)
--
--   d = (l + b)^2 + p + a + h + f
--
--   l = line_penalty (default 10)
--   b = badness (0 to 10000)
--   p = break_penalty
--   a = adjacent demerits
--   h = double_hyphen_demerits (if this and previous line are hyphenated)
--   f = final_hyphen_demerits (if the penultimate line is hyphenated)
-- ---------------------------------------------------------------------------

local function compute_demerits(params)
  local badness = params.badness or 0
  local line_penalty = params.line_penalty
  if line_penalty == nil then line_penalty = 10 end
  local break_penalty = params.break_penalty or 0
  local adj_demerits = params.adj_demerits or 0
  local double_hyphen_penalty = params.double_hyphen_demerits or 0
  local final_hyphen_penalty = params.final_hyphen_demerits or 0
  local is_hyphenated = params.is_hyphenated or false
  local prev_hyphenated = params.prev_hyphenated or false
  local is_final_line = params.is_final_line or false
  local current_fitness = params.current_fitness or FITNESS.DECENT
  local prev_fitness = params.prev_fitness
  if prev_fitness == nil then prev_fitness = FITNESS.DECENT end

  local breakdown = {}

  -- Base component: (line_penalty + badness)^2
  -- TeX caps (l+b) at 10000 to avoid overflow in the squared term
  local lb = math.min(line_penalty + badness, 10000)
  local base = lb * lb
  breakdown.base = base

  -- Break penalty
  local bp = break_penalty
  breakdown.break_penalty = bp

  -- Adjacent demerits (fitness incompatibility)
  local adj, incompatible = compute_adjacent_demerits(
    current_fitness, prev_fitness, adj_demerits
  )
  breakdown.adjacent = adj
  breakdown.adjacent_incompatible = incompatible

  -- Double hyphen demerits
  local dh = 0
  if is_hyphenated and prev_hyphenated then
    dh = double_hyphen_penalty
  end
  breakdown.double_hyphen = dh

  -- Final hyphen demerits
  -- Applied when the second-to-last line is hyphenated (TeX §859)
  local fh = 0
  if is_final_line and prev_hyphenated then
    fh = final_hyphen_penalty
  end
  breakdown.final_hyphen = fh

  local total = base + bp + adj + dh + fh
  breakdown.total = total

  return total, breakdown
end

-- ---------------------------------------------------------------------------
-- tex.demerit: compute full demerit cost for a line break
-- ---------------------------------------------------------------------------

kernel["tex.demerit"] = function(inputs)
  local demerits, breakdown = compute_demerits(inputs)

  return {
    demerits = demerits,
    component_breakdown = breakdown
  }
end

-- ---------------------------------------------------------------------------
-- tex.demerit.adjacent: compute only adjacent-line demerits
-- ---------------------------------------------------------------------------

kernel["tex.demerit.adjacent"] = function(inputs)
  local current_fitness = inputs.current_fitness or FITNESS.DECENT
  local prev_fitness = inputs.prev_fitness or FITNESS.DECENT
  local adj_demerits = inputs.adj_demerits or 0

  local demerits, incompatible = compute_adjacent_demerits(
    current_fitness, prev_fitness, adj_demerits
  )

  return {
    demerits = demerits,
    is_incompatible = incompatible
  }
end

-- ---------------------------------------------------------------------------
-- tex.demerit.fitness: classify a line's fitness from its glue ratio
-- ---------------------------------------------------------------------------

kernel["tex.demerit.fitness"] = function(inputs)
  local glue_ratio = inputs.glue_ratio or 0

  local class, name, description = classify_fitness(glue_ratio)

  return {
    fitness_class = class,
    fitness_name = name,
    description = description
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
