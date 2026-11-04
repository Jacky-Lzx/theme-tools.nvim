local M = {}

function M.resolve()
  local name = vim.g.colors_name or "default"
  local adapter = name == "theme-tools-mocha" and "mocha"
    or name:match("^catppuccin") and "catppuccin"
    or name:match("^dracula") and "dracula"
  local base
  if adapter then
    base = require("theme_tools.palettes." .. adapter)()
  end
  return require("theme_tools.palettes.fallback").resolve(base)
end

return M
