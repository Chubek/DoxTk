-- kernel/math-symbol.lua
-- Comprehensive math symbol registry with Unicode mapping, TeX-style
-- atom classification, and inter-atom spacing rules.  Companion to
-- math-layout.lua, providing the symbol database that layout and
-- frontend kernels consume through the Sched layer.

local kernel = {}

function kernel.advertise()
  return {
    name = "math-symbol",
    description = "Math symbol registry: resolve names to Unicode codepoints, classify atoms, and provide spacing rules.",
    capabilities = {
      {
        name = "math.symbol.resolve",
        version = "1.0.0",
        inputs = {
          name = "string",
          fallback = "string"
        },
        outputs = {
          codepoint = "string",
          char = "string",
          classification = "string",
          spacing = "table",
          description = "string"
        }
      },
      {
        name = "math.symbol.classify",
        version = "1.0.0",
        inputs = {
          char = "string"
        },
        outputs = {
          classification = "string",
          spacing = "table"
        }
      },
      {
        name = "math.symbol.list",
        version = "1.0.0",
        inputs = {
          category = "string"
        },
        outputs = {
          symbols = "table"
        }
      }
    }
  }
end

-- =========================================================================
-- Atom classifications
-- =========================================================================

local CLASS = {
  ORD   = "Ord",
  OP    = "Op",
  BIN   = "Bin",
  REL   = "Rel",
  OPEN  = "Open",
  CLOSE = "Close",
  PUNCT = "Punct",
  INNER = "Inner",
}

-- =========================================================================
-- Inter-atom spacing table (TeXbook Appendix G, p. 170)
-- Values in em units.  nil = 0 em.
-- =========================================================================

local SPACING = {
  Ord = {
    Ord   = { 0, 0 },
    Op    = { 0, 0 },
    Bin   = { 0.222, 0 },
    Rel   = { 0.278, 0 },
    Open  = { 0, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0.111, 0 },
  },
  Op = {
    Ord   = { 0.111, 0 },
    Op    = { 0.111, 0 },
    Bin   = { 0, 0 },
    Rel   = { 0.278, 0 },
    Open  = { 0, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0.111, 0 },
  },
  Bin = {
    Ord   = { 0.222, 0 },
    Op    = { 0.222, 0 },
    Bin   = { 0, 0 },
    Rel   = { 0, 0 },
    Open  = { 0.222, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0.222, 0 },
  },
  Rel = {
    Ord   = { 0.278, 0 },
    Op    = { 0.278, 0 },
    Bin   = { 0, 0 },
    Rel   = { 0, 0 },
    Open  = { 0.278, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0.278, 0 },
  },
  Open = {
    Ord   = { 0, 0 },
    Op    = { 0, 0 },
    Bin   = { 0, 0 },
    Rel   = { 0, 0 },
    Open  = { 0, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0, 0 },
  },
  Close = {
    Ord   = { 0, 0 },
    Op    = { 0, 0 },
    Bin   = { 0.222, 0 },
    Rel   = { 0.278, 0 },
    Open  = { 0, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0, 0 },
  },
  Punct = {
    Ord   = { 0, 0.111 },
    Op    = { 0, 0.111 },
    Bin   = { 0, 0 },
    Rel   = { 0, 0.278 },
    Open  = { 0, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0.111 },
    Inner = { 0, 0.111 },
  },
  Inner = {
    Ord   = { 0.111, 0 },
    Op    = { 0.111, 0 },
    Bin   = { 0.222, 0 },
    Rel   = { 0.278, 0 },
    Open  = { 0.111, 0 },
    Close = { 0, 0 },
    Punct = { 0, 0 },
    Inner = { 0.111, 0 },
  },
}

-- =========================================================================
-- Symbol database
-- Each entry: { utf8, class, desc, aliases }
-- =========================================================================

