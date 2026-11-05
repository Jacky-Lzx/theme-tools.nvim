vim.opt.rtp:prepend(vim.fn.getcwd())
local themes = require("theme_tools")
local colors = require("theme_tools.colors")
local api = vim.api
local warnings = {}
vim.notify = function(message)
  warnings[#warnings + 1] = tostring(message)
end
local opts = {
  persist = false,
  catppuccin = false,
  dracula = false,
  default = "theme-tools-mocha",
  themes = { "theme-tools-mocha", "theme-tools-dracula", "morning", "desert" },
}
themes.setup(opts)
assert(not package.loaded["theme_tools.mocha.palette"], "unused palette must stay lazy")
local c = themes.palette()
assert(c.name == "theme-tools-mocha" and c.background == "dark" and c.transparent)
assert(c.ui.bg == "NONE" and c.palette.bg == "#1e1e2e")
assert(c.palette.blue == "#89b4fa" and c.palette.purple == "#cba6f7")
assert(c.ui.selection_bg == "#6c7086" and c.diagnostic.error == "#f38ba8")
assert(c.ui.search_fg == "NONE", "background-only Search must preserve text foregrounds")
assert(not package.loaded.catppuccin and not package.loaded.dracula)
-- Builtin Added/Removed defaults must not mask each theme's explicit diff colors.
assert(c.git.add == "#a6e3a1" and c.git.delete == "#f38ba8")
assert(themes.set("theme-tools-dracula"))
local dracula = themes.palette()
assert(dracula.git.add == "#50fa7b" and dracula.git.delete == "#ff5555")
assert(dracula.ui.search_fg == "#191a21", "explicit search foreground must survive")
assert(themes.set("theme-tools-mocha"))
c.ui.accent = "#000000"
assert(themes.palette().ui.accent ~= "#000000", "palette() leaked mutable state")

local seen, other = {}, {}
local function subscriber(value)
  seen[#seen + 1] = value
  api.nvim_set_hl(0, "PaletteConsumer", { fg = value.ui.accent, bg = value.ui.bg })
  value.ui.accent = "#000000"
end
local old_stop = themes.on_change("consumer", function() end)
local stop = themes.on_change("consumer", subscriber)
old_stop()
assert(#seen == 1, "late subscriber must run immediately")
local same_callback_stop = stop
stop = themes.on_change("consumer", subscriber)
same_callback_stop()
local stop_other = themes.on_change("other", function(value)
  other[#other + 1] = value
end)
local stop_broken = themes.on_change("broken", function()
  error("consumer failure")
end)
local before = #seen
assert(themes.set("morning"))
assert(#seen == before + 1 and other[#other].name == "morning")
assert(other[#other].ui.accent ~= "#000000", "one subscriber mutated another's palette")
assert(not themes.palette().transparent)
assert(api.nvim_get_hl(0, { name = "PaletteConsumer" }).fg ~= 0)
vim.wait(10)
assert(#warnings > 0 and warnings[1]:find("consumer failure", 1, true))
stop_broken()

-- Direct :colorscheme waits for later ColorScheme overrides and coalesces bursts.
api.nvim_create_autocmd("ColorScheme", {
  pattern = "desert",
  callback = function()
    api.nvim_set_hl(0, "Function", { fg = "#123abc" })
  end,
})
before = #seen
vim.cmd.colorscheme("morning")
vim.cmd.colorscheme("desert")
assert(themes.palette().ui.accent == "#123abc", "direct palette read was stale")
vim.wait(10)
assert(#seen == before + 1 and other[#other].ui.accent == "#123abc")
assert(themes.set("theme-tools-mocha"))
before = #seen
vim.wait(10)
assert(#seen == before, "managed application left a duplicate notification queued")

-- Live previews and their exact restoration share the same publication path.
local original = colors.snapshot()
assert(colors.apply({ colorscheme = "morning", background = "light" }))
assert(other[#other].name == "morning")
colors.restore(original)
assert(other[#other].name == "theme-tools-mocha" and themes.palette().ui.bg == "NONE")

local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/colors", "p")
vim.opt.rtp:prepend(root)
vim.fn.writefile({
  'vim.g.colors_name = "palette-broken"',
  'vim.api.nvim_set_hl(0, "Function", {fg="#ff0000"})',
  'error("broken scheme")',
}, root .. "/colors/palette-broken.lua")
before = #other
assert(not colors.apply({ colorscheme = "palette-broken" }))
assert(#other == before + 1 and other[#other].name == "theme-tools-mocha")
assert(themes.palette().ui.accent == "#89b4fa", "failed palette was published")
vim.wait(10)
assert(#other == before + 1, "rollback left stale events queued")

-- Global and per-theme overrides compose, and survive repeated setup calls.
opts.palette = {
  overrides = { ui = { accent = "#123456", search_fg = "NONE" } },
  themes = {
    ["theme-tools-mocha"] = function(value)
      assert(value.ui.accent == "#123456")
      return { ui = { muted = "#654321" } }
    end,
  },
}
themes.setup(opts)
c = themes.palette()
assert(c.ui.accent == "#123456" and c.ui.muted == "#654321")
assert(c.ui.search_fg == "NONE", "inherited search foreground override was rejected")
assert(other[#other].ui.muted == "#654321", "setup lost subscriptions")
opts.palette.overrides = { ui = { accent = "invalid" } }
themes.setup(opts)
assert(themes.palette().ui.accent == "#89b4fa", "invalid override escaped validation")

-- No provider and almost no highlights: every required token is still available.
opts.palette = {}
opts.default = nil
themes.setup(opts)
vim.cmd("highlight clear")
vim.g.colors_name = "unknown-theme"
api.nvim_set_hl(0, "Normal", { fg = "#aabbcc" })
api.nvim_exec_autocmds("ColorScheme", { pattern = "unknown-theme" })
vim.wait(10)
c = themes.palette()
assert(c.name == "unknown-theme" and c.ui.fg == "#aabbcc" and c.ui.bg == "NONE")
for _, section in ipairs({ "palette", "ui", "diagnostic", "git" }) do
  for name, value in pairs(c[section]) do
    assert(value == "NONE" or value:match("^#%x%x%x%x%x%x$"), section .. "." .. name)
  end
end
stop()
stop_other()
before = #seen
vim.cmd.colorscheme("morning")
vim.wait(10)
assert(#seen == before, "unsubscribe did not remove callback")
themes.off_change("missing")
vim.fn.delete(root, "rf")
print(
  "palette: semantic colors, lazy adapters, copies, subscriptions, external overrides, previews, rollback and fallback passed"
)
