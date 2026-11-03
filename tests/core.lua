vim.opt.rtp:prepend(vim.fn.getcwd())
local theme = require("theme_tools")
local colors = require("theme_tools.colors")
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/colors", "p")
vim.opt.rtp:prepend(root)
vim.fn.writefile({
  'vim.g.colors_name = "broken"',
  'vim.o.background = "light"',
  'vim.api.nvim_set_hl(0, "Normal", {bg="#ff0000"})',
  'vim.api.nvim_set_hl(0, "BrokenOnly", {fg="#ff0000"})',
  'vim.api.nvim_set_hl(0, "UserDefault", {fg="#ff0000"})',
  'vim.g.terminal_color_0 = "#ff0000"',
  'error("intentional broken theme")',
}, root .. "/colors/broken.lua")
vim.fn.writefile({ 'vim.cmd.runtime("colors/desert.vim")' }, root .. "/colors/alias.lua")
local path = root .. "/state/selection.json"
local changed, warnings = {}, {}
vim.notify = function(message)
  warnings[#warnings + 1] = message
end
vim.api.nvim_create_autocmd("User", {
  pattern = "ThemeToolsChanged",
  callback = function(event)
    changed[#changed + 1] = event.data
  end,
})
local opts = {
  catppuccin = false,
  state_file = path,
  themes = {
    { name = "night", colorscheme = "habamax", background = "dark" },
    { name = "day", colorscheme = "morning", background = "light" },
    "desert",
    "broken",
  },
}
theme.setup(opts)
assert(#theme.list() == 4, "explicit list should not include discovered themes")
assert(theme.set("night"))
assert(theme.current() == "night")
assert(vim.o.background == "dark")
assert(vim.json.decode(table.concat(vim.fn.readfile(path))).name == "night")
assert(changed[#changed].name == "night")
vim.api.nvim_set_hl(0, "UserCustom", { fg = "#123456", bold = true })
vim.api.nvim_set_hl(0, "UserDefault", { fg = "#654321", default = true })
vim.g.terminal_color_0 = "#abcdef"
local snapshot = colors.snapshot()
assert(not theme.set("broken"))
assert(vim.g.colors_name == snapshot.name and vim.o.background == snapshot.background)
for name, value in pairs(snapshot.highlights) do
  local actual = vim.api.nvim_get_hl(0, { name = name })
  assert(vim.deep_equal(actual, value), "highlight not restored: " .. name .. " " .. vim.inspect({ actual, value }))
end
assert(vim.g.terminal_color_0 == "#abcdef")
assert(vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = "BrokenOnly" })))
assert(theme.current() == "night")
assert(not theme.set("missing"))
assert(#changed == 1, "failed themes must not commit")
assert(theme.next() and theme.current() == "day")
assert(theme.prev() and theme.current() == "night")
theme.register("alias")
assert(theme.set("alias") and vim.g.colors_name == "desert")
assert(theme.current() == "alias", "aliases must retain their registered ID")
assert(theme.next() and theme.current() == "night", "cycling must use alias position")
theme.setup(opts)
assert(theme.current() == "night", "setup should restore the saved ID")
theme.register({ name = "night", colorscheme = "evening" })
assert(#theme.list() == 4)
assert(theme.set("night") and vim.g.colors_name == "evening")
-- Arbitrary state IDs cannot execute unregistered colorschemes.
vim.fn.writefile({ '{"name":"unregistered"}' }, path)
theme.setup(vim.tbl_extend("force", opts, { default = "day" }))
assert(theme.current() == "day")
vim.fn.writefile({ "not JSON" }, path)
theme.setup(opts)
assert(warnings[#warnings]:find("Invalid theme state", 1, true))
theme.setup({ catppuccin = false, persist = false, themes = { "habamax", "desert" }, state_file = path })
assert(theme.set("habamax"))
assert(table.concat(vim.fn.readfile(path)) == "not JSON", "persist=false must not write")
theme.setup({ catppuccin = false, persist = false, discover = false })
assert(not theme.next())
assert(not theme.pick())
theme.setup({ catppuccin = false, persist = false })
assert(#theme.list() > 0)
assert(vim.fn.exists(":ThemeTools") == 2 and vim.fn.exists(":ThemeToolsNext") == 2)
assert(vim.tbl_contains(vim.fn.getcompletion("ThemeTools hab", "cmdline"), "habamax"))
assert(not pcall(theme.setup, { themes = { {} } }))
assert(not pcall(theme.setup, { picker = { width = 0 } }))
-- No colors_name: restore a manually constructed palette too.
vim.g.colors_name = nil
vim.api.nvim_set_hl(0, "Normal", { fg = "#aabbcc", bg = "#112233" })
snapshot = colors.snapshot()
assert(colors.apply({ colorscheme = "morning" }))
colors.restore(snapshot)
assert(vim.g.colors_name == nil)
assert(vim.deep_equal(vim.api.nvim_get_hl(0, { name = "Normal" }), snapshot.highlights.Normal))
vim.fn.delete(root, "rf")
print("core: registry, cycling, rollback, state, commands and validation passed")
