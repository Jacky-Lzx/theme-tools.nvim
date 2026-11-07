local M = {}
local active

local function release(session)
  session.closed = true
  session.viewer:close()
  if active == session then
    active = nil
  end
end

function M.close()
  if active then
    local session = active
    release(session)
    if session.picker then
      session.picker:close()
    end
  end
end

function M.open(items, current, opts, prepare, apply)
  M.close()
  local selection
  if opts.backend == "selection_tools" then
    local available
    available, selection = pcall(require, "selection_tools")
    if not available then
      return nil, "The selection_tools picker requires selection-tools.nvim"
    end
  end
  local session = {
    viewer = require("theme_tools.preview").new({
      worker = "theme_tools.icons.preview_worker",
      options = require("theme_tools.icons")._preview_options(),
    }),
  }
  active = session
  local function draw(buf, win, item)
    session.item = item
    if not item then
      require("theme_tools.icons.sample").draw(buf, win, nil)
      return
    end
    session.viewer:show(item, function(frame, err)
      if not session.closed and session.item == item then
        require("theme_tools.icons.sample").draw(buf, win, item, frame, err)
      end
    end)
  end
  if opts.backend == "builtin" then
    local picker = require("theme_tools.picker")
    local ok, err = picker.open(
      items,
      current,
      vim.tbl_extend("force", {}, opts, {
        apply = false,
        preview = false,
        prompt = "Icons · provider samples",
        empty_text = "  No matching icon providers",
        preview_draw = draw,
        on_close = function()
          release(session)
        end,
        before_confirm = function(item)
          return prepare(item.name)
        end,
      }),
      function(item)
        apply(item.name)
      end
    )
    if not ok then
      release(session)
      return nil, err
    end
    session.picker = { close = picker.close }
    return true
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
    preview = { enabled = true },
    format_item = function(item)
      return "  " .. item.label
    end,
    before_confirm = function(ctx)
      local ok, err = prepare(ctx.item.name)
      return ok == true, err
    end,
    on_close = function()
      release(session)
    end,
    previewer = function(ctx)
      local latest, failure
      session.viewer:show(ctx.item, function(frame, err)
        latest, failure = frame, err
        if not ctx.is_cancelled() then
          ctx.paint(function(buf, win)
            require("theme_tools.icons.sample").draw(buf, win, ctx.item, frame, err)
          end, { title = ctx.item.name })
        end
      end)
      return {
        resize = function()
          if not ctx.is_cancelled() then
            require("theme_tools.icons.sample").draw(ctx.buf, ctx.win, ctx.item, latest, failure)
          end
        end,
      }
    end,
    keys = {
      preview_down = ((opts.selection or {}).keys or {}).preview_down or { "<C-d>" },
      preview_up = ((opts.selection or {}).keys or {}).preview_up or { "<C-u>" },
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
  spec.items = ordered
  spec.on_choice = function(item)
    if item then
      apply(item.name)
    end
  end
  if spec.components == nil then
    spec.components = {
      require("selection_tools.components").text({ get = spec.format_item, grow = 1, truncate = "match" }),
    }
  end
  local ok, picker = pcall(selection.open, spec)
  if not ok then
    release(session)
    return nil, tostring(picker)
  end
  session.picker = picker
  return true
end

return M
