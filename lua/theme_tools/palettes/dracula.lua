return function()
  local provider = package.loaded.dracula
  if not provider then
    return
  end
  local c = provider.colors()
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
