-- Derived from Catppuccin's lualine integration (MIT); see LICENSE.catppuccin.
-- The filename lets lualine's "auto" theme resolve our independent colorscheme.
local c = require("theme_tools.mocha.palette")

return {
  normal = {
    a = { bg = c.blue, fg = c.mantle, gui = "bold" },
    b = { bg = c.surface0, fg = c.blue },
    c = { bg = "NONE", fg = c.text },
  },
  insert = {
    a = { bg = c.green, fg = c.base, gui = "bold" },
    b = { bg = c.surface0, fg = c.green },
  },
  terminal = {
    a = { bg = c.green, fg = c.base, gui = "bold" },
    b = { bg = c.surface0, fg = c.green },
  },
  command = {
    a = { bg = c.peach, fg = c.base, gui = "bold" },
    b = { bg = c.surface0, fg = c.peach },
  },
  visual = {
    a = { bg = c.mauve, fg = c.base, gui = "bold" },
    b = { bg = c.surface0, fg = c.mauve },
  },
  replace = {
    a = { bg = c.red, fg = c.base, gui = "bold" },
    b = { bg = c.surface0, fg = c.red },
  },
  inactive = {
    a = { bg = "NONE", fg = c.blue },
    b = { bg = "NONE", fg = c.surface1, gui = "bold" },
    c = { bg = "NONE", fg = c.overlay0 },
  },
}
