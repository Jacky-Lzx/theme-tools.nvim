local M = {}
M.icons = require("theme_tools.icons")
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
    width = 0.98,
    height = 0.96,
    preview_height = 0.6,
    border = "rounded",
    group_by_background = true,
    preview_mode = "window",
    transparency_key = "<C-t>",
  },
}
local config = vim.deepcopy(defaults)
local registered = {}
local selected
local managed_ready = {}
local transparency = {}
local sources = {
  catppuccin = { "catppuccin", "catppuccin-*" },
  dracula = { "dracula", "dracula-soft" },
}
local backgrounds = {
  ["theme-tools-mocha"] = "dark",
  ["theme-tools-dracula"] = "dark",
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

---Read-only diagnostic snapshot; opts.groups optionally selects highlight groups.
function M.info(opts)
  return require("theme_tools.info").snapshot(opts)
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
  assert(theme.transparent == nil or type(theme.transparent) == "boolean", "transparent must be a boolean")
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
  for _, theme in ipairs(themes) do
    if transparency[theme.name] ~= nil then
      theme.transparent = transparency[theme.name]
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
  if config.persist then
    -- Preserve preferences confirmed by another editor since this setup.
    local _, _, latest = state.read(config.state_file)
    transparency = vim.tbl_extend("force", transparency, latest or {})
  end
  if theme.transparent ~= nil then
    transparency[theme.name] = theme.transparent
  end
  selected = {
    name = theme.name,
    colorscheme = theme.colorscheme,
    applied = vim.g.colors_name,
    background = vim.o.background,
  }
  if config.persist then
    local ok, err = state.write(config.state_file, theme.name, transparency)
    if not ok then
      notify("Theme applied, but saving failed: " .. err)
    end
  end
  vim.api.nvim_exec_autocmds("User", {
    pattern = "ThemeToolsChanged",
    modeline = false,
    data = {
      name = theme.name,
      colorscheme = theme.colorscheme,
      background = vim.o.background,
      transparent = require("theme_tools.palettes.fallback").highlight("Normal", "bg") == nil,
    },
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
  local icons = vim.deepcopy(M.icons._preview_options().icons)
  icons.default, icons.persist, icons.install.offline = M.icons.current(), false, true
  return {
    catppuccin = config.catppuccin,
    dracula = config.dracula,
    palette = config.palette,
    install = config.install,
    after = config.picker.preview_after,
    plugins = plugins,
    background = vim.o.background,
    icons = icons,
  }
end

function M.close()
  M.icons.close()
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
  M.icons.commands()
  require("theme_tools.user_command").create("ThemeToolsInfo", function(args)
    require("theme_tools.info").open(args.args ~= "" and { groups = { args.args } } or nil)
  end, {
    nargs = "?",
    complete = "highlight",
    desc = "Inspect theme, icons, semantic colors and highlight links",
  })
  local function run(callback)
    local ok, err = callback()
    if not ok and err then
      notify(err)
    end
  end
  require("theme_tools.user_command").create("ThemeTools", function(args)
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
    require("theme_tools.user_command").create(command, function()
      run(callback)
    end, { desc = "Cycle colorschemes" })
  end
  require("theme_tools.user_command").create("ThemeToolsInstall", function()
    run(M.install)
  end, { desc = "Download and load configured themes" })
end

function M.dispose()
  M.close()
  M.icons.dispose()
  require("theme_tools.palette").dispose()
  pcall(vim.api.nvim_del_augroup_by_name, "theme_tools_sources")
  local commands = require("theme_tools.user_command")
  for _, name in ipairs({
    "ThemeTools",
    "ThemeToolsInfo",
    "ThemeToolsNext",
    "ThemeToolsPrev",
    "ThemeToolsInstall",
    "ThemeToolsIcons",
    "ThemeToolsIconsNext",
    "ThemeToolsIconsPrev",
    "ThemeToolsIconsInstall",
    "ThemeToolsIconsUpdate",
  }) do
    commands.delete(name)
  end
  config = vim.deepcopy(defaults)
end

function M.setup(opts)
  assert(opts == nil or type(opts) == "table", "theme-tools.nvim: setup expects a table")
  opts = vim.deepcopy(opts or {})
  opts = opts or {}
  local new = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  if opts.themes and opts.discover == nil then
    new.discover = false
  end
  assert(type(new.discover) == "boolean" and type(new.persist) == "boolean", "discover/persist must be booleans")
  assert(type(new.state_file) == "string" and new.state_file ~= "", "state_file must be nonempty")
  assert(type(new.picker.width) == "number" and new.picker.width > 0, "picker.width must be positive")
  assert(type(new.picker.height) == "number" and new.picker.height > 0, "picker.height must be positive")
  assert(
    type(new.picker.preview_height) == "number" and new.picker.preview_height > 0,
    "picker.preview_height must be positive"
  )
  assert(vim.tbl_contains({ "builtin", "selection_tools" }, new.picker.backend), "invalid picker.backend")
  assert(type(new.picker.group_by_background) == "boolean", "picker.group_by_background must be boolean")
  assert(vim.tbl_contains({ "window", "live" }, new.picker.preview_mode), "invalid picker.preview_mode")
  assert(
    new.picker.transparency_key == false
      or type(new.picker.transparency_key) == "string" and new.picker.transparency_key ~= "",
    "invalid picker.transparency_key"
  )
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
  require("theme_tools.palette").resolve_options(new.palette)
  local icon_options = M.icons.resolve(vim.tbl_deep_extend("force", {
    persist = new.persist,
    picker = {
      backend = new.picker.backend,
      selection = new.picker.selection,
      width = new.picker.width,
      height = new.picker.height,
      border = new.picker.border,
      preview_height = new.picker.preview_height,
    },
  }, opts.icons or {}))
  M.close()
  require("theme_tools.palette").setup(new.palette)
  config, registered, selected = new, {}, nil
  managed_ready = {}
  transparency = {}
  for _, theme in ipairs(themes) do
    M.register(theme)
  end
  M.commands()
  M.icons.setup(icon_options)
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
    name, err, transparency = state.read(config.state_file)
    transparency = transparency or {}
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
