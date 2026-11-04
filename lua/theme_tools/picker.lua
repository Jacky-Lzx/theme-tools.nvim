local M = {}
local colors = require("theme_tools.colors")
local transparency = require("theme_tools.transparency")
local active
local ns = vim.api.nvim_create_namespace("theme_tools_picker")

local function notify(err)
  vim.notify(tostring(err), vim.log.levels.WARN, { title = "theme-tools" })
end

local function layout(opts)
  return require("theme_tools.picker_style").resolve(opts, opts.preview_mode ~= "live" and opts.apply ~= false)
end

local function scratch()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  return buf
end

local function frame(session)
  local geometry = session.geometry
  local count = (" %d/%d "):format(#session.matches > 0 and session.index or 0, #session.matches)
  local input_width = math.max(1, geometry.width - vim.fn.strdisplaywidth(count))
  vim.api.nvim_win_set_config(session.input_win, { width = input_width })
  local lines = {}
  for i = 1, geometry.height do
    lines[i] = ""
  end
  vim.bo[session.frame_buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.frame_buf, 0, -1, false, lines)
  vim.bo[session.frame_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(session.frame_buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(session.frame_buf, ns, geometry.height - 1, 0, {
    virt_text = { { count, "Comment" } },
    virt_text_pos = "right_align",
  })
  local border = vim.api.nvim_win_get_config(session.frame_win).border or {}
  local function char(i)
    return type(border[i]) == "table" and border[i][1] or border[i] or ""
  end
  local left, right = char(8), char(4)
  local joints = { ["│"] = { "├", "┤" }, ["║"] = { "╠", "╣" }, ["┃"] = { "┣", "┫" } }
  local horizontal = left == "║" and "═" or left == "┃" and "━" or "─"
  local dividers = {}
  for _, row in ipairs(geometry.separators) do
    dividers[#dividers + 1] = (joints[left] and joints[left][1] or left)
      .. string.rep(horizontal, geometry.width)
      .. (joints[right] and joints[right][2] or right)
  end
  vim.bo[session.separator_buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.separator_buf, 0, -1, false, dividers)
  vim.bo[session.separator_buf].modifiable = false
  for i, row in ipairs(geometry.separators) do
    local conf = {
      relative = "editor",
      style = "minimal",
      row = geometry.frame.row + row + 1,
      col = geometry.frame.col,
      width = geometry.width + 2,
      height = 1,
      focusable = false,
      zindex = 62,
    }
    local win = session.separator_wins[i]
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_config(win, conf)
    else
      win = vim.api.nvim_open_win(session.separator_buf, false, conf)
      session.separator_wins[i] = win
    end
    vim.wo[win].winhighlight = "Normal:FloatBorder"
    vim.wo[win].wrap = false
    vim.api.nvim_win_set_cursor(win, { i, 0 })
  end
  for i = #geometry.separators + 1, #session.separator_wins do
    local win = session.separator_wins[i]
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    session.separator_wins[i] = nil
  end
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
  for _, win in
    ipairs(
      vim.list_extend(
        { session.input_win, session.list_win, session.preview_win or -1, session.frame_win },
        session.separator_wins
      )
    )
  do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  for _, buf in ipairs({
    session.input_buf,
    session.list_buf,
    session.preview_buf or -1,
    session.frame_buf,
    session.separator_buf,
  }) do
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
  frame(session)
  local width = vim.api.nvim_win_get_width(session.list_win)
  local lines = {}
  for _, theme in ipairs(session.matches) do
    local label = (theme.label or theme.name):gsub("%c", " ")
    lines[#lines + 1] = clip("  " .. label, width)
  end
  if #lines == 0 then
    lines = { session.opts.empty_text or "  No matching themes" }
  end
  vim.bo[session.list_buf].modifiable = true
  vim.api.nvim_buf_set_lines(session.list_buf, 0, -1, false, lines)
  vim.bo[session.list_buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(session.list_buf, ns, 0, -1)
  local theme = session.matches[session.index]
  local function status(frame)
    if theme and session.opts.apply ~= false and transparency.key(session.opts) then
      vim.api.nvim_win_set_config(session.frame_win, {
        title = " "
          .. (session.opts.prompt or "Themes")
          .. " · "
          .. transparency.key(session.opts)
          .. ": transparent "
          .. transparency.label(theme, frame)
          .. " ",
      })
    end
  end
  status(theme and session.frames[theme.name])
  if theme then
    vim.api.nvim_buf_set_extmark(session.list_buf, ns, session.index - 1, 0, { line_hl_group = "PmenuSel" })
    vim.api.nvim_win_set_cursor(session.list_win, { session.index, 0 })
    if session.viewer and session.preview_win then
      session.viewer:show(theme, function(frame, err)
        if active == session then
          if frame then
            session.frames[theme.name] = frame
            status(frame)
          end
          require("theme_tools.sample").draw(session.preview_buf, session.preview_win, theme, frame, err)
        end
      end)
    elseif
      not session.viewer
      and session.opts.preview ~= false
      and (session.previewed ~= theme.name or session.previewed_transparent ~= theme.transparent)
    then
      local ok, err = colors.apply(theme)
      if ok then
        session.previewed = theme.name
        session.previewed_transparent = theme.transparent
        session.frames[theme.name] =
          { transparent = require("theme_tools.palettes.fallback").highlight("Normal", "bg") == nil }
        status(session.frames[theme.name])
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
    local text = (theme.name .. " " .. (theme.label or "") .. " " .. (theme.colorscheme or "")):lower()
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
    original = opts.preview ~= false and colors.snapshot() or nil,
    previewed = current,
    frames = {},
    geometry = geometry,
    separator_wins = {},
    frame_buf = scratch(),
    separator_buf = scratch(),
    group = vim.api.nvim_create_augroup("ThemeToolsPicker", { clear = true }),
  }
  if opts.preview_mode ~= "live" and opts.apply ~= false then
    session.viewer = require("theme_tools.preview").new()
    session.preview_buf = vim.api.nvim_create_buf(false, true)
    vim.b[session.preview_buf].theme_tools_picker_role = "preview"
    vim.bo[session.preview_buf].bufhidden = "wipe"
    vim.bo[session.preview_buf].filetype = "theme-tools-preview"
    vim.bo[session.preview_buf].swapfile = false
  end
  for i, theme in ipairs(themes) do
    if theme.name == current then
      session.index = i
      session.previewed_transparent = theme.transparent
      session.frames[theme.name] =
        { transparent = require("theme_tools.palettes.fallback").highlight("Normal", "bg") == nil }
      break
    end
  end
  session.input_buf = vim.api.nvim_create_buf(false, true)
  session.list_buf = vim.api.nvim_create_buf(false, true)
  for role, buf in pairs({
    frame = session.frame_buf,
    separator = session.separator_buf,
    input = session.input_buf,
    list = session.list_buf,
  }) do
    vim.b[buf].theme_tools_picker_role = role
  end
  for _, buf in ipairs({ session.input_buf, session.list_buf }) do
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "theme-tools"
    vim.bo[buf].swapfile = false
    vim.bo[buf].undolevels = -1
  end
  -- A single bordered frame contains all borderless panes.

  local ok, err = pcall(function()
    session.frame_win = vim.api.nvim_open_win(session.frame_buf, false, geometry.frame)
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
    for _, win in ipairs({
      session.list_win or -1,
      session.input_win or -1,
      session.preview_win or -1,
      session.frame_win or -1,
    }) do
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end
    for _, buf in ipairs({
      session.input_buf,
      session.list_buf,
      session.preview_buf or -1,
      session.frame_buf,
      session.separator_buf,
    }) do
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end
    vim.api.nvim_del_augroup_by_id(session.group)
    return nil, tostring(err)
  end
  active = session
  for _, win in ipairs({ session.frame_win, session.list_win, session.input_win }) do
    vim.wo[win].winhighlight = "Normal:NormalFloat"
  end
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
  local transparency_key = transparency.key(opts)
  if opts.apply ~= false and transparency_key then
    map(transparency_key, function()
      filter(session)
      local theme = session.matches[session.index]
      if theme then
        transparency.toggle(theme, session.frames[theme.name])
        render(session)
      end
    end)
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
      if opts.before_confirm then
        local accepted, reason = opts.before_confirm(theme)
        if not accepted then
          notify(reason)
          return
        end
      end
      if
        opts.apply ~= false
        and (session.viewer or session.previewed ~= theme.name or session.previewed_transparent ~= theme.transparent)
      then
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
          and (
            closed == session.input_win
            or closed == session.list_win
            or closed == session.frame_win
            or closed == session.preview_win
          )
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
      session.geometry = resized
      vim.api.nvim_win_set_config(session.frame_win, resized.frame)
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
