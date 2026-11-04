return function()
  local c = require("theme_tools.mocha.palette")
  return {
    bg = c.base,
    fg = c.text,
    red = c.red,
    orange = c.peach,
    yellow = c.yellow,
    green = c.green,
    cyan = c.teal,
    blue = c.blue,
    purple = c.mauve,
    pink = c.pink,
  }
end
