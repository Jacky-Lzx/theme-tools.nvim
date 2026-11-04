local M = {}
local subscribers, current, options = {}, nil, {}
local depth, generation, pending = 0, 0, false
local initialized = false

local function warn(message)
  vim.schedule(function()
    vim.notify("Palette: " .. tostring(message), vim.log.levels.WARN, { title = "theme-tools" })
  end)
end

local function validate(value, reference, path)
  for key, expected in pairs(reference) do
    local actual = value[key]
    local name = path .. "." .. key
    if type(expected) == "table" then
      assert(type(actual) == "table", name .. " must be a table")
      validate(actual, expected, name)
    elseif type(expected) == "string" and path ~= "palette" then
      assert(
        type(actual) == "string"
          and (actual:match("^#%x%x%x%x%x%x$") or actual == "NONE" and path == "palette.ui" and key:match("bg$")),
        name .. " must be #rrggbb (or NONE for a background)"
      )
    else
      assert(type(actual) == type(expected), name .. " has an invalid type")
    end
  end
end

local function resolve()
  local name = vim.g.colors_name or "default"
  local ok, value = pcall(require("theme_tools.palettes").resolve)
  if not ok then
    warn(value)
    value = require("theme_tools.palettes.fallback").resolve()
  end
  for _, override in ipairs({ options.overrides or {}, (options.themes or {})[name] or {} }) do
    local ok, result = pcall(function()
      local changes = type(override) == "function" and override(vim.deepcopy(value)) or override
      assert(type(changes) == "table", "override must return a table")
      local merged = vim.tbl_deep_extend("force", vim.deepcopy(value), changes)
      merged.transparent = merged.ui and merged.ui.bg == "NONE"
      validate(merged, value, "palette")
      assert(merged.name == value.name and merged.background == value.background, "theme metadata is read-only")
      assert(merged.transparent == (merged.ui.bg == "NONE"), "transparent must match ui.bg")
      return merged
    end)
    if ok then
      value = result
    else
      warn(result)
    end
  end
  return value
end

local function call(id, callback)
  local ok, err = pcall(callback, vim.deepcopy(current))
  if not ok then
    warn(id .. ": " .. tostring(err))
  end
end

function M.refresh()
  generation = generation + 1
  pending = false
  local needed = current ~= nil or next(subscribers) ~= nil
  current = nil
  if depth > 0 or not needed then
    return
  end
  current = resolve()
  -- Stable order, and a copy per callback: one plugin cannot change another's colors.
  local callbacks = vim.tbl_extend("force", {}, subscribers)
  local ids = vim.tbl_keys(callbacks)
  table.sort(ids)
  for _, id in ipairs(ids) do
    if subscribers[id] == callbacks[id] then
      call(id, callbacks[id].callback)
    end
  end
end

local function initialize()
  if initialized then
    return
  end
  initialized = true
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("theme_tools_palette", { clear = true }),
    callback = function()
      if depth > 0 or pending then
        return
      end
      pending = true
      local ticket = generation
      -- External :colorscheme must finish every user's ColorScheme override first.
      vim.schedule(function()
        if pending and ticket == generation then
          M.refresh()
        end
      end)
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == "table", "palette must be a table")
  assert(
    opts.overrides == nil or type(opts.overrides) == "table" or type(opts.overrides) == "function",
    "invalid palette.overrides"
  )
  assert(opts.themes == nil or type(opts.themes) == "table", "palette.themes must be a table")
  for _, override in pairs(opts.themes or {}) do
    assert(type(override) == "table" or type(override) == "function", "invalid theme palette override")
  end
  options = vim.deepcopy(opts)
  initialize()
end

function M.get()
  initialize()
  -- A direct :colorscheme may have completed but its notification is still queued.
  if not current or pending and depth == 0 then
    current = resolve()
  end
  return vim.deepcopy(current)
end

function M.on_change(id, callback)
  assert(type(id) == "string" and id ~= "", "subscriber ID must be nonempty")
  assert(type(callback) == "function", "subscriber callback must be a function")
  initialize()
  local entry = { callback = callback }
  subscribers[id] = entry
  if depth == 0 then
    current = (not current or pending) and resolve() or current
    call(id, callback)
  end
  return function()
    -- A stale cleanup closure must not remove a newer registration with the same ID.
    if subscribers[id] == entry then
      subscribers[id] = nil
    end
  end
end

function M.off_change(id)
  subscribers[id] = nil
end

-- Theme application/restoration publishes only after all highlights are final.
function M.begin()
  initialize()
  depth = depth + 1
  generation = generation + 1
  pending = false
end

function M.finish()
  depth = depth - 1
  assert(depth >= 0, "unbalanced palette transaction")
  if depth == 0 then
    M.refresh()
  end
end

return M
