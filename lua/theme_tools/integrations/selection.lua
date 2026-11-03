local M = {}
local colors = require("theme_tools.colors")
local active

function M.close()
  if active and active.picker then
    active.picker:close()
  end
end

function M.open(themes, current, opts, confirm)
  M.close()
  if #themes == 0 then
    return nil, "No themes available; install a colorscheme or configure themes"
  end
  local available, selection = pcall(require, "selection_tools")
  if not available then
    return nil, "The selection_tools picker requires selection-tools.nvim"
  end
  -- Start on the active theme without briefly applying the first configured one.
  local items = {}
  for _, theme in ipairs(themes) do
    if theme.name == current then
      table.insert(items, 1, theme)
    else
      items[#items + 1] = theme
    end
  end
  local session = { original = colors.snapshot(), previewed = current }
  active = session
  local function preview(theme)
    if active ~= session then
      return nil, "Theme picker is closed"
    end
    if not theme then
      if session.previewed then
        colors.restore(session.original)
        session.previewed = nil
      end
      return true
    end
    if session.previewed == theme.name then
      return true
    end
    local ok, err = colors.apply(theme)
    if ok then
      session.previewed = theme.name
    end
    return ok, err
  end
  local spec = vim.tbl_deep_extend("force", {}, opts.selection or {}, {
    prompt = "Themes",
    kind = "theme_tools",
    resume = false,
    multi = false,
    preview = { enabled = false },
    item_icons = false,
    keys = {
      split = {},
      vsplit = {},
      tab = {},
      quickfix = {},
      quickfix_all = {},
      loclist = {},
      loclist_all = {},
      system_open = {},
      details = {},
    },
    format_item = function(theme)
      local label = theme.label or theme.name
      if label ~= theme.name then
        label = label .. " (" .. theme.name .. ")"
      end
      if theme.colorscheme ~= theme.name then
        label = label .. " · " .. theme.colorscheme
      end
      return label
    end,
    on_change = function(theme, _, picker)
      session.picker = picker
      local ok, err = preview(theme)
      if not ok and session.failed ~= (theme and theme.name) then
        session.failed = theme and theme.name
        vim.notify(err, vim.log.levels.WARN, { title = "theme-tools" })
      end
    end,
    before_confirm = function(ctx)
      local ok, err = preview(ctx.item)
      return ok == true, err
    end,
    on_close = function(_, outcome)
      session.closed = true
      if active == session then
        active = nil
        if outcome.reason ~= "confirm" then
          colors.restore(session.original)
        end
      end
    end,
  })
  local ok, picker = pcall(selection.select, items, spec, function(theme)
    if theme then
      confirm(theme)
    end
  end)
  if not ok then
    if not session.closed then
      active = nil
      colors.restore(session.original)
    end
    return nil, tostring(picker)
  end
  session.picker = picker
  return true
end

return M
