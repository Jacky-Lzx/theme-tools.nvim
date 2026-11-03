local M = {}

function M.snapshot()
  local terminal = {}
  for i = 0, 15 do
    terminal[i] = vim.g["terminal_color_" .. i]
  end
  return {
    name = vim.g.colors_name,
    background = vim.o.background,
    highlights = vim.api.nvim_get_hl(0, {}),
    terminal = terminal,
  }
end

function M.restore(snapshot)
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
end

function M.apply(theme)
  local snapshot = M.snapshot()
  local ok, err = pcall(function()
    if theme.before then
      theme.before(theme)
    end
    if theme.background then
      vim.o.background = theme.background
    end
    vim.cmd.colorscheme(theme.colorscheme)
  end)
  if not ok then
    M.restore(snapshot)
    return nil, tostring(err)
  end
  return true
end

return M
