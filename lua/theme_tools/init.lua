local M = {}
local colors = require("theme_tools.colors")
local state = require("theme_tools.state")
local defaults = {
  discover = true,
  persist = true,
  state_file = vim.fn.stdpath("state") .. "/theme-tools/selection.json",
  catppuccin = {},
  install = { root = vim.fn.stdpath("data") .. "/theme-tools/themes", timeout = 30000 },
  picker = { backend = "builtin", width = 52, height = 12, border = "rounded" },
}
local config = vim.deepcopy(defaults)
local registered = {}
local selected

local function notify(err)
  vim.notify(tostring(err), vim.log.levels.WARN, { title = "theme-tools" })
end

function M.install()
  if config.catppuccin == false then
    return true
  end
  local path, err = require("theme_tools.providers.catppuccin").load(config.install, config.catppuccin)
  if not path then
    return nil, err
  end
  return true
end

local function normalize(theme)
  if type(theme) == "string" then
    theme = { name = theme, colorscheme = theme }
  end
  assert(type(theme) == "table", "theme must be a string or table")
  theme = vim.deepcopy(theme)
  theme.name = theme.name or theme.colorscheme
  theme.colorscheme = theme.colorscheme or theme.name
  assert(type(theme.name) == "string" and theme.name:match("^%S+$"), "theme name must be nonempty without whitespace")
  assert(type(theme.colorscheme) == "string" and theme.colorscheme ~= "", "colorscheme must be nonempty")
  assert(theme.label == nil or type(theme.label) == "string", "label must be a string")
  assert(theme.background == nil or theme.background == "light" or theme.background == "dark", "invalid background")
  assert(theme.before == nil or type(theme.before) == "function", "before must be a function")
  return theme
end

function M.register(theme)
  theme = normalize(theme)
  for i, item in ipairs(registered) do
    if item.name == theme.name then
      registered[i] = theme
      return
    end
  end
  registered[#registered + 1] = theme
end

function M.list()
  local themes, seen = vim.deepcopy(registered), {}
  for _, theme in ipairs(themes) do
    seen[theme.name] = true
  end
  if config.discover then
    local names = vim.fn.getcompletion("", "color")
    table.sort(names)
    for _, name in ipairs(names) do
      if not seen[name] then
        themes[#themes + 1] = normalize(name)
        seen[name] = true
      end
    end
  end
  return themes
end

function M.current()
  local matches = {}
  for _, theme in ipairs(M.list()) do
    -- Some colorscheme entry points load a differently named variant (for
    -- example catppuccin-nvim loads catppuccin-mocha).
    if
      selected
      and theme.name == selected.name
      and theme.colorscheme == selected.colorscheme
      and vim.g.colors_name == selected.applied
      and vim.o.background == selected.background
    then
      return theme.name
    end
    if theme.colorscheme == vim.g.colors_name and (not theme.background or theme.background == vim.o.background) then
      matches[#matches + 1] = theme.name
    end
  end
  return matches[1]
end

local function commit(theme)
  selected = {
    name = theme.name,
    colorscheme = theme.colorscheme,
    applied = vim.g.colors_name,
    background = vim.o.background,
  }
  if config.persist then
    local ok, err = state.write(config.state_file, theme.name)
    if not ok then
      notify("Theme applied, but saving failed: " .. err)
    end
  end
  vim.api.nvim_exec_autocmds("User", {
    pattern = "ThemeToolsChanged",
    modeline = false,
    data = { name = theme.name, colorscheme = theme.colorscheme, background = vim.o.background },
  })
end

function M.close()
  local builtin = package.loaded["theme_tools.picker"]
  if builtin then
    builtin.close()
  end
  local selection = package.loaded["theme_tools.integrations.selection"]
  if selection then
    selection.close()
  end
end

function M.set(name)
  M.close()
  for _, theme in ipairs(M.list()) do
    if theme.name == name then
      local ok, err = colors.apply(theme)
      if not ok then
        return nil, err
      end
      commit(theme)
      return true
    end
  end
  return nil, "Unknown theme: " .. tostring(name)
end

function M.pick()
  M.close()
  local picker = config.picker.backend == "selection_tools" and "theme_tools.integrations.selection"
    or "theme_tools.picker"
  return require(picker).open(M.list(), M.current(), config.picker, commit)
end

local function cycle(step)
  M.close()
  local themes, current = M.list(), M.current()
  if #themes == 0 then
    return nil, "No themes available"
  end
  local index = step == 1 and 0 or 1
  for i, theme in ipairs(themes) do
    if theme.name == current then
      index = i
      break
    end
  end
  return M.set(themes[(index - 1 + step) % #themes + 1].name)
end

function M.next()
  return cycle(1)
end

function M.prev()
  return cycle(-1)
end

function M.commands()
  local function run(callback)
    local ok, err = callback()
    if not ok and err then
      notify(err)
    end
  end
  vim.api.nvim_create_user_command("ThemeTools", function(args)
    if args.args == "" then
      run(M.pick)
    else
      run(function()
        return M.set(args.args)
      end)
    end
  end, {
    nargs = "?",
    desc = "Preview or apply a colorscheme",
    complete = function(prefix)
      return vim.tbl_filter(
        function(name)
          return name:sub(1, #prefix) == prefix
        end,
        vim.tbl_map(function(theme)
          return theme.name
        end, M.list())
      )
    end,
  })
  for command, callback in pairs({ ThemeToolsNext = M.next, ThemeToolsPrev = M.prev }) do
    vim.api.nvim_create_user_command(command, function()
      run(callback)
    end, { desc = "Cycle colorschemes" })
  end
  vim.api.nvim_create_user_command("ThemeToolsInstall", function()
    run(M.install)
  end, { desc = "Download and load configured themes" })
end

function M.setup(opts)
  opts = opts or {}
  local new = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  if opts.themes and opts.discover == nil then
    new.discover = false
  end
  assert(type(new.discover) == "boolean" and type(new.persist) == "boolean", "discover/persist must be booleans")
  assert(type(new.state_file) == "string" and new.state_file ~= "", "state_file must be nonempty")
  assert(type(new.picker.width) == "number" and new.picker.width >= 1, "picker.width must be positive")
  assert(type(new.picker.height) == "number" and new.picker.height >= 1, "picker.height must be positive")
  assert(vim.tbl_contains({ "builtin", "selection_tools" }, new.picker.backend), "invalid picker.backend")
  assert(type(new.catppuccin) == "table" or new.catppuccin == false, "catppuccin must be an options table or false")
  assert(type(new.install.root) == "string" and new.install.root ~= "", "install.root must be nonempty")
  assert(type(new.install.timeout) == "number" and new.install.timeout > 0, "install.timeout must be positive")
  assert(opts.themes == nil or vim.islist(opts.themes), "themes must be a list")
  local themes = vim.tbl_map(normalize, opts.themes or {})
  M.close()
  config, registered, selected = new, {}, nil
  for _, theme in ipairs(themes) do
    M.register(theme)
  end
  M.commands()
  local installed, install_error = M.install()
  if not installed then
    notify(install_error)
  end
  local name, err
  if config.persist then
    name, err = state.read(config.state_file)
    if err then
      notify(err)
    end
  end
  -- Only registered/discovered IDs from data files can be restored.
  local found = false
  for _, theme in ipairs(M.list()) do
    found = found or theme.name == name
  end
  name = found and name or opts.default
  if name then
    local ok
    ok, err = M.set(name)
    if not ok then
      notify(err)
    end
  end
end

return M
