-- kernel/tex-penalty.lua
-- Implements TeX's penalty system for line and page breaking decisions.
-- Reference: TeX: The Program, §123, §843–§846, §890–§892.
-- Reference: The TeXbook, Chapter 14 (How TeX Breaks Paragraphs into Lines),
--   Chapter 15 (How TeX Makes Pages).
--
-- TeX associates an integer penalty with each potential breakpoint:
--   penalty <= -10000  → forced break (unconditional)
--   penalty >= 10000   → forbidden break (unbreakable)
--   penalty  < 0       → good break (encouraged)
--   penalty  > 0       → bad break (discouraged)
--   penalty  = 0       → neutral
--
-- Capability: tex.penalty — compute a penalty value for a break context.
-- Capability: tex.penalty.classify — classify a penalty value by severity.
-- Capability: tex.penalty.widow_orphan — compute widow/orphan penalties.

local kernel = {}

function kernel.advertise()
  return {
    name = "tex-penalty",
    description = "Implements TeX's penalty system for line and page breaking.",
    capabilities = {
      {
        name = "tex.penalty",
        version = "1.0.0",
        inputs = {
          context = "string",
          params = "table"
        },
        outputs = {
          penalty = "number",
          classification = "string"
        }
      },
      {
        name = "tex.penalty.classify",
        version = "1.0.0",
        inputs = {
          penalty = "number"
        },
        outputs = {
          classification = "string",
          is_forced = "boolean",
          is_forbidden = "boolean",
          is_good = "boolean",
          is_bad = "boolean",
          is_neutral = "boolean",
          severity = "number"
        }
      },
      {
        name = "tex.penalty.widow_orphan",
        version = "1.0.0",
        inputs = {
          lines_before = "number",
          lines_after = "number",
          widow_penalty = "number",
          orphan_penalty = "number",
          club_penalty = "number",
          display_penalty = "number"
        },
        outputs = {
          penalties = "table",
          total_penalty = "number"
        }
      }
    }
  }
end

-- ---------------------------------------------------------------------------
-- Penalty constants (TeX §123, §843)
-- ---------------------------------------------------------------------------

local PENALTY = {
  INFINITY     = 10000,
  FORCED       = -10000,
  -- Common predefined penalties
  LINE         = 10,      -- \linepenalty: base penalty for line breaks
  HYPHEN       = 50,      -- \hyphenpenalty: penalty for hyphenated breaks
  EX_HYPHEN    = 50,      -- \exhyphenpenalty: penalty for explicit hyphen breaks
  BIN_OP       = 700,     -- \binoppenalty: penalty after binary operator
  RELATION     = 500,     -- \relpenalty: penalty after relation
  WIDOW        = 150,     -- \widowpenalty: widow line at top of page
  CLUB         = 150,     -- \clubpenalty: club line at bottom of page
  DISPLAY_WIDOW = 50,    -- \displaywidowpenalty: widow before display math
  BROKEN_PENALTY = 100,  -- \brokenpenalty: penalty after page break in paragraph
  PREDISPLAY   = 10000,  -- \predisplaypenalty: break before display math
  POSTDISPLAY  = 0,      -- \postdisplaypenalty: break after display math
  INTERLINE    = 0,      -- \interlinepenalty: break between lines of paragraph
  DOUBLE_HYPHEN = 10000, -- \doublehyphendemerits (used with demerits, not penalty)
  FINAL_HYPHEN = 5000,   -- \finalhyphendemerits (used with demerits, not penalty)
  FLOATING      = 0,     -- \floatingpenalty: penalty for float insertions
}

-- ---------------------------------------------------------------------------
-- Penalty classification
-- ---------------------------------------------------------------------------

local function classify_penalty(p)
  if p <= -10000 then
    return "forced", true, false, false, false, false, 1.0
  elseif p >= 10000 then
    return "forbidden", false, true, false, false, false, 1.0
  elseif p < 0 then
    local severity = math.abs(p) / 10000.0
    return "good", false, false, true, false, false, severity
  elseif p > 0 then
    local severity = p / 10000.0
    return "bad", false, false, false, true, false, severity
  else
    return "neutral", false, false, false, false, true, 0
  end
end

-- ---------------------------------------------------------------------------
-- Context-specific penalty computation
-- ---------------------------------------------------------------------------

