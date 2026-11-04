-- Run after VeryLazy in the actual personal configuration, before loading Catppuccin.
local themes = require("theme_tools")
local api = vim.api
assert(vim.g.colors_name == "theme-tools-mocha")
assert(package.loaded.lualine and package.loaded["barbar.highlight"], "bar plugins did not load")
assert(not package.loaded.catppuccin, "independent bar colors must not load Catppuccin")

local c = require("theme_tools.mocha.palette")
local function rgb(hex)
  return tonumber(hex:sub(2), 16)
end
for mode, color in pairs({ normal = c.blue, insert = c.green, visual = c.mauve, replace = c.red, command = c.peach }) do
  assert(api.nvim_get_hl(0, { name = "lualine_a_" .. mode, link = false }).bg == rgb(color), mode .. " color missing")
end
assert(api.nvim_get_hl(0, { name = "lualine_c_normal", link = false }).bg == nil, "statusline must stay transparent")
assert(api.nvim_get_hl(0, { name = "BufferCurrent", link = false }).bg == rgb(c.surface1))
assert(api.nvim_get_hl(0, { name = "BufferCurrentSign", link = false }).fg == rgb(c.blue))

local function capture()
  local result = {}
  for name in pairs(api.nvim_get_hl(0, {})) do
    local include = name:match("^Buffer") ~= nil
    for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
      include = include or name:match("^lualine_[abcxyz]_" .. mode .. "$") ~= nil
    end
    if include then
      local value = api.nvim_get_hl(0, { name = name, link = false })
      value.default = nil -- A default-link marker does not affect the rendered color.
      result[name] = value
    end
  end
  return result
end

local startup = capture()
assert(themes.set("catppuccin-mocha"))
local upstream = capture()
for name, value in pairs(startup) do
  assert(vim.deep_equal(value, upstream[name]), "startup bar colors differ from Catppuccin: " .. name)
end
assert(themes.set("theme-tools-mocha"))
local restored = capture()
for name, value in pairs(startup) do
  assert(vim.deep_equal(value, restored[name]), "bar colors lost after switching back: " .. name)
end
assert(themes.set("dracula"))
assert(themes.set("theme-tools-mocha"))
restored = capture()
for name, value in pairs(startup) do
  assert(vim.deep_equal(value, restored[name]), "bar colors lost after Dracula: " .. name)
end
io.stdout:write(
  "configured bars: delayed startup matches Catppuccin; mode colors, transparency, Barbar and theme switching passed\n"
)
