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
  local preview_height
  if opts.preview_mode ~= "live" and opts.apply ~= false and available >= 16 then
    local content = math.min(math.floor(opts.height) + 12, available - 9)
    height = math.min(math.floor(opts.height), math.max(2, math.floor(content / 4)))
    preview_height = content - height
    width = math.min(math.max(width, 80), vim.o.columns - 4)
    row = math.floor((available - content - 7) / 2)
  end
  local col = math.floor((vim.o.columns - width - 2) / 2)
  local result = {
    input = {
      relative = "editor",
      row = row,
      col = col,
      width = width,
      height = 1,
      style = "minimal",
      border = opts.border,
      title = opts.apply == false and " Filter groups " or " Filter themes ",
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
      title = " " .. (opts.prompt or "Themes") .. " ",
      title_pos = "center",
      footer = opts.apply == false and " Enter: open  Esc: cancel " or " Enter: apply  Esc: cancel ",
      footer_pos = "center",
      focusable = false,
      zindex = 60,
    },
  }
  if preview_height then
    result.preview = {
      relative = "editor",
      row = row + height + 5,
      col = col,
      width = width,
      height = preview_height,
      style = "minimal",
      border = opts.border,
      title = " Theme preview · Ctrl-D/U: scroll ",
      title_pos = "center",
      focusable = false,
      zindex = 60,
    }
  end
  return result
end

local function finish(session, accept)
  if active ~= session then
    return
  end
  active = nil
  vim.api.nvim_del_augroup_by_id(session.group)
  vim.cmd.stopinsert()
  if session.viewer then
    session.viewer:close()
  end
  for _, win in ipairs({ session.input_win, session.list_win, session.preview_win or -1 }) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, buf in ipairs({ session.input_buf, session.list_buf, session.preview_buf or -1 }) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
  if not accept and session.opts.preview ~= false and not session.viewer then
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
    if session.viewer and session.preview_win then
      session.viewer:show(theme, function(frame, err)
        if active == session then
          require("theme_tools.sample").draw(session.preview_buf, session.preview_win, theme, frame, err)
        end
      end)
    elseif not session.viewer and session.opts.preview ~= false and session.previewed ~= theme.name then
      local ok, err = colors.apply(theme)
      if ok then
        session.previewed = theme.name
      elseif session.failed ~= theme.name then
        session.failed = theme.name
        notify(err)
      end
    end
  elseif
    not session.viewer
    and session.previewed
    and session.opts.preview ~= false
    and not session.opts.retain_preview
  then
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
    opts = opts,
    matches = themes,
    index = 1,
    original = colors.snapshot(),
    previewed = current,
    group = vim.api.nvim_create_augroup("ThemeToolsPicker", { clear = true }),
  }
  if opts.preview_mode ~= "live" and opts.apply ~= false then
    session.viewer = require("theme_tools.preview").new()
    session.preview_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[session.preview_buf].bufhidden = "wipe"
    vim.bo[session.preview_buf].filetype = "theme-tools-preview"
    vim.bo[session.preview_buf].swapfile = false
  end
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
    if geometry.preview then
      session.preview_win = vim.api.nvim_open_win(session.preview_buf, false, geometry.preview)
    end
  end)
  if not ok then
    if session.viewer then
      session.viewer:close()
    end
    for _, win in ipairs({ session.list_win or -1, session.input_win or -1, session.preview_win or -1 }) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    for _, buf in ipairs({ session.input_buf, session.list_buf, session.preview_buf or -1 }) do
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
  if opts.on_group then
    map("<C-g>", opts.on_group)
  end
  if session.viewer then
    local function scroll(step)
      if session.preview_win and vim.api.nvim_win_is_valid(session.preview_win) then
        local cursor = vim.api.nvim_win_get_cursor(session.preview_win)
        cursor[1] = math.max(1, math.min(vim.api.nvim_buf_line_count(session.preview_buf), cursor[1] + step))
        vim.api.nvim_win_set_cursor(session.preview_win, cursor)
      end
    end
    map("<C-d>", function()
      scroll(6)
    end)
    map("<C-u>", function()
      scroll(-6)
    end)
  end
  map("<CR>", function()
    if active ~= session then
      return
    end
    filter(session)
    local theme = session.matches[session.index]
    if theme then
      if opts.apply ~= false and (session.viewer or session.previewed ~= theme.name) then
        local applied, reason = colors.apply(theme)
        if not applied then
          notify(reason)
          return
        end
      end
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
    callback = function(event)
      local closed = tonumber(event.match)
      vim.schedule(function()
        if
          active == session
          and (closed == session.input_win or closed == session.list_win or closed == session.preview_win)
        then
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
      if resized.preview then
        if session.preview_win and vim.api.nvim_win_is_valid(session.preview_win) then
          vim.api.nvim_win_set_config(session.preview_win, resized.preview)
        else
          session.preview_win = vim.api.nvim_open_win(session.preview_buf, false, resized.preview)
        end
      elseif session.preview_win then
        -- Keep the sample buffer alive while the terminal is too small.
        vim.bo[session.preview_buf].bufhidden = "hide"
        vim.api.nvim_win_close(session.preview_win, true)
        session.preview_win = nil
      end
      render(session)
    end,
  })
  render(session)
  vim.cmd.startinsert()
  return true
end

return M
