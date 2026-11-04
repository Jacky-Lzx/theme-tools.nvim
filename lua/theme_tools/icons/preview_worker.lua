-- Isolated provider setup/downloads and icon highlights; the host stays unchanged.
local M = {}
local channel, session, config, pending, scheduled, busy

function M.setup(options, parent, id)
  channel, session, config = parent, id, options.icons
  vim.o.background = options.background
  for name, attributes in pairs(options.highlights) do
    vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", {}, attributes, { default = false }))
  end
  vim.notify = function() end -- Failures are returned to the pane, never host notifications.
end

local function render(request)
  local ok, result = pcall(function()
    local item = assert(loadstring(request.item))()
    local icons = require("theme_tools.icons")
    icons.setup(vim.tbl_extend("force", {}, config, { default = item.name }))
    local loaded, err = icons.set(item.name)
    assert(loaded, err)
    return require("theme_tools.icons.sample").build(icons)
  end)
  vim.rpcnotify(channel, "nvim_exec_lua", "require('theme_tools.preview').receive(...)", {
    session,
    request.id,
    ok and result or vim.NIL,
    not ok and tostring(result) or vim.NIL,
  })
end

function M.request(id, item)
  pending = { id = id, item = item }
  if scheduled or busy then
    return
  end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    local request = pending
    pending, busy = nil, true
    render(request)
    busy = false
    if pending then
      M.request(pending.id, pending.item)
    end
  end)
end

return M
