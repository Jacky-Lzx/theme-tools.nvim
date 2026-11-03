local M = {}
local colors = require("theme_tools.colors")
local active
local ns = vim.api.nvim_create_namespace("theme_tools_picker")

local function notify(err)
  vim.notify(tostring(err), vim.log.levels.WARN, { title = "theme-tools" })
end

local function layout(opts)
  local available = vim.o.lines - vim.o.cmdheight
  if vim.o.columns < 16 or available < 7 then
    return nil
  end
  local width = math.min(math.floor(opts.width), vim.o.columns - 4)
  local height = math.min(math.floor(opts.height), available - 6)
  local row = math.floor((available - height - 5) / 2)
  local col = math.floor((vim.o.columns - width - 2) / 2)
  return {
    input = {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = 1,
      style = "minimal",
      border = opts.border,
      title = " Filter themes ",
      title_pos = "center",
      zindex = 60,
    },
    list = {
      relative = "editor",
      row = row + 3,
      col = col,
      width = width,
      height = height,
      style = "minimal",
      border = opts.border,
      title = " Themes ",
      title_pos = "center",
      footer = " Enter: apply  Esc: cancel ",
      footer_pos = "center",
      focusable = false,
      zindex = 60,
    },
  }
end

local function finish(session, accept)
  if active ~= session then
    return
  end
  active = nil
  vim.api.nvim_del_augroup_by_id(session.group)
  vim.cmd.stopinsert()
  for _, win in ipairs({ session.input_win, session.list_win }) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, buf in ipairs({ session.input_buf, session.list_buf }) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  if not accept then
    colors.restore(session.original)
  end
end

function M.close()
  if active then
    finish(active, false)
  end
end

local function clip(text, width)
  local result = ""
  for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    if vim.fn.strdisplaywidth(result .. char) > width then
      break
    end
    result = result .. char
  end
  return result
end

local function render(session)
  if active ~= session then
    return
  end
  local width = vim.api.nvim_win_get_width(session.list_win)
  local lines = {}
  for _, theme in ipairs(session.matches) do
    local label = (theme.label or theme.name):gsub("%c", " ")
    lines[#lines + 1] = clip("  " .. label, width)
  end
  if #lines == 0 then
    lines = { "  No matching themes" }
  end
  vim.bo[session.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.list_buf, 0, -1, false, lines)
  vim.bo[session.list_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(session.list_buf, ns, 0, -1)
  local theme = session.matches[session.index]
  if theme then
    vim.api.nvim_buf_set_extmark(session.list_buf, ns, session.index - 1, 0, { line_hl_group = "PmenuSel" })
    vim.api.nvim_win_set_cursor(session.list_win, { session.index, 0 })
    if session.previewed ~= theme.name then
      local ok, err = colors.apply(theme)
      if ok then
        session.previewed = theme.name
      elseif session.failed ~= theme.name then
        session.failed = theme.name
        notify(err)
      end
    end
  elseif session.previewed then
    colors.restore(session.original)
    session.previewed = nil
  end
end

local function filter(session)
  if active ~= session then
    return
  end
  local query = (vim.api.nvim_buf_get_lines(session.input_buf, 0, 1, false)[1] or ""):lower()
  local previous = session.matches[session.index]
  session.matches, session.index = {}, 1
  for _, theme in ipairs(session.themes) do
    local text = (theme.name .. " " .. (theme.label or "") .. " " .. theme.colorscheme):lower()
    local matches = true
    for word in query:gmatch("%S+") do
      matches = matches and text:find(word, 1, true) ~= nil
    end
    if matches then
      session.matches[#session.matches + 1] = theme
      if previous and theme.name == previous.name then
        session.index = #session.matches
      end
    end
  end
  render(session)
end

function M.open(themes, current, opts, confirm)
  M.close()
  if #themes == 0 then
    return nil, "No themes available; install a colorscheme or configure themes"
  end
  local geometry = layout(opts)
  if not geometry then
    return nil, "Terminal is too small for the theme picker"
  end
  local session = {
    themes = themes,
    matches = themes,
    index = 1,
    original = colors.snapshot(),
    previewed = current,
    group = vim.api.nvim_create_augroup("ThemeToolsPicker", { clear = true }),
  }
  for i, theme in ipairs(themes) do
    if theme.name == current then
      session.index = i
      break
    end
  end
  session.input_buf = vim.api.nvim_create_buf(false, true)
  session.list_buf = vim.api.nvim_create_buf(false, true)
  for _, buf in ipairs({ session.input_buf, session.list_buf }) do
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "theme-tools"
    vim.bo[buf].swapfile = false
    vim.bo[buf].undolevels = -1
  end
  -- Build both windows before entering the editable filter.
  local ok, err = pcall(function()
    session.list_win = vim.api.nvim_open_win(session.list_buf, false, geometry.list)
    session.input_win = vim.api.nvim_open_win(session.input_buf, true, geometry.input)
  end)
  if not ok then
    for _, win in ipairs({ session.list_win or -1, session.input_win or -1 }) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    for _, buf in ipairs({ session.input_buf, session.list_buf }) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.api.nvim_del_augroup_by_id(session.group)
    return nil, tostring(err)
  end
  active = session
  vim.wo[session.input_win].wrap = false
  vim.wo[session.list_win].wrap = false
  vim.wo[session.list_win].scrolloff = 0
  vim.b[session.input_buf].completion = false
  local function map(keys, callback)
    vim.keymap.set({ "n", "i" }, keys, callback, { buffer = session.input_buf, silent = true, nowait = true })
  end
  local function move(step)
    -- Typeahead may invoke a mapping before TextChangedI has been dispatched.
    filter(session)
    if active == session and #session.matches > 0 then
      session.index = math.max(1, math.min(#session.matches, session.index + step))
      render(session)
    end
  end
  for _, key in ipairs({ "<Down>", "<C-n>", "<Tab>" }) do
    map(key, function()
      move(1)
    end)
  end
  for _, key in ipairs({ "<Up>", "<C-p>", "<S-Tab>" }) do
    map(key, function()
      move(-1)
    end)
  end
  for _, key in ipairs({ "<Esc>", "<C-c>" }) do
    map(key, M.close)
  end
  map("<CR>", function()
    if active ~= session then
      return
    end
    filter(session)
    local theme = session.matches[session.index]
    if theme and session.previewed == theme.name then
      finish(session, true)
      confirm(theme)
    end
  end)
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
    group = session.group,
    buffer = session.input_buf,
    callback = function()
      filter(session)
    end,
  })
  vim.api.nvim_create_autocmd({ "WinLeave", "BufWipeout" }, {
    group = session.group,
    buffer = session.input_buf,
    callback = function()
      vim.schedule(function()
        if active == session then
          M.close()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = session.group,
    pattern = { tostring(session.input_win), tostring(session.list_win) },
    callback = function()
      vim.schedule(function()
        if active == session then
          M.close()
        end
      end)
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = session.group,
    callback = function()
      local resized = layout(opts)
      if not resized then
        M.close()
        return
      end
      vim.api.nvim_win_set_config(session.input_win, resized.input)
      vim.api.nvim_win_set_config(session.list_win, resized.list)
      render(session)
    end,
  })
  render(session)
  vim.cmd.startinsert()
  return true
end

return M
