local M = {}
local active

function M.close()
  if active then
    local picker = active
    active = nil
    picker:close()
  end
end

function M.open(items, current, opts, prepare, apply)
  M.close()
  if opts.backend == "builtin" then
    -- Reuse filtering, terminal input and resize handling without theme preview.
    local picker = require("theme_tools.picker")
    local ok, err = picker.open(
      items,
      current,
      vim.tbl_extend("force", {}, opts, {
        apply = false,
        preview = false,
        prompt = "Icons · provider samples",
        filter_title = " Filter icons ",
        footer = " Enter: apply  Esc: cancel ",
        empty_text = "  No matching icon providers",
        before_confirm = function(item)
          return prepare(item.name)
        end,
      }),
      function(item)
        active = nil
        apply(item.name)
      end
    )
    if ok then
      active = { close = picker.close }
    end
    return ok, err
  end
  local available, selection = pcall(require, "selection_tools")
  if not available then
    return nil, "The selection_tools picker requires selection-tools.nvim"
  end
  local ordered = {}
  for _, item in ipairs(items) do
    if item.name == current then
      table.insert(ordered, 1, item)
    else
      ordered[#ordered + 1] = item
    end
  end
  local spec = vim.tbl_deep_extend("force", {}, opts.selection or {}, {
    prompt = "Icons · provider samples",
    kind = "theme_tools_icons",
    resume = false,
    multi = false,
    item_icons = false,
    preview = { enabled = false },
    format_item = function(item)
      return item.label
    end,
    before_confirm = function(ctx)
      local ok, err = prepare(ctx.item.name)
      return ok == true, err
    end,
    on_close = function()
      active = nil
    end,
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
  })
  local ok, picker = pcall(selection.select, ordered, spec, function(item)
    if item then
      apply(item.name)
    end
  end)
  if not ok then
    return nil, tostring(picker)
  end
  active = picker
  return true
end

return M
