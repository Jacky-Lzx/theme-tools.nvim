local M = {}

-- Managed icon sources are deliberately absent from package-manager inventories.
-- Include them without loading/downloading the provider or unrelated minis.
function M.with_managed_icons(catppuccin, opts)
  local auto = opts.auto_integrations
  if auto == nil then
    auto = catppuccin.default_options and catppuccin.default_options.auto_integrations
  end
  local icons = package.loaded["theme_tools.icons"]
  if
    not auto
    or type(icons) ~= "table"
    or type(icons.list) ~= "function"
    or opts.integrations ~= nil and type(opts.integrations) ~= "table"
  then
    return opts
  end
  for _, provider in ipairs(icons.list()) do
    if provider.name == "mini" then
      local resolved = vim.deepcopy(opts)
      resolved.integrations = resolved.integrations or {}
      local mini = resolved.integrations.mini
      if mini == nil then
        resolved.integrations.mini = { enabled = true }
      elseif type(mini) == "table" and mini.enabled == nil then
        mini.enabled = true
      end
      return resolved
    end
  end
  return opts
end

-- Lazy has already resolved its plugin inventory. Avoid loading other package
-- managers merely to discover that they are absent. Unrecognized environments
-- retain Catppuccin's normal detector.
function M.resolve(catppuccin, opts)
  local defaults = catppuccin.default_options
  if type(defaults) ~= "table" then
    return opts
  end
  local auto = opts.auto_integrations
  if auto == nil then
    auto = defaults.auto_integrations
  end
  if not auto or type(defaults.integrations) ~= "table" then
    return opts
  end
  if opts.integrations ~= nil and type(opts.integrations) ~= "table" then
    return opts
  end
  local lazy, loader = package.loaded["lazy.core.config"], package.loaded["vim.loader"]
  if
    type(lazy) ~= "table"
    or type(lazy.plugins) ~= "table"
    or type(loader) ~= "table"
    or not loader.enabled
    or type(loader.find) ~= "function"
    or type(package.searchpath) ~= "function"
  then
    return opts
  end
  if
    package.loaded.pckr
    or package.loaded["pckr.plugin"]
    or package.preload.pckr
    or lazy.plugins["pckr.nvim"]
    or lazy.plugins.pckr
    or #loader.find("pckr") > 0
    or package.searchpath("pckr", package.path)
    or package.searchpath("pckr", package.cpath)
  then
    return opts
  end
  local names = vim.tbl_keys(lazy.plugins)
  if vim.fn.has("nvim-0.12.0") == 1 then
    local ok, plugins = pcall(vim.pack.get, nil, { info = false })
    if not ok then
      return opts
    end
    for _, plugin in ipairs(plugins) do
      if plugin.spec.name == "pckr.nvim" or plugin.spec.name == "pckr" then
        return opts
      end
      names[#names + 1] = plugin.spec.name
    end
  end
  local mappings = require("catppuccin.utils.integration_mappings")
  -- Match upstream: combine user settings and defaults first, then let that
  -- table override detected entries, including false and nested settings.
  local resolved = vim.deepcopy(opts)
  local merged = vim.tbl_deep_extend("keep", resolved.integrations or {}, defaults.integrations)
  local detected = {}
  for _, name in ipairs(names) do
    name = name:sub(1, 5) == "mini." and "mini.nvim" or name
    local integration = mappings[name]
    if integration and not detected[integration] then
      if type(defaults.integrations[integration]) == "table" then
        detected[integration] = vim.deepcopy(defaults.integrations[integration])
        detected[integration].enabled = true
      else
        detected[integration] = true
      end
    end
  end
  resolved.integrations = vim.tbl_deep_extend("force", detected, merged)
  resolved.auto_integrations = false
  return resolved
end

return M
