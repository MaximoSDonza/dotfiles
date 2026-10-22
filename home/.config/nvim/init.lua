-- Cybersigil: esquema con la paleta (lo genera cybersigil-apply en colors/cybersigil.lua) y sin fondo
-- propio, así se ve el de kitty (negro semitransparente con la imagen).
vim.opt.termguicolors = true

local function transparente()
  for _, grupo in ipairs({ "Normal", "NormalNC", "SignColumn", "EndOfBuffer", "LineNr", "FoldColumn", "CursorLineNr" }) do
    vim.api.nvim_set_hl(0, grupo, vim.tbl_extend("force", vim.api.nvim_get_hl(0, { name = grupo }), { bg = "NONE" }))
  end
end

-- también si después se cambia de esquema de colores
vim.api.nvim_create_autocmd("ColorScheme", { callback = transparente })
if not pcall(vim.cmd.colorscheme, "cybersigil") then
  transparente()   -- todavía no se ejecutó cybersigil-apply: esquema por defecto, sin fondo
end
