-- Cybersigil — esquema de neovim generado por cybersigil-apply desde palette.sh
-- Sin fondo propio: se ve el de kitty (negro semitransparente con la imagen). Los mismos colores de
-- código que VS Code e IntelliJ, todos con contraste ≥ 4,5:1.
vim.cmd("highlight clear")
vim.g.colors_name = "cybersigil"
vim.o.background = "dark"

local c = {
  bg_alt = "@@BG_ALT@@", surface = "@@SURFACE@@", surface_hi = "@@SURFACE_HI@@",
  text = "@@TEXT@@", chrome = "@@CHROME@@", chrome_dim = "@@CHROME_DIM@@", chrome_hi = "@@CHROME_HI@@",
  accent = "@@ACCENT@@", accent_hi = "@@ACCENT_HI@@", accent_soft = "@@ACCENT_SOFT@@",
  string = "@@SYN_STRING@@", number = "@@SYN_NUMBER@@", type = "@@SYN_TYPE@@",
  property = "@@SYN_PROPERTY@@", comment = "@@SYN_COMMENT@@",
}

local grupos = {
  -- interfaz
  Normal = { fg = c.text }, NormalNC = { fg = c.text },
  NormalFloat = { fg = c.text, bg = c.surface }, FloatBorder = { fg = c.chrome_dim, bg = c.surface },
  FloatTitle = { fg = c.chrome_hi, bg = c.surface, bold = true },
  Cursor = { fg = "@@BG@@", bg = c.accent_hi }, CursorLine = { bg = c.bg_alt }, CursorColumn = { bg = c.bg_alt },
  CursorLineNr = { fg = c.accent_hi, bold = true }, LineNr = { fg = c.chrome_dim },
  SignColumn = {}, FoldColumn = { fg = c.chrome_dim }, Folded = { fg = c.chrome, bg = c.bg_alt },
  EndOfBuffer = { fg = c.bg_alt }, NonText = { fg = c.chrome_dim }, Whitespace = { fg = c.surface_hi },
  ColorColumn = { bg = c.bg_alt }, WinSeparator = { fg = c.chrome_dim }, VertSplit = { fg = c.chrome_dim },
  StatusLine = { fg = c.chrome_hi, bg = c.surface }, StatusLineNC = { fg = c.chrome, bg = c.bg_alt },
  TabLine = { fg = c.chrome, bg = c.bg_alt }, TabLineSel = { fg = c.chrome_hi, bg = c.surface, bold = true },
  TabLineFill = { bg = c.bg_alt }, WinBar = { fg = c.chrome }, WinBarNC = { fg = c.chrome_dim },
  Visual = { bg = c.accent }, VisualNOS = { bg = c.surface_hi },
  Search = { fg = c.chrome_hi, bg = c.accent }, IncSearch = { fg = "@@BG@@", bg = c.accent_soft },
  CurSearch = { fg = "@@BG@@", bg = c.accent_soft }, Substitute = { fg = "@@BG@@", bg = c.accent_soft },
  MatchParen = { fg = c.accent_soft, bold = true, underline = true },
  Pmenu = { fg = c.text, bg = c.surface }, PmenuSel = { fg = c.chrome_hi, bg = c.accent },
  PmenuSbar = { bg = c.surface }, PmenuThumb = { bg = c.chrome_dim }, PmenuKind = { fg = c.type, bg = c.surface },
  WildMenu = { fg = c.chrome_hi, bg = c.accent },
  Title = { fg = c.chrome_hi, bold = true }, Directory = { fg = c.type },
  ModeMsg = { fg = c.chrome_hi }, MoreMsg = { fg = c.chrome }, Question = { fg = c.chrome },
  ErrorMsg = { fg = c.accent_soft }, WarningMsg = { fg = c.number },
  SpellBad = { sp = c.accent_soft, undercurl = true }, SpellCap = { sp = c.number, undercurl = true },
  SpellRare = { sp = c.property, undercurl = true }, SpellLocal = { sp = c.type, undercurl = true },
  QuickFixLine = { bg = c.surface_hi },

  -- sintaxis (mismos colores que VS Code e IntelliJ)
  Comment = { fg = c.comment, italic = true },
  Constant = { fg = c.number }, String = { fg = c.string }, Character = { fg = c.string },
  Number = { fg = c.number }, Boolean = { fg = c.number }, Float = { fg = c.number },
  Identifier = { fg = c.text }, Function = { fg = c.chrome_hi },
  Statement = { fg = c.accent_soft }, Keyword = { fg = c.accent_soft }, Conditional = { fg = c.accent_soft },
  Repeat = { fg = c.accent_soft }, Exception = { fg = c.accent_soft }, Label = { fg = c.accent_soft },
  Operator = { fg = c.chrome }, PreProc = { fg = c.accent_soft }, Include = { fg = c.accent_soft },
  Type = { fg = c.type }, StorageClass = { fg = c.accent_soft }, Structure = { fg = c.type },
  Special = { fg = c.property }, SpecialChar = { fg = c.number }, Delimiter = { fg = c.chrome },
  Tag = { fg = c.accent_soft }, Underlined = { underline = true },
  Error = { fg = c.accent_soft }, Todo = { fg = "@@BG@@", bg = c.accent_soft, bold = true },

  -- treesitter y LSP
  ["@variable"] = { fg = c.text }, ["@variable.builtin"] = { fg = c.property, italic = true },
  ["@variable.parameter"] = { fg = c.text, italic = true }, ["@variable.member"] = { fg = c.property },
  ["@property"] = { fg = c.property }, ["@constant"] = { fg = c.number }, ["@constant.builtin"] = { fg = c.number },
  ["@module"] = { fg = c.type }, ["@function.builtin"] = { fg = c.chrome_hi, italic = true },
  ["@constructor"] = { fg = c.type }, ["@type.builtin"] = { fg = c.type, italic = true },
  ["@keyword.return"] = { fg = c.accent_soft, bold = true }, ["@punctuation"] = { fg = c.chrome },
  ["@tag"] = { fg = c.accent_soft }, ["@tag.attribute"] = { fg = c.property }, ["@tag.delimiter"] = { fg = c.chrome },
  ["@markup.heading"] = { fg = c.chrome_hi, bold = true }, ["@markup.strong"] = { bold = true },
  ["@markup.italic"] = { italic = true }, ["@markup.link"] = { fg = c.accent_soft, underline = true },
  ["@markup.raw"] = { fg = c.string }, ["@markup.list"] = { fg = c.accent_soft },
  ["@lsp.type.parameter"] = { link = "@variable.parameter" }, ["@lsp.type.property"] = { link = "@property" },
  LspReferenceText = { bg = c.surface_hi }, LspReferenceRead = { bg = c.surface_hi }, LspReferenceWrite = { bg = c.surface_hi },
  DiagnosticError = { fg = c.accent_soft }, DiagnosticWarn = { fg = c.number },
  DiagnosticInfo = { fg = c.type }, DiagnosticHint = { fg = c.chrome },
  DiagnosticUnderlineError = { sp = c.accent_soft, undercurl = true },
  DiagnosticUnderlineWarn = { sp = c.number, undercurl = true },
  DiagnosticUnderlineInfo = { sp = c.type, undercurl = true },
  DiagnosticUnderlineHint = { sp = c.chrome, undercurl = true },

  -- diferencias y git
  DiffAdd = { bg = "#0f1a12" }, DiffChange = { bg = c.bg_alt }, DiffDelete = { fg = c.accent_hi, bg = "#1a0709" },
  DiffText = { bg = c.surface_hi }, Added = { fg = c.string }, Changed = { fg = c.number }, Removed = { fg = c.accent_soft },
}

for nombre, estilo in pairs(grupos) do
  vim.api.nvim_set_hl(0, nombre, estilo)
end

-- colores de la terminal integrada (:terminal), los mismos de kitty
for i, color in ipairs({ c.bg_alt, c.accent, "#8a8f88", "#a89f91", "#7d8590", "#8e7d8a", "#86918f", c.chrome,
                         c.chrome_dim, c.accent_hi, c.string, c.number, c.type, c.property, "#b0bcb9", c.chrome_hi }) do
  vim.g["terminal_color_" .. (i - 1)] = color
end
