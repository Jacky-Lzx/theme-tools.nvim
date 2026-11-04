vim.opt.rtp:prepend(vim.fn.getcwd())
local themes = require("theme_tools")
local colors = require("theme_tools.colors")
local state = require("theme_tools.state")
local path = vim.fn.tempname()
local opts = {
  state_file = path,
  catppuccin = false,
  dracula = false,
  default = "theme-tools-mocha",
  themes = { "theme-tools-mocha", { name = "day", colorscheme = "morning", background = "light", transparent = true } },
}
themes.setup(opts)
assert(themes.palette().transparent)
local events = {}
themes.on_change("transparency-test", function(c)
  events[#events + 1] = c
end)
assert(colors.apply({ colorscheme = "theme-tools-mocha", transparent = false }))
assert(not themes.palette().transparent and events[#events].ui.bg == "#1e1e2e")
for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder", "FloatTitle", "StatusLine" }) do
  assert(vim.api.nvim_get_hl(0, { name = group, link = false }).bg ~= nil, group)
end
local snapshot = colors.snapshot()
assert(colors.apply({ colorscheme = "morning", background = "light", transparent = true }))
assert(themes.palette().transparent)
for _, group in ipairs({ "Normal", "NormalNC", "NormalFloat", "FloatBorder", "FloatTitle", "StatusLine" }) do
  assert(vim.api.nvim_get_hl(0, { name = group, link = false }).bg == nil, group)
end
colors.restore(snapshot)
assert(not themes.palette().transparent and themes.palette().ui.bg == "#1e1e2e")
assert(themes.set("day") and themes.palette().transparent)
local name, err, preferences = state.read(path)
assert(name == "day" and not err and preferences.day == true)
preferences["theme-tools-mocha"] = false
assert(state.write(path, "theme-tools-mocha", preferences))
themes.setup(opts)
assert(not themes.palette().transparent, "startup did not restore explicit false")
assert(themes.list()[1].transparent == false)
local stat = vim.uv.fs_stat(path)
assert(themes.set("theme-tools-mocha"))
assert(vim.uv.fs_stat(path).ino == stat.ino, "unchanged preference rewrote state")
local _, _, latest = state.read(path)
latest["another-instance"] = true
assert(state.write(path, "theme-tools-mocha", latest))
assert(themes.set("day") and themes.palette().transparent)
assert(select(3, state.read(path))["another-instance"] == true, "another editor's preference was lost")
assert(themes.set("theme-tools-mocha") and not themes.palette().transparent)
-- Legacy files keep native theme defaults.
vim.fn.writefile({ '{"name":"theme-tools-mocha"}' }, path)
themes.setup(opts)
assert(themes.palette().transparent)
assert(select(3, state.read(path)) == nil)
-- Invalid preferences cannot escape the data schema.
vim.fn.writefile({ '{"name":"day","transparency":{"day":"false"}}' }, path)
assert(state.read(path) == nil)
opts.persist = false
themes.setup(opts)
assert(themes.palette().transparent)
assert(not pcall(themes.register, { name = "invalid", transparent = "yes" }))
assert(not pcall(themes.setup, { picker = { transparency_key = 12 } }))
vim.fn.delete(path)
print(
  "transparency: opaque/transparent editor and floats, palette publication, rollback, per-theme state and legacy restore passed"
)
