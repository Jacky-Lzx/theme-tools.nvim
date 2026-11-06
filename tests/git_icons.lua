vim.opt.rtp:prepend(vim.fn.getcwd())
local api = vim.api
local themes = require("theme_tools")
themes.setup({
  persist = false,
  catppuccin = false,
  dracula = false,
  default = "theme-tools-mocha",
  themes = { "theme-tools-mocha", "theme-tools-dracula", "morning" },
  icons = { default = "ascii" },
})
assert(not package.loaded["theme_tools.icons.highlights"], "unused semantic groups loaded eagerly")
local function check()
  local c = themes.palette()
  for name, color in pairs({
    keymap = "blue",
    format = "cyan",
    diagnostics = "green",
    git = "orange",
    rename = "purple",
    debug = "red",
    toggle_on = "yellow",
  }) do
    local icon, group, fallback = themes.icons.get("ui", name)
    local hl = api.nvim_get_hl(0, { name = group, link = false })
    assert(icon ~= "" and not fallback and hl.fg == tonumber(c.palette[color]:sub(2), 16), name)
    assert(hl.bg == nil, "action icon must not paint a background")
  end
  for name, role in pairs({ added = "add", modified = "change", removed = "delete" }) do
    local icon, group = themes.icons.get("git", name)
    local hl = api.nvim_get_hl(0, { name = group, link = false })
    assert(icon ~= "" and hl.fg == tonumber(c.git[role]:sub(2), 16), name)
    assert(hl.bg == nil and not hl.reverse, "Git icon borrowed a diff surface: " .. name)
  end
end
for _, name in ipairs({ "theme-tools-mocha", "theme-tools-dracula", "morning" }) do
  assert(themes.set(name))
  check()
end
local original = require("theme_tools.colors").snapshot()
assert(themes.set("theme-tools-dracula"))
check()
require("theme_tools.colors").restore(original)
check()
api.nvim_set_hl(0, "ThemeToolsIconBlue", { fg = "#654321" })
api.nvim_set_hl(0, "ThemeToolsIconGitAdd", { fg = "#123456" })
themes.refresh_palette()
assert(api.nvim_get_hl(0, { name = "ThemeToolsIconGitAdd", link = false }).fg == 0x123456)
assert(api.nvim_get_hl(0, { name = "ThemeToolsIconBlue", link = false }).fg == 0x654321)
for name in pairs(require("theme_tools.icons.catalog").values.ui) do
  local icon = themes.icons.get("ui", name)
  assert(not icon:find("[^ -~]"), "ASCII mode returned a glyph: " .. name)
end
assert(themes.icons.set("none"))
assert(themes.icons.get("git", "added") == "" and themes.icons.get("ui", "keymap") == "")
assert(not package.loaded["nvim-web-devicons"] and not package.loaded["mini.icons"])
print("Git icons: lazy semantic foregrounds, no diff backgrounds, light/dark, overrides and rollback passed")
