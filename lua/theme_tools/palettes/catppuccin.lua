return function()
  -- Never initialize another provider just to read its palette.
  if not package.loaded.catppuccin then
    return
  end
  local c = require("catppuccin.palettes").get_palette()
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
