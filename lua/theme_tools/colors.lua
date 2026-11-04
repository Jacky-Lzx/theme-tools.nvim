local M = {}

function M.snapshot()
  local terminal = {}
  for i = 0, 15 do
    terminal[i] = vim.g["terminal_color_" .. i]
  end
  terminal.background = vim.g.terminal_color_background
  terminal.foreground = vim.g.terminal_color_foreground
  return {
    name = vim.g.colors_name,
    background = vim.o.background,
    highlights = vim.api.nvim_get_hl(0, {}),
    terminal = terminal,
  }
end

local function restore(snapshot)
  -- Reload first so ColorScheme integrations return to the original theme.
  -- Changing background can automatically reload g:colors_name. A failed theme
  -- may have left that global pointing at itself.
  vim.g.colors_name = nil
  vim.o.background = snapshot.background
  if snapshot.name then
    pcall(vim.cmd.colorscheme, snapshot.name)
  else
    vim.cmd("highlight clear")
  end
  vim.g.colors_name = nil
  vim.o.background = snapshot.background
  for name in pairs(vim.api.nvim_get_hl(0, {})) do
    if not snapshot.highlights[name] then
      vim.api.nvim_set_hl(0, name, {})
    end
  end
  for name, value in pairs(snapshot.highlights) do
    vim.api.nvim_set_hl(0, name, value)
  end
  vim.g.colors_name = snapshot.name
  for i = 0, 15 do
    vim.g["terminal_color_" .. i] = snapshot.terminal[i]
  end
  vim.g.terminal_color_background = snapshot.terminal.background
  vim.g.terminal_color_foreground = snapshot.terminal.foreground
end

function M.restore(snapshot)
  local palette = require("theme_tools.palette")
  palette.begin()
  local ok, err = pcall(restore, snapshot)
  palette.finish()
  if not ok then
    error(err, 0)
  end
end

function M.apply(theme)
  local snapshot = M.snapshot()
  local palette = require("theme_tools.palette")
  palette.begin()
  local ok, err = pcall(function()
    if theme.before then
      theme.before(theme)
    end
    if theme.background and theme.background ~= vim.o.background then
      -- Avoid reloading the previous scheme when changing light/dark modes.
      vim.g.colors_name = nil
      vim.o.background = theme.background
    end
    vim.g.terminal_color_background = nil
    vim.g.terminal_color_foreground = nil
    vim.cmd.colorscheme(theme.colorscheme)
    require("theme_tools.transparency").apply(theme.transparent)
  end)
  if not ok then
    M.restore(snapshot)
    palette.finish()
    return nil, tostring(err)
  end
  palette.finish()
  return true
end

return M
