local M = {}
local workers, next_id = {}, 0
local Viewer = {}
Viewer.__index = Viewer

function M.receive(id, request, frame, err)
  local viewer = workers[id]
  if not viewer or viewer.closed or (request ~= viewer.request and request ~= 0) then
    return
  end
  frame, err = frame ~= vim.NIL and frame or nil, err ~= vim.NIL and err or nil
  if frame then
    viewer.cache[viewer.key] = frame
  end
  viewer.pending = false
  if viewer.draw then
    viewer.draw(frame, err)
  end
end

function Viewer:close()
  if self.closed then
    return
  end
  self.closed = true
  self.cache, self.draw = {}, nil
  workers[self.id] = nil
  if self.job and self.job > 0 then
    pcall(vim.fn.jobstop, self.job)
  end
end

function Viewer:show(theme, draw)
  self.draw = draw
  local key = theme.name
    .. "\0"
    .. (theme.colorscheme or "")
    .. "\0"
    .. (theme.background or "")
    .. "\0"
    .. tostring(theme.transparent)
  if self.key == key and self.pending then
    return
  end
  self.key, self.request = key, self.request + 1
  self.pending = false
  if self.cache[key] then
    draw(self.cache[key])
    return
  end
  local ok, payload = pcall(require("theme_tools.serialize").encode, theme)
  if not ok then
    draw(nil, payload)
    return
  end
  if not self.job then
    local options = self.options or require("theme_tools")._preview_options()
    local encoded, configuration = pcall(require("theme_tools.serialize").encode, options)
    if not encoded then
      draw(nil, configuration)
      return
    end
    local logfile = vim.fn.tempname()
    self.job = vim.fn.jobstart(
      { vim.v.progpath, "--embed", "--headless", "-u", "NONE", "-i", "NONE", "-n", "--noplugin" },
      {
        rpc = true,
        env = { NVIM_LOG_FILE = logfile },
        on_exit = function()
          vim.fn.delete(logfile)
          if not self.closed then
            self.job = nil
            M.receive(self.id, 0, nil, "Preview process exited")
          end
        end,
      }
    )
    if self.job <= 0 then
      self.job = nil
      draw(nil, "Cannot start preview process")
      return
    end
    vim.rpcnotify(
      self.job,
      "nvim_exec_lua",
      [[
      local encoded, id, rtp, packpath, path, cpath, worker = ...
      local parent
      for _, info in ipairs(vim.api.nvim_list_chans()) do
        if info.stream == 'stdio' and info.mode == 'rpc' then parent = info.id; break end
      end
      assert(parent, 'missing preview RPC channel')
      local ok, err = pcall(function()
        vim.o.runtimepath, vim.o.packpath = rtp, packpath
        package.path, package.cpath = path, cpath
        require(worker).setup(assert(loadstring(encoded))(), parent, id)
      end)
      if not ok then
        vim.rpcnotify(parent, 'nvim_exec_lua', "require('theme_tools.preview').receive(...)", {id, 0, vim.NIL, tostring(err)})
      end
    ]],
      { configuration, self.id, vim.o.runtimepath, vim.o.packpath, package.path, package.cpath, self.worker }
    )
  end
  self.pending = true
  draw(nil, nil)
  vim.rpcnotify(
    self.job,
    "nvim_exec_lua",
    "local worker, id, payload = ...; require(worker).request(id, payload)",
    { self.worker, self.request, payload }
  )
end

function M.new(opts)
  opts = opts or {}
  next_id = next_id + 1
  local viewer = setmetatable({
    id = next_id,
    request = 0,
    cache = {},
    worker = opts.worker or "theme_tools.preview_worker",
    options = opts.options,
  }, Viewer)
  workers[viewer.id] = viewer
  return viewer
end

return M
