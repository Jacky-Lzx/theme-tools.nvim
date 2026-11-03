local M = {}

M.source = {
  name = "catppuccin",
  url = "https://github.com/catppuccin/nvim.git",
  commit = "edefef779ab08ce1a4a404713e3012b0d202bd35",
  entrypoint = "lua/catppuccin/init.lua",
}

function M.load(install, opts)
  local path, err = require("theme_tools.install").ensure(M.source, install)
  if not path then
    return nil, err
  end
  if not vim.tbl_contains(vim.opt.runtimepath:get(), path) then
    -- Take priority over Neovim's bundled, differently styled catppuccin.vim.
    vim.opt.runtimepath:prepend(path)
    local after = path .. "/after"
    if vim.fn.isdirectory(after) == 1 then
      vim.opt.runtimepath:append(after)
    end
  end
  local ok, reason = pcall(function()
    require("catppuccin").setup(opts)
  end)
  if not ok then
    return nil, tostring(reason)
  end
  return path
end

return M
