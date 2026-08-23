-- kernel/glue-set.lua
-- Computes glue set ratios for TeX-style boxes (hbox, vbox).
-- Reference: TeX: The Program, §816–§820, §1243–§1250.
-- Reference: The TeXbook, Chapter 12 (Glue).
--
-- Given a list of items (boxes, glue, penalties, kerns) and a target
-- dimension, computes the glue set ratio r that TeX would apply to
-- all glue items to make the box fit the target.
--
-- Capability: tex.glue_set — compute glue set ratio for a box list.
-- Capability: tex.glue_set.distribute — distribute glue set across individual items.

local kernel = {}

function kernel.advertise()
  return {
    name = "glue-set",
    description = "Computes glue set ratios for TeX-style boxes.",
    capabilities = {
      {
        name = "tex.glue_set",
        version = "1.0.0",
        inputs = {
          items = "table",
          target = "number"
        },
        outputs = {
          ratio = "number",
          direction = "string",
          natural_sum = "number",
          total_stretch = "number",
          total_shrink = "number",
          badness = "number"
        }
      },
      {
        name = "tex.glue_set.distribute",
        version = "1.0.0",
        inputs = {
          items = "table",
          target = "number"
        },
        outputs = {
          ratio = "number",
          direction = "string",
          natural_sum = "number",
          total_stretch = "number",
          total_shrink = "number",
          badness = "number",
          items = "table"
        }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- Glue order constants (TeX §149)
-- TeX supports four orders of infinity for glue:
--   normal (0)  — finite stretch/shrink
--   fil    (1)  — infinite, lowest order
--   fill   (2)  — infinite, middle order
--   filll  (3)  — infinite, highest order
--
-- When computing glue set, only the highest order present among all glue
-- items is used; lower-order glue is treated as having zero stretch/shrink
-- for that computation.
-- ---------------------------------------------------------------------------

local GLUE_ORDER = {
  normal = 0,
  fil    = 1,
  fill   = 2,
  filll  = 3,
}

-- Item type constants
local ITEM_BOX       = "box"
local ITEM_GLUE      = "glue"
local ITEM_KERN      = "kern"
local ITEM_PENALTY   = "penalty"

-- ---------------------------------------------------------------------------
-- Compute the highest glue order present in a list of items
-- ---------------------------------------------------------------------------
local function max_order(items)
  local order = -1
  for _, item in ipairs(items) do
    if item.type == ITEM_GLUE and item.stretch_order then
      local o = GLUE_ORDER[item.stretch_order] or 0
      if o > order then order = o end
    end
    if item.type == ITEM_GLUE and item.shrink_order then
      local o = GLUE_ORDER[item.shrink_order] or 0
      if o > order then order = o end
    end
  end
  return math.max(order, 0)
end

-- ---------------------------------------------------------------------------
-- Compute glue set ratio and statistics for a box list
-- ---------------------------------------------------------------------------
local function compute_glue_set(items, target)
  local natural_sum = 0
  local total_stretch = 0
  local total_shrink = 0
  local highest_order = max_order(items)

  for _, item in ipairs(items) do
    if item.type == ITEM_BOX or item.type == ITEM_KERN then
      natural_sum = natural_sum + (item.width or 0)
    elseif item.type == ITEM_GLUE then
      natural_sum = natural_sum + (item.natural or 0)
      -- Only count stretch/shrink at the highest order
      local stretch_order = GLUE_ORDER[item.stretch_order] or 0
      local shrink_order = GLUE_ORDER[item.shrink_order] or 0
      if stretch_order == highest_order then
        total_stretch = total_stretch + (item.stretch or 0)
      end
      if shrink_order == highest_order then
        total_shrink = total_shrink + (item.shrink or 0)
      end
    elseif item.type == ITEM_PENALTY then
      natural_sum = natural_sum + (item.width or 0)
    end
  end

  local diff = target - natural_sum

  if diff == 0 then
    return 0, "exact", natural_sum, total_stretch, total_shrink, 0
  end

  if diff > 0 then
    -- Need to stretch
    if total_stretch <= 0 then
      -- No stretch available; check if we have infinite glue
      -- If highest_order > 0, any positive ratio works (infinite stretch)
      if highest_order > 0 then
        return 0, "stretch", natural_sum, total_stretch, total_shrink, 0
      end
      -- Underfull box: ratio is undefined, badness is infinite
      return 0, "underfull", natural_sum, total_stretch, total_shrink, 10000
    end
    local ratio = diff / total_stretch
    local b = math.floor(100.0 * (ratio ^ 3) + 0.5)
    if b > 10000 then b = 10000 end
    return ratio, "stretch", natural_sum, total_stretch, total_shrink, b
  else
    -- Need to shrink
    local excess = -diff
    if total_shrink <= 0 then
      if highest_order > 0 then
        return 0, "shrink", natural_sum, total_stretch, total_shrink, 0
      end
      -- Overfull box
      return 0, "overfull", natural_sum, total_stretch, total_shrink, 10000
    end
    local ratio = excess / total_shrink
    local b = math.floor(100.0 * (ratio ^ 3) + 0.5)
    if b > 10000 then b = 10000 end
    return ratio, "shrink", natural_sum, total_stretch, total_shrink, b
  end
end

-- ---------------------------------------------------------------------------
-- tex.glue_set: compute glue set ratio for a box list
-- ---------------------------------------------------------------------------

kernel["tex.glue_set"] = function(inputs)
  local items = inputs.items or {}
  local target = inputs.target or 0

  local ratio, direction, natural_sum, total_stretch, total_shrink, badness =
    compute_glue_set(items, target)

  return {
    ratio = ratio,
    direction = direction,
    natural_sum = natural_sum,
    total_stretch = total_stretch,
    total_shrink = total_shrink,
    badness = badness
  }
end

-- ---------------------------------------------------------------------------
-- tex.glue_set.distribute: compute glue set and distribute across items
--
-- Returns the same aggregate information as tex.glue_set, plus the items
-- list with each glue item annotated with its adjusted width after applying
-- the glue set ratio.
-- ---------------------------------------------------------------------------

kernel["tex.glue_set.distribute"] = function(inputs)
  local items = inputs.items or {}
  local target = inputs.target or 0

  local ratio, direction, natural_sum, total_stretch, total_shrink, badness =
    compute_glue_set(items, target)

  local highest_order = max_order(items)

  local distributed = {}
  for _, item in ipairs(items) do
    local adjusted = {
      type = item.type,
      width = item.width or item.natural or 0,
      label = item.label
    }

    if item.type == ITEM_GLUE then
      adjusted.natural = item.natural or 0
      adjusted.stretch = item.stretch or 0
      adjusted.shrink = item.shrink or 0
      adjusted.stretch_order = item.stretch_order or "normal"
      adjusted.shrink_order = item.shrink_order or "normal"

      local stretch_order = GLUE_ORDER[item.stretch_order] or 0
      local shrink_order = GLUE_ORDER[item.shrink_order] or 0

      if direction == "stretch" and stretch_order == highest_order then
        adjusted.width = adjusted.natural + ratio * adjusted.stretch
      elseif direction == "shrink" and shrink_order == highest_order then
        adjusted.width = adjusted.natural - ratio * adjusted.shrink
      else
        adjusted.width = adjusted.natural
      end
    end

    distributed[#distributed + 1] = adjusted
  end

  return {
    ratio = ratio,
    direction = direction,
    natural_sum = natural_sum,
    total_stretch = total_stretch,
    total_shrink = total_shrink,
    badness = badness,
    items = distributed
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
