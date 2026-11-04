vim.opt.runtimepath:prepend(vim.fn.getcwd())
local themes = require("theme_tools")
local install_root = vim.fn.tempname()
themes.setup({
  persist = false,
  install = { root = install_root },
  default = "theme-tools-dracula",
  themes = { "theme-tools-dracula", "theme-tools-mocha", "morning" },
})
assert(vim.g.colors_name == "theme-tools-dracula" and vim.o.background == "dark")
assert(vim.o.termguicolors)
assert(not package.loaded.dracula and not package.loaded.catppuccin)
assert(not package.loaded["theme_tools.providers.dracula"])
assert(not package.loaded["theme_tools.dracula.palette"] and not package.loaded["theme_tools.dracula.build"])
assert(vim.fn.isdirectory(install_root) == 0, "independent startup installed a provider")
local selected = vim.api.nvim_get_hl(0, { name = "PmenuSel", link = false })
assert(selected.bg == 0x44475a and selected.bold and not selected.fg)
assert(not vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg)
assert(not vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).bg)
local c = themes.palette()
assert(c.name == "theme-tools-dracula" and c.transparent and c.palette.bg == "#282a36")
assert(c.palette.green == "#50fa7b" and c.palette.purple == "#bd93f9")
local line = require("lualine.themes.theme-tools-dracula")
assert(line.normal.a.bg == "#BD93F9" and line.normal.c.bg == "NONE")
assert(not package.loaded.dracula, "statusline loaded upstream Dracula")
assert(themes.list()[1].background == "dark")
assert(themes.set("morning"))
assert(themes.set("theme-tools-dracula"))
assert(vim.g.colors_name == "theme-tools-dracula" and vim.o.background == "dark")
themes.setup({
  persist = false,
  catppuccin = false,
  dracula = false,
  themes = { { name = "theme-tools-dracula", transparent = false }, "theme-tools-mocha" },
})
assert(themes.set("theme-tools-dracula"))
assert(vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg == 0x282a36)
assert(themes.palette().palette.bg == "#282a36" and not themes.palette().transparent)
assert(themes.set("theme-tools-mocha"))
assert(themes.set("theme-tools-dracula"))
assert(vim.g.terminal_color_background == "#282A36" and vim.g.terminal_color_4 == "#BD93F9")
assert(not package.loaded.dracula and not package.loaded.catppuccin)
print(
  "independent Dracula: offline startup, palette, selection colors, statusline, transparency and theme switching passed"
)
