-- Run inside the complete personal configuration with managed Catppuccin installed.
local themes = require("theme_tools")
assert(themes.set("catppuccin-mocha"))
local groups, terminal = require("theme_tools.mocha.build").definitions()
local before = {}
for name in pairs(groups) do
  before[name] = vim.api.nvim_get_hl(0, { name = name })
end
local terms = {}
for key in pairs(terminal) do
  terms[key] = vim.g[key]
end
assert(themes.set("theme-tools-mocha"))
local differences = {}
for name, value in pairs(before) do
  local after = vim.api.nvim_get_hl(0, { name = name })
  if not vim.deep_equal(value, after) then
    differences[name] = { upstream = value, personal = after }
  end
end
assert(vim.tbl_isempty(differences), vim.inspect(differences))
for key, value in pairs(terms) do
  assert(vim.g[key] == value, key)
end
assert(vim.o.background == "dark" and vim.o.termguicolors)
io.stdout:write(
  "independent Mocha matches " .. vim.tbl_count(groups) .. " customized upstream highlights and 16 terminal colors\n"
)
