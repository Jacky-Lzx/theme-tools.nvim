if vim.g.loaded_theme_tools then
  return
end
vim.g.loaded_theme_tools = true
require("theme_tools").commands()
