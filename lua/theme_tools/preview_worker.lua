-- Runs only in a disposable, embedded Neovim. No theme code runs in the host UI.
local M = {}
local channel, session, after, pending, scheduled, busy

local function send(request, frame, err)
  vim.rpcnotify(channel, "nvim_exec_lua", "require('theme_tools.preview').receive(...)", {
    session,
    request,
    frame or vim.NIL,
    err or vim.NIL,
  })
end

function M.setup(options, parent, id)
  channel, session, after = parent, id, options.after
  vim.loader.enable()
  if options.plugins then
    package.loaded["lazy.core.config"] = { plugins = options.plugins }
  end
  vim.g.colors_name = nil
  vim.o.background = options.background
  require("theme_tools").setup({
    persist = false,
    discover = false,
    themes = {},
    catppuccin = options.catppuccin,
    dracula = options.dracula,
    install = options.install,
  })
end

local function render(request)
  local ok, result = pcall(function()
    local theme = assert(loadstring(request.theme))()
    local applied, err = require("theme_tools.colors").apply(theme)
    assert(applied, err)
    if after then
      after(theme)
    end
    local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
    local canvas = normal.bg
    if not canvas then
      local palette
      if theme.colorscheme == "theme-tools-mocha" then
        palette = require("theme_tools.mocha.palette").base
      elseif theme.colorscheme:match("^catppuccin") and package.loaded.catppuccin then
        palette = require("catppuccin.palettes").get_palette().base
      elseif theme.colorscheme:match("^dracula") and package.loaded.dracula then
        palette = require("dracula").colors().bg
      end
      canvas = palette and tonumber(palette:sub(2), 16) or (vim.o.background == "light" and 0xf5f5f5 or 0x20202a)
    end
    return {
      highlights = vim.api.nvim_get_hl(0, {}),
      background = vim.o.background,
      canvas = canvas,
      normal = normal,
      transparent = normal.bg == nil,
    }
  end)
  send(request.id, ok and result or nil, not ok and tostring(result) or nil)
end

function M.request(id, theme)
  pending = { id = id, theme = theme }
  if scheduled or busy then
    return
  end
  scheduled = true
  vim.schedule(function()
    scheduled = false
    local request = pending
    pending = nil
    busy = true
    render(request)
    busy = false
    if pending then
      M.request(pending.id, pending.theme)
    end
  end)
end

return M
