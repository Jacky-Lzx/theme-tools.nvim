-- Loaded only when opening the picker, never during startup.
local M = {}
local order = { "dark", "light", "unknown" }
local labels = { dark = "Dark themes", light = "Light themes", unknown = "Unclassified themes" }
local active

function M.close()
  active = nil
end

function M.open(themes, current, opts, confirm, picker)
  local session = {}
  active = session
  local function transition(open)
    -- Let the previous picker's stopinsert finish before entering the next input.
    vim.schedule(function()
      if active ~= session then
        return
      end
      local ok, err = open()
      if not ok then
        vim.notify(err, vim.log.levels.WARN, { title = "theme-tools" })
      end
    end)
  end
  local groups, current_group = { dark = {}, light = {}, unknown = {} }
  for _, theme in ipairs(themes) do
    local group = theme.background or "unknown"
    groups[group][#groups[group] + 1] = theme
    if theme.name == current then
      current_group = group
    end
  end
  local initial = current_group or vim.o.background
  local categories = {}
  for _, name in ipairs(order) do
    if #groups[name] > 0 then
      categories[#categories + 1] = { name = name, label = labels[name], colorscheme = name }
    end
  end
  if #categories == 0 then
    return nil, "No themes available; install a colorscheme or configure themes"
  end
  local open_categories
  local function open_themes(group)
    local options = vim.tbl_extend("force", {}, opts, {
      prompt = labels[group] .. " · Ctrl-G: groups",
      retain_preview = true,
      preview = opts.preview_mode == "window" or group ~= "unknown",
      on_group = function()
        picker.close()
        transition(function()
          return open_categories(group)
        end)
      end,
    })
    if group == "unknown" and opts.preview_mode ~= "window" then
      options.prompt = "Unclassified · Enter: apply · Ctrl-G: groups"
    end
    return picker.open(groups[group], current, options, function(theme)
      active = nil
      confirm(theme)
    end)
  end
  open_categories = function(group)
    local options = vim.tbl_extend("force", {}, opts, {
      prompt = "Theme groups · Enter: open",
      preview = false,
      apply = false,
    })
    return picker.open(categories, group, options, function(category)
      transition(function()
        return open_themes(category.name)
      end)
    end)
  end
  if #groups[initial] > 0 then
    return open_themes(initial)
  end
  return open_categories(initial)
end

return M
