local M = {}
local colors = require("theme_tools.colors")
local state = require("theme_tools.state")
local defaults = {
  discover = true,
  persist = true,
  state_file = vim.fn.stdpath("state") .. "/theme-tools/selection.json",
  catppuccin = {},
  dracula = {},
  palette = {},
  install = { root = vim.fn.stdpath("data") .. "/theme-tools/themes", timeout = 30000 },
  picker = {
    backend = "builtin",
    width = 52,
    height = 12,
    border = "rounded",
    group_by_background = true,
    preview_mode = "window",
  },
}
local config = vim.deepcopy(defaults)
local registered = {}
local selected
local managed_ready = {}
local sources = {
  catppuccin = { "catppuccin", "catppuccin-*" },
  dracula = { "dracula", "dracula-soft" },
}
local backgrounds = {
  ["theme-tools-mocha"] = "dark",
  dracula = "dark",
  ["dracula-soft"] = "dark",
  ["catppuccin-latte"] = "light",
  ["catppuccin-frappe"] = "dark",
  ["catppuccin-macchiato"] = "dark",
  ["catppuccin-mocha"] = "dark",
}

local function notify(err)
  vim.notify(tostring(err), vim.log.levels.WARN, { title = "theme-tools" })
end

---Return a copied semantic palette for the current applied colorscheme.
function M.palette()
  return require("theme_tools.palette").get()
end

---Subscribe by stable ID; runs immediately and returns an unsubscribe function.
function M.on_change(id, callback)
  return require("theme_tools.palette").on_change(id, callback)
end

function M.off_change(id)
  require("theme_tools.palette").off_change(id)
end

---Re-read manually changed highlights and notify palette subscribers.
function M.refresh_palette()
  require("theme_tools.palette").refresh()
end

function M.install(source)
  assert(source == nil or sources[source], "unknown theme source")
  for _, name in ipairs(source and { source } or { "catppuccin", "dracula" }) do
    if config[name] ~= false then
      local path, err = require("theme_tools.providers." .. name).load(config.install, config[name])
      if not path then
        return nil, err
      end
      managed_ready[name] = true
    end
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
  -- Catppuccin remembers its last flavour. After another scheme changes
  -- 'background', its loader can interpret a repeated flavour as a mode toggle.
  theme.background = theme.background or backgrounds[theme.colorscheme]
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

-- Private worker configuration, read only when the theme picker needs a preview.
function M._preview_options()
  local lazy = package.loaded["lazy.core.config"]
  local plugins
  if lazy then
    plugins = {}
    for name in pairs(lazy.plugins or {}) do
      plugins[name] = {}
    end
  end
  return {
    catppuccin = config.catppuccin,
    dracula = config.dracula,
    palette = config.palette,
    install = config.install,
    after = config.picker.preview_after,
    plugins = plugins,
    background = vim.o.background,
  }
end

function M.close()
  local groups = package.loaded["theme_tools.groups"]
  if groups then
    groups.close()
  end
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
  if config.picker.group_by_background then
    return require("theme_tools.groups").open(M.list(), M.current(), config.picker, commit, require(picker))
  end
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
  assert(type(new.picker.group_by_background) == "boolean", "picker.group_by_background must be boolean")
  assert(vim.tbl_contains({ "window", "live" }, new.picker.preview_mode), "invalid picker.preview_mode")
  assert(
    new.picker.preview_after == nil or type(new.picker.preview_after) == "function",
    "preview_after must be a function"
  )
  assert(type(new.catppuccin) == "table" or new.catppuccin == false, "catppuccin must be an options table or false")
  assert(type(new.dracula) == "table" or new.dracula == false, "dracula must be an options table or false")
  assert(type(new.install.root) == "string" and new.install.root ~= "", "install.root must be nonempty")
  assert(type(new.install.timeout) == "number" and new.install.timeout > 0, "install.timeout must be positive")
  assert(opts.themes == nil or vim.islist(opts.themes), "themes must be a list")
  local themes = vim.tbl_map(normalize, opts.themes or {})
  M.close()
  require("theme_tools.palette").setup(new.palette)
  config, registered, selected = new, {}, nil
  managed_ready = {}
  for _, theme in ipairs(themes) do
    M.register(theme)
  end
  M.commands()
  local group = vim.api.nvim_create_augroup("theme_tools_sources", { clear = true })
  for name, patterns in pairs(sources) do
    if config[name] ~= false then
      -- ColorSchemePre runs before runtimepath lookup, including direct :colorscheme
      -- calls and picker previews. Independent themes never initialize this source.
      vim.api.nvim_create_autocmd("ColorSchemePre", {
        group = group,
        pattern = patterns,
        callback = function()
          if not managed_ready[name] then
            local ok, err = M.install(name)
            if not ok then
              error(err, 0)
            end
          end
        end,
      })
    end
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
  else
    require("theme_tools.palette").refresh()
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "ThemeToolsReady", modeline = false })
end

return M
