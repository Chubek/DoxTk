-- kernel/badness.lua
-- Implements Knuth's badness algorithm for TeX-quality line breaking.
-- Reference: TeX: The Program, §108, §816–§818 (badness function).
-- Reference: The TeXbook, Chapter 14 (How TeX Breaks Paragraphs into Lines).
--
-- badness(t, s) rates the aesthetic cost of stretching or shrinking a box
-- from its natural size to a desired size, on a scale of 0 (perfect) to
-- 10000 (awful or impossible).
--
-- Capability: tex.badness — compute badness for a single box/glue item.
-- Capability: tex.badness.batch — compute badness for a batch of items.

local kernel = {}

function kernel.advertise()
  return {
    name = "badness",
    description = "Implements Knuth's badness algorithm for TeX-quality line breaking.",
    capabilities = {
      {
        name = "tex.badness",
        version = "1.0.0",
        inputs = {
          natural = "number",
          desired = "number",
          stretch = "number",
          shrink = "number"
        },
        outputs = {
          badness = "number",
          glue_ratio = "number",
          direction = "string"
        }
      },
      {
        name = "tex.badness.batch",
        version = "1.0.0",
        inputs = {
          items = "table"
        },
        outputs = {
          badness = "number",
          glue_ratio = "number",
          direction = "string",
          per_item = "table"
        }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- Knuth's badness function (§108, §816–§818 of TeX: The Program)
--
--   badness(t, s) =
--     if t == 0              → 0        (perfect fit)
--     else if s <= 0         → 10000    (no stretch/shrink available → awful)
--     else                  → min(10000, round(100 * (t/s)^3))
--
--   t = absolute excess (|desired - natural|)
--   s = available stretch (if desired > natural) or shrink (if desired < natural)
--
-- The cubic scaling means that stretching to 2× the available stretchability
-- gives badness 800, while 3× gives 2700 and 4× gives 6400.
-- ---------------------------------------------------------------------------

local INFINITELY_BAD = 10000
local function round(x)
  return math.floor(x + 0.5)
end

local function compute_badness(natural, desired, stretch, shrink)
  local diff = desired - natural

  if diff == 0 then
    return 0, 0, "exact"
  end

  if diff > 0 then
    -- We need to stretch
    if not stretch or stretch <= 0 then
      return INFINITELY_BAD, diff, "stretch"
    end
    local ratio = diff / stretch
    local b = round(100.0 * (ratio ^ 3))
    if b > INFINITELY_BAD then
      b = INFINITELY_BAD
    end
    return b, ratio, "stretch"
  else
    -- We need to shrink
    local excess = -diff -- positive value
    if not shrink or shrink <= 0 then
      return INFINITELY_BAD, excess, "shrink"
    end
    local ratio = excess / shrink
    local b = round(100.0 * (ratio ^ 3))
    if b > INFINITELY_BAD then
      b = INFINITELY_BAD
    end
    return b, ratio, "shrink"
  end
end

-- ---------------------------------------------------------------------------
-- tex.badness: single-item badness
-- ---------------------------------------------------------------------------

kernel["tex.badness"] = function(inputs)
  local natural = inputs.natural or 0
  local desired = inputs.desired or 0
  local stretch = inputs.stretch or 0
  local shrink = inputs.shrink or 0

  local badness, ratio, direction = compute_badness(natural, desired, stretch, shrink)

  return {
    badness = badness,
    glue_ratio = ratio,
    direction = direction
  }
end

-- ---------------------------------------------------------------------------
-- tex.badness.batch: batch badness computation
--
-- Each item in inputs.items is a table:
--   { natural = N, desired = D, stretch = St, shrink = Sh, label = "..." }
-- The aggregate natural, stretch, and shrink are summed; desired is summed.
-- The per-item field returns individual badness values computed against the
-- single aggregate ratio (consistent with how TeX sets glue in a box).
-- ---------------------------------------------------------------------------

kernel["tex.badness.batch"] = function(inputs)
  local items = inputs.items or {}

  if #items == 0 then
    return {
      badness = 0,
      glue_ratio = 0,
      direction = "exact",
      per_item = {}
    }
  end

  local total_natural = 0
  local total_desired = 0
  local total_stretch = 0
  local total_shrink = 0

  for _, item in ipairs(items) do
    total_natural = total_natural + (item.natural or 0)
    total_desired = total_desired + (item.desired or 0)
    total_stretch = total_stretch + (item.stretch or 0)
    total_shrink = total_shrink + (item.shrink or 0)
  end

  local badness, ratio, direction = compute_badness(
    total_natural, total_desired, total_stretch, total_shrink
  )

  -- Compute per-item badness using the aggregate ratio
  local per_item = {}
  for _, item in ipairs(items) do
    local nat = item.natural or 0
    local str = item.stretch or 0
    local shr = item.shrink or 0

    local item_badness
    local item_direction
    if ratio == 0 then
      item_badness = 0
      item_direction = "exact"
    elseif direction == "stretch" then
      local item_diff = ratio * str
      item_badness, _, item_direction = compute_badness(nat, nat + item_diff, str, shr)
    else
      local item_diff = ratio * shr
      item_badness, _, item_direction = compute_badness(nat, nat - item_diff, str, shr)
    end

    per_item[#per_item + 1] = {
      label = item.label,
      badness = item_badness,
      direction = item_direction
    }
  end

  return {
    badness = badness,
    glue_ratio = ratio,
    direction = direction,
    per_item = per_item
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