local SYMBOLS = {
  -- Greek lowercase
  { utf8 = "α", class = CLASS.ORD, desc = "alpha",       aliases = {} },
  { utf8 = "β", class = CLASS.ORD, desc = "beta",        aliases = {} },
  { utf8 = "γ", class = CLASS.ORD, desc = "gamma",       aliases = {} },
  { utf8 = "δ", class = CLASS.ORD, desc = "delta",       aliases = {} },
  { utf8 = "ε", class = CLASS.ORD, desc = "epsilon",     aliases = {} },
  { utf8 = "ζ", class = CLASS.ORD, desc = "zeta",        aliases = {} },
  { utf8 = "η", class = CLASS.ORD, desc = "eta",         aliases = {} },
  { utf8 = "θ", class = CLASS.ORD, desc = "theta",       aliases = {} },
  { utf8 = "ι", class = CLASS.ORD, desc = "iota",        aliases = {} },
  { utf8 = "κ", class = CLASS.ORD, desc = "kappa",       aliases = {} },
  { utf8 = "λ", class = CLASS.ORD, desc = "lambda",      aliases = {} },
  { utf8 = "μ", class = CLASS.ORD, desc = "mu",          aliases = {} },
  { utf8 = "ν", class = CLASS.ORD, desc = "nu",          aliases = {} },
  { utf8 = "ξ", class = CLASS.ORD, desc = "xi",          aliases = {} },
  { utf8 = "π", class = CLASS.ORD, desc = "pi",          aliases = {} },
  { utf8 = "ρ", class = CLASS.ORD, desc = "rho",         aliases = {} },
  { utf8 = "σ", class = CLASS.ORD, desc = "sigma",       aliases = {} },
  { utf8 = "τ", class = CLASS.ORD, desc = "tau",         aliases = {} },
  { utf8 = "υ", class = CLASS.ORD, desc = "upsilon",     aliases = {} },
  { utf8 = "φ", class = CLASS.ORD, desc = "phi",         aliases = {} },
  { utf8 = "χ", class = CLASS.ORD, desc = "chi",         aliases = {} },
  { utf8 = "ψ", class = CLASS.ORD, desc = "psi",         aliases = {} },
  { utf8 = "ω", class = CLASS.ORD, desc = "omega",       aliases = {} },

  -- Greek uppercase
  { utf8 = "Γ", class = CLASS.ORD, desc = "Gamma",       aliases = {} },
  { utf8 = "Δ", class = CLASS.ORD, desc = "Delta",       aliases = {} },
  { utf8 = "Θ", class = CLASS.ORD, desc = "Theta",       aliases = {} },
  { utf8 = "Λ", class = CLASS.ORD, desc = "Lambda",      aliases = {} },
  { utf8 = "Ξ", class = CLASS.ORD, desc = "Xi",          aliases = {} },
  { utf8 = "Π", class = CLASS.ORD, desc = "Pi",          aliases = {} },
  { utf8 = "Σ", class = CLASS.ORD, desc = "Sigma",       aliases = {} },
  { utf8 = "Φ", class = CLASS.ORD, desc = "Phi",         aliases = {} },
  { utf8 = "Ψ", class = CLASS.ORD, desc = "Psi",         aliases = {} },
  { utf8 = "Ω", class = CLASS.ORD, desc = "Omega",       aliases = {} },

  -- Greek variants
  { utf8 = "ϑ", class = CLASS.ORD, desc = "vartheta",    aliases = {} },
  { utf8 = "ϖ", class = CLASS.ORD, desc = "varpi",       aliases = {} },
  { utf8 = "ϱ", class = CLASS.ORD, desc = "varrho",      aliases = {} },
  { utf8 = "ς", class = CLASS.ORD, desc = "varsigma",    aliases = {} },
  { utf8 = "φ", class = CLASS.ORD, desc = "varphi",      aliases = {} },
  { utf8 = "ϵ", class = CLASS.ORD, desc = "straightepsilon", aliases = {"varepsilon"} },
  { utf8 = "϶", class = CLASS.ORD, desc = "backepsilon", aliases = {} },

  -- Binary operators
  { utf8 = "±", class = CLASS.BIN, desc = "pm",          aliases = {"plusminus"} },
  { utf8 = "∓", class = CLASS.BIN, desc = "mp",          aliases = {"minusplus"} },
  { utf8 = "×", class = CLASS.BIN, desc = "times",       aliases = {} },
  { utf8 = "·", class = CLASS.BIN, desc = "cdot",        aliases = {} },
  { utf8 = "÷", class = CLASS.BIN, desc = "div",         aliases = {"divide"} },
  { utf8 = "∖", class = CLASS.BIN, desc = "setminus",    aliases = {} },
  { utf8 = "∗", class = CLASS.BIN, desc = "ast",         aliases = {} },
  { utf8 = "∘", class = CLASS.BIN, desc = "circ",        aliases = {} },
  { utf8 = "•", class = CLASS.BIN, desc = "bullet",      aliases = {} },
  { utf8 = "∧", class = CLASS.BIN, desc = "wedge",       aliases = {"land"} },
  { utf8 = "∨", class = CLASS.BIN, desc = "vee",         aliases = {"lor"} },
  { utf8 = "∩", class = CLASS.BIN, desc = "cap",         aliases = {} },
  { utf8 = "∪", class = CLASS.BIN, desc = "cup",         aliases = {} },
  { utf8 = "⊓", class = CLASS.BIN, desc = "sqcap",       aliases = {} },
  { utf8 = "⊔", class = CLASS.BIN, desc = "sqcup",       aliases = {} },
  { utf8 = "⊎", class = CLASS.BIN, desc = "uplus",       aliases = {} },
  { utf8 = "∐", class = CLASS.BIN, desc = "amalg",       aliases = {} },
  { utf8 = "⋄", class = CLASS.BIN, desc = "diamond",     aliases = {} },
  { utf8 = "⊲", class = CLASS.BIN, desc = "lhd",         aliases = {} },
  { utf8 = "⊳", class = CLASS.BIN, desc = "rhd",         aliases = {} },
  { utf8 = "⊴", class = CLASS.BIN, desc = "unlhd",       aliases = {} },
  { utf8 = "⊵", class = CLASS.BIN, desc = "unrhd",       aliases = {} },
  { utf8 = "◃", class = CLASS.BIN, desc = "triangleleft",  aliases = {} },
  { utf8 = "▹", class = CLASS.BIN, desc = "triangleright", aliases = {} },
  { utf8 = "△", class = CLASS.BIN, desc = "bigtriangleup", aliases = {} },
  { utf8 = "▽", class = CLASS.BIN, desc = "bigtriangledown", aliases = {} },
  { utf8 = "⊖", class = CLASS.BIN, desc = "ominus",      aliases = {} },
  { utf8 = "⊘", class = CLASS.BIN, desc = "oslash",      aliases = {} },
  { utf8 = "⊙", class = CLASS.BIN, desc = "odot",        aliases = {} },
  { utf8 = "⊕", class = CLASS.BIN, desc = "oplus",       aliases = {} },
  { utf8 = "⊗", class = CLASS.BIN, desc = "otimes",      aliases = {} },
  { utf8 = "≀", class = CLASS.BIN, desc = "wr",          aliases = {} },
  { utf8 = "⋆", class = CLASS.BIN, desc = "star",        aliases = {} },
  { utf8 = "★", class = CLASS.BIN, desc = "bigstar",     aliases = {} },
  { utf8 = "†", class = CLASS.BIN, desc = "dagger",      aliases = {"dag"} },
  { utf8 = "‡", class = CLASS.BIN, desc = "ddagger",     aliases = {"ddag"} },
  { utf8 = "⊞", class = CLASS.BIN, desc = "boxplus",     aliases = {} },
  { utf8 = "⊟", class = CLASS.BIN, desc = "boxminus",    aliases = {} },
  { utf8 = "⊠", class = CLASS.BIN, desc = "boxtimes",    aliases = {} },
  { utf8 = "⊡", class = CLASS.BIN, desc = "boxdot",      aliases = {} },

  -- Relations
  { utf8 = "≤", class = CLASS.REL, desc = "leq",         aliases = {"le"} },
  { utf8 = "≥", class = CLASS.REL, desc = "geq",         aliases = {"ge"} },
  { utf8 = "≠", class = CLASS.REL, desc = "neq",         aliases = {"ne"} },
  { utf8 = "≡", class = CLASS.REL, desc = "equiv",       aliases = {} },
  { utf8 = "≈", class = CLASS.REL, desc = "approx",      aliases = {} },
  { utf8 = "∼", class = CLASS.REL, desc = "sim",         aliases = {} },
  { utf8 = "≃", class = CLASS.REL, desc = "simeq",       aliases = {} },
  { utf8 = "≅", class = CLASS.REL, desc = "cong",        aliases = {} },
  { utf8 = "∝", class = CLASS.REL, desc = "propto",      aliases = {} },
  { utf8 = "⊑", class = CLASS.REL, desc = "sqsubseteq",  aliases = {} },
  { utf8 = "⊒", class = CLASS.REL, desc = "sqsupseteq",  aliases = {} },
  { utf8 = "⊆", class = CLASS.REL, desc = "subseteq",    aliases = {} },
  { utf8 = "⊇", class = CLASS.REL, desc = "supseteq",    aliases = {} },
  { utf8 = "⊂", class = CLASS.REL, desc = "subset",      aliases = {} },
  { utf8 = "⊃", class = CLASS.REL, desc = "supset",      aliases = {} },
  { utf8 = "⊊", class = CLASS.REL, desc = "subsetneq",   aliases = {} },
  { utf8 = "⊋", class = CLASS.REL, desc = "supsetneq",   aliases = {} },
  { utf8 = "∈", class = CLASS.REL, desc = "in",          aliases = {} },
  { utf8 = "∋", class = CLASS.REL, desc = "ni",          aliases = {"owns"} },
  { utf8 = "∉", class = CLASS.REL, desc = "notin",       aliases = {} },
  { utf8 = "⊢", class = CLASS.REL, desc = "vdash",       aliases = {} },
  { utf8 = "⊣", class = CLASS.REL, desc = "dashv",       aliases = {} },
  { utf8 = "⊨", class = CLASS.REL, desc = "models",      aliases = {} },
  { utf8 = "⊫", class = CLASS.REL, desc = "Vdash",       aliases = {} },
  { utf8 = "⊬", class = CLASS.REL, desc = "nvdash",      aliases = {} },
  { utf8 = "⊭", class = CLASS.REL, desc = "nvDash",      aliases = {} },
  { utf8 = "≺", class = CLASS.REL, desc = "prec",        aliases = {} },
  { utf8 = "≻", class = CLASS.REL, desc = "succ",        aliases = {} },
  { utf8 = "≼", class = CLASS.REL, desc = "preceq",      aliases = {} },
  { utf8 = "≽", class = CLASS.REL, desc = "succeq",      aliases = {} },
  { utf8 = "≪", class = CLASS.REL, desc = "ll",          aliases = {} },
  { utf8 = "≫", class = CLASS.REL, desc = "gg",          aliases = {} },
  { utf8 = "≍", class = CLASS.REL, desc = "asymp",       aliases = {} },
  { utf8 = "⋈", class = CLASS.REL, desc = "bowtie",      aliases = {} },
  { utf8 = "⊏", class = CLASS.REL, desc = "sqsubset",    aliases = {} },
  { utf8 = "⊐", class = CLASS.REL, desc = "sqsupset",    aliases = {} },
  { utf8 = "⊥", class = CLASS.REL, desc = "perp",        aliases = {"bot"} },
  { utf8 = "⌣", class = CLASS.REL, desc = "smile",       aliases = {} },
  { utf8 = "⌢", class = CLASS.REL, desc = "frown",       aliases = {} },
  { utf8 = "∥", class = CLASS.REL, desc = "parallel",    aliases = {} },
  { utf8 = "∦", class = CLASS.REL, desc = "nparallel",   aliases = {} },
  { utf8 = "∣", class = CLASS.REL, desc = "mid",         aliases = {} },
  { utf8 = "∤", class = CLASS.REL, desc = "nmid",        aliases = {} },
  { utf8 = "≐", class = CLASS.REL, desc = "doteq",       aliases = {} },
  { utf8 = "≗", class = CLASS.REL, desc = "circeq",      aliases = {} },
  { utf8 = "≜", class = CLASS.REL, desc = "triangleq",   aliases = {} },
  { utf8 = "≟", class = CLASS.REL, desc = "questeq",     aliases = {} },
  { utf8 = "≙", class = CLASS.REL, desc = "wedgeq",      aliases = {} },
  { utf8 = "≚", class = CLASS.REL, desc = "veeeq",       aliases = {} },
  { utf8 = "≛", class = CLASS.REL, desc = "stareq",      aliases = {} },

  -- Arrows
  { utf8 = "→", class = CLASS.REL, desc = "rightarrow",      aliases = {"to"} },
  { utf8 = "←", class = CLASS.REL, desc = "leftarrow",       aliases = {"gets"} },
  { utf8 = "↔", class = CLASS.REL, desc = "leftrightarrow",  aliases = {} },
  { utf8 = "⇒", class = CLASS.REL, desc = "Rightarrow",      aliases = {} },
  { utf8 = "⇐", class = CLASS.REL, desc = "Leftarrow",       aliases = {} },
  { utf8 = "⇔", class = CLASS.REL, desc = "Leftrightarrow",  aliases = {} },
  { utf8 = "↦", class = CLASS.REL, desc = "mapsto",          aliases = {} },
  { utf8 = "↪", class = CLASS.REL, desc = "hookrightarrow",  aliases = {} },
  { utf8 = "↩", class = CLASS.REL, desc = "hookleftarrow",   aliases = {} },
  { utf8 = "⇀", class = CLASS.REL, desc = "rightharpoonup",    aliases = {} },
  { utf8 = "⇁", class = CLASS.REL, desc = "rightharpoondown",  aliases = {} },
  { utf8 = "↼", class = CLASS.REL, desc = "leftharpoonup",     aliases = {} },
  { utf8 = "↽", class = CLASS.REL, desc = "leftharpoondown",   aliases = {} },
  { utf8 = "⇌", class = CLASS.REL, desc = "rightleftharpoons", aliases = {} },
  { utf8 = "↑", class = CLASS.REL, desc = "uparrow",         aliases = {} },
  { utf8 = "↓", class = CLASS.REL, desc = "downarrow",       aliases = {} },
  { utf8 = "↕", class = CLASS.REL, desc = "updownarrow",     aliases = {} },
  { utf8 = "⇑", class = CLASS.REL, desc = "Uparrow",         aliases = {} },
  { utf8 = "⇓", class = CLASS.REL, desc = "Downarrow",       aliases = {} },
  { utf8 = "⇕", class = CLASS.REL, desc = "Updownarrow",     aliases = {} },
  { utf8 = "↗", class = CLASS.REL, desc = "nearrow",         aliases = {} },
  { utf8 = "↘", class = CLASS.REL, desc = "searrow",         aliases = {} },
  { utf8 = "↙", class = CLASS.REL, desc = "swarrow",         aliases = {} },
  { utf8 = "↖", class = CLASS.REL, desc = "nwarrow",         aliases = {} },
  { utf8 = "⇝", class = CLASS.REL, desc = "rightsquigarrow", aliases = {} },
  { utf8 = "↭", class = CLASS.REL, desc = "leftrightsquigarrow", aliases = {} },
  { utf8 = "↺", class = CLASS.REL, desc = "circlearrowleft",  aliases = {} },
  { utf8 = "↻", class = CLASS.REL, desc = "circlearrowright", aliases = {} },
  { utf8 = "⟶", class = CLASS.REL, desc = "longrightarrow",     aliases = {} },
  { utf8 = "⟵", class = CLASS.REL, desc = "longleftarrow",      aliases = {} },
  { utf8 = "⟷", class = CLASS.REL, desc = "longleftrightarrow", aliases = {} },
  { utf8 = "⟼", class = CLASS.REL, desc = "longmapsto",         aliases = {} },
  { utf8 = "⇉", class = CLASS.REL, desc = "rightrightarrows", aliases = {} },
  { utf8 = "⇇", class = CLASS.REL, desc = "leftleftarrows",   aliases = {} },
  { utf8 = "⇄", class = CLASS.REL, desc = "rightleftarrows",  aliases = {} },
  { utf8 = "⇆", class = CLASS.REL, desc = "leftrightarrows",  aliases = {} },

  -- Big operators
  { utf8 = "∑", class = CLASS.OP, desc = "sum",          aliases = {} },
  { utf8 = "∏", class = CLASS.OP, desc = "prod",         aliases = {} },
  { utf8 = "∐", class = CLASS.OP, desc = "coprod",       aliases = {} },
  { utf8 = "∫", class = CLASS.OP, desc = "int",          aliases = {} },
  { utf8 = "∬", class = CLASS.OP, desc = "iint",         aliases = {} },
  { utf8 = "∭", class = CLASS.OP, desc = "iiint",        aliases = {} },
  { utf8 = "∮", class = CLASS.OP, desc = "oint",         aliases = {} },
  { utf8 = "∯", class = CLASS.OP, desc = "oiint",        aliases = {} },
  { utf8 = "∰", class = CLASS.OP, desc = "oiiint",       aliases = {} },
  { utf8 = "⋀", class = CLASS.OP, desc = "bigwedge",     aliases = {} },
  { utf8 = "⋁", class = CLASS.OP, desc = "bigvee",       aliases = {} },
  { utf8 = "⋂", class = CLASS.OP, desc = "bigcap",       aliases = {} },
  { utf8 = "⋃", class = CLASS.OP, desc = "bigcup",       aliases = {} },
  { utf8 = "⨆", class = CLASS.OP, desc = "bigsqcup",     aliases = {} },
  { utf8 = "⨁", class = CLASS.OP, desc = "bigoplus",     aliases = {} },
  { utf8 = "⨂", class = CLASS.OP, desc = "bigotimes",    aliases = {} },
  { utf8 = "⨄", class = CLASS.OP, desc = "biguplus",     aliases = {} },
  { utf8 = "⨀", class = CLASS.OP, desc = "bigodot",      aliases = {} },

  -- Delimiters
  { utf8 = "(", class = CLASS.OPEN,  desc = "lparen",    aliases = {"("} },
  { utf8 = ")", class = CLASS.CLOSE, desc = "rparen",    aliases = {")"} },
  { utf8 = "[", class = CLASS.OPEN,  desc = "lbracket",  aliases = {"["} },
  { utf8 = "]", class = CLASS.CLOSE, desc = "rbracket",  aliases = {"]"} },
  { utf8 = "{", class = CLASS.OPEN,  desc = "lbrace",    aliases = {"\\{"} },
  { utf8 = "}", class = CLASS.CLOSE, desc = "rbrace",    aliases = {"\\}"} },
  { utf8 = "⌈", class = CLASS.OPEN,  desc = "lceil",     aliases = {} },
  { utf8 = "⌉", class = CLASS.CLOSE, desc = "rceil",     aliases = {} },
  { utf8 = "⌊", class = CLASS.OPEN,  desc = "lfloor",    aliases = {} },
  { utf8 = "⌋", class = CLASS.CLOSE, desc = "rfloor",    aliases = {} },
  { utf8 = "⟨", class = CLASS.OPEN,  desc = "langle",    aliases = {} },
  { utf8 = "⟩", class = CLASS.CLOSE, desc = "rangle",    aliases = {} },
  { utf8 = "|", class = CLASS.ORD,   desc = "vert",      aliases = {"|"} },
  { utf8 = "‖", class = CLASS.ORD,   desc = "Vert",      aliases = {"\\|"} },
  { utf8 = "⌜", class = CLASS.OPEN,  desc = "ulcorner",  aliases = {} },
  { utf8 = "⌝", class = CLASS.CLOSE, desc = "urcorner",  aliases = {} },
  { utf8 = "⌞", class = CLASS.OPEN,  desc = "llcorner",  aliases = {} },
  { utf8 = "⌟", class = CLASS.CLOSE, desc = "lrcorner",  aliases = {} },
  { utf8 = "⎧", class = CLASS.OPEN,  desc = "lBrace",    aliases = {} },
  { utf8 = "⎫", class = CLASS.CLOSE, desc = "rBrace",    aliases = {} },
  { utf8 = "⟦", class = CLASS.OPEN,  desc = "llbracket", aliases = {} },
  { utf8 = "⟧", class = CLASS.CLOSE, desc = "rrbracket", aliases = {} },

  -- Punctuation / ellipsis
  { utf8 = "…", class = CLASS.PUNCT, desc = "ldots",     aliases = {"dots"} },
  { utf8 = "⋯", class = CLASS.PUNCT, desc = "cdots",     aliases = {} },
  { utf8 = "⋮", class = CLASS.PUNCT, desc = "vdots",     aliases = {} },
  { utf8 = "⋱", class = CLASS.PUNCT, desc = "ddots",     aliases = {} },
  { utf8 = "⋰", class = CLASS.PUNCT, desc = "udots",     aliases = {} },
  { utf8 = ",", class = CLASS.PUNCT, desc = "comma",     aliases = {","} },
  { utf8 = ";", class = CLASS.PUNCT, desc = "semicolon", aliases = {";"} },
  { utf8 = ":", class = CLASS.PUNCT, desc = "colon",     aliases = {":"} },

  -- Misc symbols
  { utf8 = "∞", class = CLASS.ORD, desc = "infty",       aliases = {} },
  { utf8 = "∂", class = CLASS.ORD, desc = "partial",     aliases = {} },
  { utf8 = "∇", class = CLASS.ORD, desc = "nabla",       aliases = {} },
  { utf8 = "∀", class = CLASS.ORD, desc = "forall",      aliases = {} },
  { utf8 = "∃", class = CLASS.ORD, desc = "exists",      aliases = {} },
  { utf8 = "∄", class = CLASS.ORD, desc = "nexists",     aliases = {} },
  { utf8 = "∅", class = CLASS.ORD, desc = "emptyset",    aliases = {"varnothing"} },
  { utf8 = "△", class = CLASS.ORD, desc = "triangle",    aliases = {} },
  { utf8 = "√", class = CLASS.ORD, desc = "surd",        aliases = {"sqrt"} },
  { utf8 = "⊤", class = CLASS.ORD, desc = "top",         aliases = {} },
  { utf8 = "∠", class = CLASS.ORD, desc = "angle",       aliases = {} },
  { utf8 = "∡", class = CLASS.ORD, desc = "measuredangle", aliases = {} },
  { utf8 = "∢", class = CLASS.ORD, desc = "sphericalangle", aliases = {} },
  { utf8 = "ℵ", class = CLASS.ORD, desc = "aleph",       aliases = {} },
  { utf8 = "ℶ", class = CLASS.ORD, desc = "beth",        aliases = {} },
  { utf8 = "ℷ", class = CLASS.ORD, desc = "gimel",       aliases = {} },
  { utf8 = "ℸ", class = CLASS.ORD, desc = "daleth",      aliases = {} },
  { utf8 = "′", class = CLASS.ORD, desc = "prime",       aliases = {"'"} },
  { utf8 = "″", class = CLASS.ORD, desc = "dprime",      aliases = {} },
  { utf8 = "‴", class = CLASS.ORD, desc = "trprime",     aliases = {} },
  { utf8 = "‵", class = CLASS.ORD, desc = "backprime",   aliases = {} },
  { utf8 = "ℏ", class = CLASS.ORD, desc = "hbar",        aliases = {} },
  { utf8 = "ℜ", class = CLASS.ORD, desc = "Re",          aliases = {} },
  { utf8 = "ℑ", class = CLASS.ORD, desc = "Im",          aliases = {} },
  { utf8 = "℘", class = CLASS.ORD, desc = "wp",          aliases = {} },
  { utf8 = "ℓ", class = CLASS.ORD, desc = "ell",         aliases = {} },
  { utf8 = "℧", class = CLASS.ORD, desc = "mho",         aliases = {} },
  { utf8 = "Ⅎ", class = CLASS.ORD, desc = "Finv",        aliases = {} },
  { utf8 = "⅁", class = CLASS.ORD, desc = "Game",        aliases = {} },
  { utf8 = "¬", class = CLASS.ORD, desc = "neg",         aliases = {"lnot"} },
  { utf8 = "□", class = CLASS.ORD, desc = "square",      aliases = {"Box"} },
  { utf8 = "■", class = CLASS.ORD, desc = "blacksquare", aliases = {} },
  { utf8 = "◆", class = CLASS.ORD, desc = "lozenge",     aliases = {"Diamond"} },
  { utf8 = "⧫", class = CLASS.ORD, desc = "blacklozenge", aliases = {} },
  { utf8 = "∘", class = CLASS.ORD, desc = "circle",      aliases = {} },
  { utf8 = "✠", class = CLASS.ORD, desc = "maltese",     aliases = {} },
  { utf8 = "✓", class = CLASS.ORD, desc = "checkmark",   aliases = {} },
  { utf8 = "¥", class = CLASS.ORD, desc = "yen",         aliases = {} },
  { utf8 = "£", class = CLASS.ORD, desc = "pounds",      aliases = {} },
  { utf8 = "€", class = CLASS.ORD, desc = "euro",        aliases = {} },
  { utf8 = "¢", class = CLASS.ORD, desc = "cent",        aliases = {} },
  { utf8 = "°", class = CLASS.ORD, desc = "degree",      aliases = {} },
  { utf8 = "§", class = CLASS.ORD, desc = "section",     aliases = {"S"} },
  { utf8 = "¶", class = CLASS.ORD, desc = "pilcrow",     aliases = {"P"} },
  { utf8 = "℗", class = CLASS.ORD, desc = "copyright",   aliases = {} },
  { utf8 = "®", class = CLASS.ORD, desc = "registered",  aliases = {} },
  { utf8 = "™", class = CLASS.ORD, desc = "trademark",   aliases = {} },
  { utf8 = "♯", class = CLASS.ORD, desc = "sharp",       aliases = {} },
  { utf8 = "♭", class = CLASS.ORD, desc = "flat",        aliases = {} },
  { utf8 = "♮", class = CLASS.ORD, desc = "natural",     aliases = {} },
  { utf8 = "♣", class = CLASS.ORD, desc = "clubsuit",    aliases = {} },
  { utf8 = "♢", class = CLASS.ORD, desc = "diamondsuit", aliases = {} },
  { utf8 = "♡", class = CLASS.ORD, desc = "heartsuit",   aliases = {} },
  { utf8 = "♠", class = CLASS.ORD, desc = "spadesuit",   aliases = {} },
  { utf8 = "ð", class = CLASS.ORD, desc = "eth",         aliases = {} },
  { utf8 = "ı", class = CLASS.ORD, desc = "imath",       aliases = {} },
  { utf8 = "ȷ", class = CLASS.ORD, desc = "jmath",       aliases = {} },
  { utf8 = "∁", class = CLASS.ORD, desc = "complement",  aliases = {} },
  { utf8 = "∅", class = CLASS.ORD, desc = "diameter",    aliases = {} },
  { utf8 = "↯", class = CLASS.ORD, desc = "lightning",   aliases = {} },
  { utf8 = "◊", class = CLASS.ORD, desc = "lozenge",     aliases = {} },
  { utf8 = "∎", class = CLASS.ORD, desc = "qed",         aliases = {} },
  { utf8 = "♮", class = CLASS.ORD, desc = "natural",     aliases = {} },
  { utf8 = "♭", class = CLASS.ORD, desc = "flat",        aliases = {} },
  { utf8 = "♯", class = CLASS.ORD, desc = "sharp",       aliases = {} },
  { utf8 = "♪", class = CLASS.ORD, desc = "eighthnote",  aliases = {} },
  { utf8 = "♫", class = CLASS.ORD, desc = "beamednotes", aliases = {} },
  { utf8 = "☀", class = CLASS.ORD, desc = "sun",         aliases = {} },
  { utf8 = "", class = CLASS.ORD, desc = "unknown",     aliases = {} },
}

