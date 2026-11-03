local M = {}

M.source = {
  name = "dracula",
  url = "https://github.com/Mofiqul/dracula.nvim.git",
  commit = "ae752c13e95fb7c5f58da4b5123cb804ea7568ee",
  entrypoint = "lua/dracula/init.lua",
}

function M.load(install, opts)
  local path, err = require("theme_tools.install").ensure(M.source, install)
  if not path then
    return nil, err
  end
  if not vim.tbl_contains(vim.opt.runtimepath:get(), path) then
    vim.opt.runtimepath:prepend(path)
  end
  local ok, reason = pcall(function()
    require("dracula").setup(opts)
  end)
  if not ok then
    return nil, tostring(reason)
  end
  return path
end

return M
