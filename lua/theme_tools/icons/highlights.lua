-- Resolve semantic icon foregrounds lazily, without initializing a theme manager.
local M = {}
local initialized = false

function M.setup()
  if initialized then
    return
  end
  initialized = true
  require("theme_tools.palette").on_change("theme-tools:git-icons", function(c)
    local api = vim.api
    for suffix, role in pairs({ Add = "add", Change = "change", Delete = "delete" }) do
      local name = "ThemeToolsIconGit" .. suffix
      local target = "ThemeToolsDefaultIconGit" .. suffix
      api.nvim_set_hl(0, target, { fg = c.git[role] })
      local empty = vim.tbl_isempty(api.nvim_get_hl(0, { name = name, create = false }))
      api.nvim_set_hl(0, name, { link = target, default = not empty })
    end
  end)
end

return M
