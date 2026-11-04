-- Derived from Mofiqul/dracula.nvim (MIT); see LICENSE.dracula.
-- Resolve lualine auto without loading the managed Dracula provider.
local c = require("theme_tools.dracula.palette")
local bg = "NONE"

local normal = {
  a = { fg = c.black, bg = c.purple, gui = "bold" },
  b = { fg = c.purple, bg = bg },
  c = { fg = c.white, bg = bg },
}

local command = {
  a = { fg = c.black, bg = c.cyan, gui = "bold" },
  b = { fg = c.cyan, bg = bg },
}

local visual = {
  a = { fg = c.black, bg = c.pink, gui = "bold" },
  b = { fg = c.pink, bg = bg },
}

local inactive = {
  a = { fg = c.white, bg = c.visual, gui = "bold" },
  b = { fg = c.black, bg = c.white },
}

local replace = {
  a = { fg = c.black, bg = c.yellow, gui = "bold" },
  b = { fg = c.yellow, bg = bg },
  c = { fg = c.white, bg = bg },
}

local insert = {
  a = { fg = c.black, bg = c.green, gui = "bold" },
  b = { fg = c.green, bg = bg },
  c = { fg = c.white, bg = bg },
}

return {
  normal = normal,
  command = command,
  visual = visual,
  inactive = inactive,
  replace = replace,
  insert = insert,
}
