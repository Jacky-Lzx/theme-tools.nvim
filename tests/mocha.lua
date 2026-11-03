vim.opt.runtimepath:prepend(vim.fn.getcwd())
local themes = require("theme_tools")
local install_root = vim.fn.tempname()
themes.setup({
  persist = false,
  install = { root = install_root },
  default = "theme-tools-mocha",
  themes = { "theme-tools-mocha", "catppuccin-latte" },
})
assert(vim.g.colors_name == "theme-tools-mocha")
assert(not package.loaded.catppuccin and not package.loaded["theme_tools.providers.catppuccin"])
assert(not package.loaded["theme_tools.mocha.palette"] and not package.loaded["theme_tools.mocha.build"])
assert(vim.fn.isdirectory(install_root) == 0)
local palette = require("theme_tools.mocha.palette")
local function rgb(hex)
  return tonumber(hex:sub(2), 16)
end
assert(vim.o.background == "dark" and vim.o.termguicolors)
assert(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == nil)
assert(vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).bg == nil)
assert(vim.api.nvim_get_hl(0, { name = "UiToolsLineNr" }).fg == rgb(palette.surface2))
assert(vim.api.nvim_get_hl(0, { name = "GitToolsAdd" }).fg == rgb(palette.green))
local custom = vim.api.nvim_get_hl(0, { name = "CurSearch" })
assert(custom.bg == rgb(palette.mauve) and custom.fg == rgb(palette.search_text))
local _, terminal = require("theme_tools.mocha.build").definitions()
for name, value in pairs(terminal) do
  assert(vim.g[name] == value, name)
end
-- Returning from a light scheme must not reload the previous theme recursively.
themes.setup({ persist = false, catppuccin = false, themes = { "morning", "theme-tools-mocha" } })
assert(themes.set("morning"))
assert(themes.set("theme-tools-mocha"))
assert(vim.o.background == "dark" and vim.g.colors_name == "theme-tools-mocha")
assert(not package.loaded.catppuccin)
print("independent Mocha: offline startup, lazy sources, generated highlights and light-to-dark switching passed")