-- =========================================================================
-- Index construction (run once at load time)
-- =========================================================================

local NAME_INDEX = {}
local CHAR_INDEX = {}
local CLASS_INDEX = {
  [CLASS.ORD]   = {},
  [CLASS.OP]    = {},
  [CLASS.BIN]   = {},
  [CLASS.REL]   = {},
  [CLASS.OPEN]  = {},
  [CLASS.CLOSE] = {},
  [CLASS.PUNCT] = {},
  [CLASS.INNER] = {},
}

local function build_indexes()
  for _, sym in ipairs(SYMBOLS) do
    -- Primary name
    NAME_INDEX[sym.desc] = sym
    -- Aliases
    for _, alias in ipairs(sym.aliases) do
      if not NAME_INDEX[alias] then
        NAME_INDEX[alias] = sym
      end
    end
    -- Character lookup
    CHAR_INDEX[sym.utf8] = sym
    -- Class buckets
    CLASS_INDEX[sym.class][#CLASS_INDEX[sym.class] + 1] = sym
  end
end

build_indexes()

-- =========================================================================
-- Spacing helper
-- =========================================================================

local function inter_atom_spacing(left_class, right_class)
  local row = SPACING[left_class]
  if not row then
    return { 0, 0 }
  end
  local cell = row[right_class]
  if not cell then
    return { 0, 0 }
  end
  return { cell[1] or 0, cell[2] or 0 }
end

-- =========================================================================
-- Capability implementations
-- =========================================================================

-- math.symbol.resolve
--   Look up a symbol by name (LaTeX command name without the backslash).
--   Optional fallback name if the primary is not found.
kernel["math.symbol.resolve"] = function(inputs)
  local name = inputs.name
  local fallback = inputs.fallback
  local sym = NAME_INDEX[name]

  if not sym and fallback then
    sym = NAME_INDEX[fallback]
  end

  if not sym then
    return {
      codepoint = nil,
      char = name,
      classification = CLASS.ORD,
      spacing = { left = 0, right = 0 },
      description = nil,
      error = "symbol not found: " .. tostring(name)
    }
  end

  return {
    codepoint = sym.utf8,
    char = sym.utf8,
    classification = sym.class,
    spacing = {
      left = inter_atom_spacing(CLASS.ORD, sym.class)[1],
      right = inter_atom_spacing(sym.class, CLASS.ORD)[1],
    },
    description = sym.desc
  }
end

-- math.symbol.classify
--   Given a Unicode character, return its math atom classification.
kernel["math.symbol.classify"] = function(inputs)
  local c = inputs.char
  local sym = CHAR_INDEX[c]

  if not sym then
    return {
      classification = CLASS.ORD,
      spacing = { left = 0, right = 0 }
    }
  end

  return {
    classification = sym.class,
    spacing = {
      left = inter_atom_spacing(CLASS.ORD, sym.class)[1],
      right = inter_atom_spacing(sym.class, CLASS.ORD)[1],
    }
  }
end

-- math.symbol.list
--   List symbols, optionally filtered by atom classification.
kernel["math.symbol.list"] = function(inputs)
  local category = inputs.category
  local result = {}

  if category and CLASS_INDEX[category] then
    local seen = {}
    for _, sym in ipairs(CLASS_INDEX[category]) do
      if not seen[sym.desc] then
        seen[sym.desc] = true
        result[#result + 1] = {
          name = sym.desc,
          char = sym.utf8,
          classification = sym.class,
          aliases = sym.aliases
        }
      end
    end
  else
    local seen = {}
    for _, sym in ipairs(SYMBOLS) do
      if not seen[sym.desc] then
        seen[sym.desc] = true
        result[#result + 1] = {
          name = sym.desc,
          char = sym.utf8,
          classification = sym.class,
          aliases = sym.aliases
        }
      end
    end
  end

  return { symbols = result }
end

-- =========================================================================
-- Entry point
-- =========================================================================

if arg and arg[1] == "--advertise" then
  local json = require("doxtk_ljson")
  print(json.encode(kernel.advertise()))
else
  return kernel
end
