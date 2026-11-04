local M = {}
local state = require("theme_tools.state")
local defaults = {
  default = "devicons",
  persist = true,
  state_file = vim.fn.stdpath("state") .. "/theme-tools/icons.json",
  install = { root = vim.fn.stdpath("data") .. "/theme-tools/icons", timeout = 30000 },
  providers = { "mini", "devicons", "ascii", "none" },
  mini = {},
  devicons = {},
  overrides = {},
  sources = {},
  picker = { backend = "builtin", width = 0.98, height = 0.96, preview_height = 0.6, border = "rounded" },
}
local config = vim.deepcopy(defaults)
local selected = defaults.default
local loaded, failures, subscribers = {}, {}, {}
local labels = {
  mini = "mini.icons        󰢱 init.lua   󰉋 src",
  devicons = "nvim-web-devicons  init.lua    src",
  ascii = "ASCII            f init.lua   d src",
  none = "none (hidden)      init.lua     src",
}

local function warn(message)
  vim.notify("Icons: " .. tostring(message), vim.log.levels.WARN, { title = "theme-tools" })
end

local function descriptor()
  return {
    name = selected,
    enabled = selected ~= "none",
    style = selected == "none" and "none" or selected == "ascii" and "ascii" or "glyph",
  }
end

local function call(callback)
  local ok, err = pcall(callback, descriptor())
  if not ok then
    warn(err)
  end
end

local function publish()
  local callbacks = vim.tbl_extend("force", {}, subscribers)
  local ids = vim.tbl_keys(callbacks)
  table.sort(ids)
  for _, id in ipairs(ids) do
    if subscribers[id] == callbacks[id] then
      call(callbacks[id].callback)
    end
  end
  vim.api.nvim_exec_autocmds("User", { pattern = "ThemeToolsIconsChanged", modeline = false, data = descriptor() })
  -- Startup restores the theme after icon preferences; do not expose the
  -- editor's default background before that restoration finishes.
  if vim.v.vim_did_enter == 1 then
    vim.cmd.redrawstatus()
  end
end

local function source(name)
  local base = require("theme_tools.icons.providers").sources[name]
  if not base then
    return nil
  end
  return vim.tbl_extend("force", {}, base, config.sources[name] or {})
end

local function revision_file(spec)
  return vim.fs.joinpath(vim.fn.expand(config.install.root), spec.name, "revision.json")
end

local function install(name, update)
  local spec = source(name)
  if not spec then
    return true
  end
  local installer = require("theme_tools.install")
  local saved = state.read(revision_file(spec))
  if saved and #saved == 40 and saved:match("^%x+$") then
    spec.commit = saved
  end
  if update then
    local commit, err = installer.latest(spec, config.install)
    if not commit then
      return nil, err
    end
    spec.commit = commit
  end
  local path, err = installer.ensure(spec, config.install)
  if not path then
    return nil, err
  end
  if update then
    local ok
    ok, err = state.write(revision_file(spec), spec.commit)
    if not ok then
      return nil, err
    end
  end
  return path
end

local function prepare(name)
  if loaded[name] or not source(name) then
    return true
  end
  local path, err = install(name)
  if not path then
    return nil, err
  end
  local ok, provider = pcall(require("theme_tools.icons.providers").load, name, path, config[name])
  if not ok then
    return nil, tostring(provider)
  end
  loaded[name], failures[name] = provider, nil
  return true
end

function M.current()
  return selected
end

function M._preview_options()
  return {
    icons = {
      persist = false,
      install = config.install,
      providers = config.providers,
      mini = config.mini,
      devicons = config.devicons,
      overrides = config.overrides,
      sources = config.sources,
    },
    highlights = vim.api.nvim_get_hl(0, {}),
    background = vim.o.background,
  }
end

function M.list()
  return vim.tbl_map(function(name)
    return { name = name, label = labels[name] }
  end, config.providers)
end

