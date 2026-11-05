vim.opt.rtp:prepend(vim.fn.getcwd())
local api = vim.api
local themes = require("theme_tools")
local colors = require("theme_tools.colors")
local dir = vim.fn.tempname()
themes.setup({
  catppuccin = false,
  dracula = false,
  state_file = dir .. "/theme.json",
  themes = { { name = "night", colorscheme = "theme-tools-dracula", transparent = false }, "morning" },
  default = "night",
  icons = { default = "mini", state_file = dir .. "/icons.json" },
  palette = { overrides = { ui = { accent = "#123456" } } },
})
assert(not package.loaded["theme_tools.info"], "diagnostics loaded during startup")
assert(vim.fn.exists(":ThemeToolsInfo") == 2)
assert(vim.tbl_contains(vim.fn.getcompletion("ThemeToolsInfo Norm", "cmdline"), "NormalFloat"))

api.nvim_set_hl(0, "InfoBase", { fg = "#abcdef", italic = true })
api.nvim_set_hl(0, "InfoLink", { link = "InfoBase" })
api.nvim_set_hl(0, "InfoOther", { fg = "#fedcba", bg = "#123456" })
api.nvim_set_hl(0, "InfoCycleA", { link = "InfoCycleB" })
api.nvim_set_hl(0, "InfoCycleB", { link = "InfoCycleA" })
vim.wo.winhighlight = "InfoBase:InfoOther"
local before = colors.snapshot()
local saved = vim.uv.fs_stat(dir .. "/theme.json")
local events = 0
api.nvim_create_autocmd({ "ColorScheme", "User" }, {
  callback = function()
    events = events + 1
  end,
})
local opts = { groups = { "InfoLink", "InfoMissing", "InfoCycleA" } }
local value = themes.info(opts)
assert(value.theme.id == "night" and value.theme.colorscheme == "theme-tools-dracula")
assert(value.theme.background == "dark" and not value.theme.transparent)
assert(value.icons.name == "mini" and value.icons.style == "glyph" and not value.icons.loaded)
assert(value.palette.ui.accent == "#123456", "report must use final semantic overrides")
assert(vim.deep_equal(value.highlights[1].chain, { "InfoLink", "InfoBase" }))
assert(value.highlights[1].attributes.fg == 0xabcdef and value.highlights[1].attributes.italic)
assert(value.highlights[2].status == "undefined")
assert(value.highlights[3].status == "cycle", "link cycles must terminate")
assert(vim.fn.hlexists("InfoMissing") == 0, "inspection created an undefined group")
value.palette.ui.accent = "#ffffff"
value.highlights[1].attributes.fg = 0
value.icons.name = "mutated"
assert(themes.palette().ui.accent == "#123456" and themes.icons.current() == "mini")
assert(api.nvim_get_hl(0, { name = "InfoBase", link = true }).fg == 0xabcdef)

local source_buf, source_win = api.nvim_get_current_buf(), api.nvim_get_current_win()
api.nvim_buf_set_lines(source_buf, 0, -1, false, { "unsaved source" })
vim.cmd("ThemeToolsInfo InfoLink")
local buf, win = api.nvim_get_current_buf(), api.nvim_get_current_win()
local text = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
assert(text:find("InfoLink -> InfoBase", 1, true) and text:find("fg=#abcdef", 1, true))
assert(text:find("ui.accent", 1, true) and text:find("#123456", 1, true))
assert(not vim.bo[buf].modifiable and vim.bo[buf].buftype == "nofile")
assert(not pcall(api.nvim_buf_set_lines, buf, 0, -1, false, { "accidental edit" }))
local mappings = {}
for _, map in ipairs(api.nvim_buf_get_keymap(buf, "n")) do
  mappings[map.lhs] = map.callback
end
assert(mappings.r and mappings.q)
assert(themes.set("morning"))
mappings.r()
text = table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
assert(text:find("Colorscheme: morning", 1, true) and text:find("InfoLink\n    undefined", 1, true))
mappings.q()
assert(not api.nvim_win_is_valid(win) and not api.nvim_buf_is_valid(buf))
assert(api.nvim_get_current_win() == source_win and api.nvim_get_current_buf() == source_buf)
assert(vim.bo[source_buf].modified and api.nvim_buf_get_lines(source_buf, 0, -1, false)[1] == "unsaved source")

-- Reading/opening the report cannot apply a theme or prepare a provider.
assert(themes.set("night"))
colors.restore(before)
local saved_again = vim.uv.fs_stat(dir .. "/theme.json")
events = 0
before = colors.snapshot()
local report_buf, report_win = require("theme_tools.info").open()
api.nvim_win_close(report_win, true)
assert(not api.nvim_buf_is_valid(report_buf))
assert(events == 0 and vim.deep_equal(colors.snapshot(), before))
local after = vim.uv.fs_stat(dir .. "/theme.json")
assert(saved_again.ino == after.ino and vim.deep_equal(saved_again.mtime, after.mtime))
assert(saved, "theme fixture must have persisted a real selection")
assert(not vim.uv.fs_stat(dir .. "/icons.json"))
assert(not package.loaded["mini.icons"] and not package.loaded["nvim-web-devicons"])
assert(not package.loaded["theme_tools.icons.providers"] and not package.loaded["theme_tools.install"])
vim.fn.delete(dir, "rf")
print(
  "theme info: lazy diagnostics, final roles, raw links, cycles, missing groups, refresh, source and state preservation passed"
)
