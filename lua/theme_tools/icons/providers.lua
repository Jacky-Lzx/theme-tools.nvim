local M = {}

M.sources = {
  mini = {
    name = "mini-icons",
    url = "https://github.com/nvim-mini/mini.icons.git",
    commit = "eab3e692d796d78ea6ffc978d8a380ff26fcf4e3",
    ref = "refs/heads/main",
    entrypoint = "lua/mini/icons.lua",
  },
  devicons = {
    name = "nvim-web-devicons",
    url = "https://github.com/nvim-tree/nvim-web-devicons.git",
    commit = "ec309a0eaff6ea967e58c275996155ab5c16938d",
    ref = "refs/heads/master",
    entrypoint = "lua/nvim-web-devicons.lua",
  },
}

function M.load(name, path, opts)
  -- Prefer managed files for new loads; keep existing module references valid.
  vim.opt.runtimepath:remove(path)
  vim.opt.runtimepath:prepend(path)
  local module = name == "mini" and "mini.icons" or "nvim-web-devicons"
  local provider = package.loaded[module]
  if not provider then
    provider = assert(loadfile(path .. "/" .. M.sources[name].entrypoint))()
    package.loaded[module] = provider
  end
  provider.setup(opts)
  if name == "mini" then
    return {
      get = function(category, value)
        if vim.tbl_contains({ "file", "extension", "filetype", "directory", "os", "lsp" }, category) then
          return provider.get(category, value)
        end
      end,
      refresh = function()
        provider.setup(opts)
      end,
      catalog = function()
        local entries = {}
        for _, category in ipairs({ "file", "extension", "filetype", "directory", "os", "lsp" }) do
          for _, value in ipairs(provider.list(category)) do
            local icon, hl = provider.get(category, value)
            entries[#entries + 1] = { category = category, name = value, icon = icon, hl = hl }
          end
        end
        return entries
      end,
    }
  end
  return {
    get = function(category, value)
      if category == "file" then
        return provider.get_icon(
          vim.fs.basename(value),
          vim.fn.fnamemodify(value, ":e"),
          { default = false, strict = true }
        )
      elseif category == "extension" then
        return provider.get_icon(nil, value, { default = false, strict = true })
      elseif category == "filetype" then
        return provider.get_icon_by_filetype(value, { default = false })
      elseif category == "os" then
        return provider.get_icon_by_operating_system(value, { default = false })
      end
    end,
    refresh = function()
      provider.refresh()
    end,
    catalog = function()
      local entries = {}
      for category, getter in pairs({
        file = provider.get_icons_by_filename,
        extension = provider.get_icons_by_extension,
        os = provider.get_icons_by_operating_system,
      }) do
        for name, value in pairs(getter()) do
          if type(name) == "string" and type(value) == "table" and type(value.icon) == "string" then
            entries[#entries + 1] = { category = category, name = name, icon = value.icon }
          end
        end
      end
      return entries
    end,
  }
end

return M
