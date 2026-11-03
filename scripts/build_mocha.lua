-- Run from the repository: nvim --headless -u NONE -l scripts/build_mocha.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local output = require("theme_tools.mocha.build").render()
assert(loadstring(output), "generated colorscheme is invalid Lua")
local path = "colors/theme-tools-mocha.lua"
if arg[1] == "--check" then
  local file = assert(io.open(path, "rb"))
  local previous = file:read("*a")
  file:close()
  assert(previous == output, "Mocha is stale; run scripts/build_mocha.lua")
else
  vim.fn.mkdir("colors", "p")
  local file = assert(io.open(path, "wb"))
  file:write(output)
  file:close()
end