local function compute_context_penalty(context, params)
  params = params or {}

  if context == "line_break" then
    -- Base line break penalty (\linepenalty)
    return params.line_penalty or PENALTY.LINE

  elseif context == "hyphen" then
    -- Penalty for a discretionary hyphen break
    return params.hyphen_penalty or PENALTY.HYPHEN

  elseif context == "explicit_hyphen" then
    -- Penalty for an explicit hyphen break (\exhyphenpenalty)
    return params.ex_hyphen_penalty or PENALTY.EX_HYPHEN

  elseif context == "after_binop" then
    -- Penalty for breaking after a binary operator
    return params.bin_op_penalty or PENALTY.BIN_OP

  elseif context == "after_relation" then
    -- Penalty for breaking after a relation
    return params.relation_penalty or PENALTY.RELATION

  elseif context == "before_display" then
    -- Penalty before display math (\predisplaypenalty)
    return params.predisplay_penalty or PENALTY.PREDISPLAY

  elseif context == "after_display" then
    -- Penalty after display math (\postdisplaypenalty)
    return params.postdisplay_penalty or PENALTY.POSTDISPLAY

  elseif context == "interline" then
    -- Penalty between lines of a paragraph (\interlinepenalty)
    return params.interline_penalty or PENALTY.INTERLINE

  elseif context == "page_break" then
    -- Base page break penalty
    return params.page_penalty or 0

  elseif context == "forced_break" then
    return PENALTY.FORCED

  elseif context == "forbidden_break" then
    return PENALTY.INFINITY

  elseif context == "float_insert" then
    return params.float_penalty or PENALTY.FLOATING

  else
    -- Unknown context: treat as neutral
    return 0
  end
end

-- ---------------------------------------------------------------------------
-- tex.penalty: compute penalty for a given break context
-- ---------------------------------------------------------------------------

kernel["tex.penalty"] = function(inputs)
  local context = inputs.context or "neutral"
  local params = inputs.params or {}

  local penalty = compute_context_penalty(context, params)
  local classification, forced, forbidden, good, bad, neutral, severity =
    classify_penalty(penalty)

  return {
    penalty = penalty,
    classification = classification
  }
end

-- ---------------------------------------------------------------------------
-- tex.penalty.classify: classify an arbitrary penalty value
-- ---------------------------------------------------------------------------

kernel["tex.penalty.classify"] = function(inputs)
  local penalty = inputs.penalty or 0

  local classification, forced, forbidden, good, bad, neutral, severity =
    classify_penalty(penalty)

  return {
    classification = classification,
    is_forced = forced,
    is_forbidden = forbidden,
    is_good = good,
    is_bad = bad,
    is_neutral = neutral,
    severity = severity
  }
end

-- ---------------------------------------------------------------------------
-- tex.penalty.widow_orphan: compute widow/orphan/club penalties
--
-- In TeX, these are penalties added at page breaks:
--   - widow: a single line of a paragraph at the top of a page
--   - orphan/club: a single line at the bottom of a page
--   - display widow: a single line before display math at the top of a page
--
-- The kernel evaluates line counts on either side of a breakpoint and
-- assigns penalties if the counts are too low.
-- ---------------------------------------------------------------------------

kernel["tex.penalty.widow_orphan"] = function(inputs)
  local lines_before = inputs.lines_before or 0
  local lines_after = inputs.lines_after or 0
  local widow_penalty = inputs.widow_penalty or PENALTY.WIDOW
  local orphan_penalty = inputs.orphan_penalty or PENALTY.CLUB
  local club_penalty = inputs.club_penalty or PENALTY.CLUB
  local display_penalty = inputs.display_penalty or PENALTY.DISPLAY_WIDOW

  local penalties = {}
  local total = 0

  -- Widow: one line after the break (line at top of next page)
  if lines_after == 1 then
    penalties[#penalties + 1] = {
      type = "widow",
      penalty = widow_penalty,
      lines = lines_after
    }
    total = total + widow_penalty
  end

  -- Orphan/club: one line before the break (line at bottom of current page)
  if lines_before == 1 then
    penalties[#penalties + 1] = {
      type = "club",
      penalty = club_penalty,
      lines = lines_before
    }
    total = total + club_penalty
  end

  -- Display widow is a special case that would need context about math displays;
  -- included as a parameter-driven check.
  if inputs.is_display_widow then
    penalties[#penalties + 1] = {
      type = "display_widow",
      penalty = display_penalty,
      lines = lines_before
    }
    total = total + display_penalty
  end

  return {
    penalties = penalties,
    total_penalty = total
  }
end

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
