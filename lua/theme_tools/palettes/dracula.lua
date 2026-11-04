return function()
  local c
  if vim.g.colors_name == "theme-tools-dracula" then
    c = require("theme_tools.dracula.palette")
  else
    local provider = package.loaded.dracula
    if not provider then
      return
    end
    c = provider.colors()
  end
  return {
    bg = c.bg,
    fg = c.fg,
    red = c.red,
    orange = c.orange,
    yellow = c.yellow,
    green = c.green,
    cyan = c.cyan,
    blue = c.cyan,
    purple = c.purple,
    pink = c.pink,
  }
end