---Always returns icon, highlight group, is_fallback. Hidden icons return "".
function M.get(category, name)
  local catalog = require("theme_tools.icons.catalog")
  assert(vim.tbl_contains(catalog.categories, category), "unknown icon category: " .. tostring(category))
  assert(type(name) == "string", "icon name must be a string")
  if selected == "none" then
    return "", "Normal", false
  end
  local override = (config.overrides[category] or {})[name]
  if override and (selected ~= "ascii" or override.ascii) then
    return selected == "ascii" and override.ascii or override.icon, override.hl or "Normal", false
  end
  local native = vim.tbl_contains({ "file", "extension", "filetype", "directory", "os" }, category)
    or category == "lsp" and selected == "mini"
  if selected ~= "ascii" and native then
    if not failures[selected] then
      local ok, err = prepare(selected)
      if not ok then
        failures[selected] = err
        warn(err)
      end
    end
    if loaded[selected] then
      local ok, icon, hl, fallback = pcall(loaded[selected].get, category, name)
      if ok and icon and not (fallback and (catalog.values[category] or {})[name]) then
        return icon, hl or "Normal", fallback == true
      end
    end
  end
  return catalog.get(category, name, selected == "ascii")
end

---Copied icon inventory for character insertion UIs; uses the managed provider.
function M.catalog()
  if selected == "none" then
    return {}
  end
  local catalog = require("theme_tools.icons.catalog")
  local entries, seen = {}, {}
  local function add(category, name)
    local key = category .. ":" .. name
    if not seen[key] then
      local icon, hl = M.get(category, name)
      entries[#entries + 1] = { category = category, name = name, icon = icon, hl = hl }
      seen[key] = true
    end
  end
  for category, values in pairs(catalog.values) do
    for name in pairs(values) do
      add(category, name)
    end
  end
  if selected ~= "ascii" then
    local ok, err = prepare(selected)
    if ok and loaded[selected] then
      local listed, inventory = pcall(loaded[selected].catalog)
      if listed then
        for _, entry in ipairs(inventory) do
          add(entry.category, entry.name)
        end
      else
        warn(inventory)
      end
    elseif not ok then
      warn(err)
    end
  end
  table.sort(entries, function(a, b)
    return a.category .. ":" .. a.name < b.category .. ":" .. b.name
  end)
  return entries
end

---Subscriptions survive setup; repeated IDs replace the previous subscriber.
function M.on_change(id, callback)
  assert(type(id) == "string" and id ~= "" and type(callback) == "function", "expected subscriber ID and callback")
  local entry = { callback = callback }
  subscribers[id] = entry
  call(callback)
  return function()
    if subscribers[id] == entry then
      subscribers[id] = nil
    end
  end
end

function M.off_change(id)
  subscribers[id] = nil
end

function M.close()
  local picker = package.loaded["theme_tools.icons.picker"]
  if picker then
    picker.close()
  end
end

function M.set(name)
  if not vim.tbl_contains(config.providers, name) then
    return nil, "Unknown icon provider: " .. tostring(name)
  end
  local ok, err = prepare(name)
  if not ok then
    return nil, err
  end
  M.close()
  selected = name
  if config.persist then
    ok, err = state.write(config.state_file, name)
    if not ok then
      warn("Provider applied, but saving failed: " .. err)
    end
  end
  publish()
  return true
end

local function cycle(step)
  local index = 1
  for i, name in ipairs(config.providers) do
    if name == selected then
      index = i
      break
    end
  end
  return M.set(config.providers[(index - 1 + step) % #config.providers + 1])
end

function M.next()
  return cycle(1)
end
function M.prev()
  return cycle(-1)
end

function M.pick()
  require("theme_tools").close()
  return require("theme_tools.icons.picker").open(M.list(), selected, config.picker, prepare, M.set)
end

local function manage(name, update)
  if name and not vim.tbl_contains(config.providers, name) then
    return nil, "Unknown icon provider: " .. tostring(name)
  end
  for _, value in ipairs(name and { name } or config.providers) do
    local path, err = install(value, update)
    if not path then
      return nil, err
    end
    failures[value] = nil
  end
  return true
end

function M.install(name)
  return manage(name, false)
end
function M.update(name)
  return manage(name, true)
end

function M.commands()
  local function run(callback)
    local ok, err = callback()
    if not ok and err then
      warn(err)
    end
  end
  local function complete(prefix)
    return vim.tbl_filter(function(name)
      return name:sub(1, #prefix) == prefix
    end, config.providers)
  end
  vim.api.nvim_create_user_command("ThemeToolsIcons", function(args)
    run(function()
      if args.args == "" then
        return M.pick()
      end
      return M.set(args.args)
    end)
  end, { nargs = "?", complete = complete, desc = "Choose icon display/provider" })
  for command, callback in pairs({ ThemeToolsIconsNext = M.next, ThemeToolsIconsPrev = M.prev }) do
    vim.api.nvim_create_user_command(command, function()
      run(callback)
    end, { desc = "Cycle icon providers" })
  end
  for command, callback in pairs({ ThemeToolsIconsInstall = M.install, ThemeToolsIconsUpdate = M.update }) do
    vim.api.nvim_create_user_command(command, function(args)
      run(function()
        return callback(args.args ~= "" and args.args or nil)
      end)
    end, { nargs = "?", complete = complete, desc = "Manage icon plugins (loaded updates activate after restart)" })
  end
end

function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == "table", "icons must be a table")
  local new = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts)
  assert(type(new.persist) == "boolean", "icons.persist must be boolean")
  assert(type(new.state_file) == "string" and new.state_file ~= "", "icons.state_file must be nonempty")
  assert(type(new.install.root) == "string" and new.install.root ~= "", "icons.install.root must be nonempty")
  assert(type(new.install.timeout) == "number" and new.install.timeout > 0, "icons.install.timeout must be positive")
  assert(vim.islist(new.providers) and #new.providers > 0, "icons.providers must be a nonempty list")
  local seen = {}
  for _, name in ipairs(new.providers) do
    assert(labels[name] and not seen[name], "invalid or duplicate icon provider")
    seen[name] = true
  end
  assert(seen[new.default], "icons.default must be in icons.providers")
  assert(type(new.mini) == "table" and type(new.devicons) == "table", "icon provider options must be tables")
  assert(vim.tbl_contains({ "builtin", "selection_tools" }, new.picker.backend), "invalid icons.picker.backend")
  for _, dimension in ipairs({ "width", "height" }) do
    assert(type(new.picker[dimension]) == "number" and new.picker[dimension] > 0, "invalid icons.picker." .. dimension)
  end
  assert(
    type(new.picker.preview_height) == "number" and new.picker.preview_height > 0,
    "invalid icons.picker.preview_height"
  )
  assert(type(new.overrides) == "table" and type(new.sources) == "table", "invalid icon overrides/sources")
  local catalog = require("theme_tools.icons.catalog")
  for category, values in pairs(new.overrides) do
    assert(vim.tbl_contains(catalog.categories, category) and type(values) == "table", "invalid icon override category")
    for name, value in pairs(values) do
      assert(
        type(name) == "string" and type(value) == "table" and type(value.icon) == "string",
        "invalid icon override"
      )
      assert(value.hl == nil or type(value.hl) == "string", "invalid icon override highlight")
      assert(
        value.ascii == nil or type(value.ascii) == "string" and not value.ascii:find("[^ -~]"),
        "invalid ASCII override"
      )
    end
  end
  for name, spec in pairs(new.sources) do
    assert((name == "mini" or name == "devicons") and type(spec) == "table", "invalid icon source")
    -- Keep directory and entrypoint ownership internal.
    for key, value in pairs(spec) do
      assert(
        vim.tbl_contains({ "url", "commit", "ref" }, key) and type(value) == "string" and value ~= "",
        "invalid icon source option"
      )
    end
    assert(spec.commit == nil or #spec.commit == 40 and spec.commit:match("^%x+$"), "icon source requires full SHA")
  end
  M.close()
  config = new
  -- Keep live module references until restart; apply changed provider options.
  for name in pairs(loaded) do
    loaded[name] = nil
  end
  failures = {}
  selected = config.default
  if config.persist then
    local saved, err = state.read(config.state_file)
    if err then
      warn(err)
    end
    if seen[saved] then
      selected = saved
    end
  end
  M.commands()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("theme_tools_icons", { clear = true }),
    callback = function()
      for _, provider in pairs(loaded) do
        local ok, err = pcall(provider.refresh)
        if not ok then
          warn(err)
        end
      end
      publish()
    end,
  })
  publish()
end

return M
