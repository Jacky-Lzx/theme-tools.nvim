local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("theme_tools_preview_colors")
local marks = api.nvim_create_namespace("theme_tools_preview_sample")
local previous = {}

local lines = {
  "",
  "  NORMAL    INSERT    VISUAL                 main  [+]",
  "",
  "  -- Lua: syntax, numbers, strings and functions",
  "  local function greet(name)",
  "    local enabled = true",
  "    local count = 42",
  '    print("Hello, " .. name)',
  "    return { enabled = enabled, count = count }",
  "  end",
  '  greet("Neovim")',
  "",
  "  Search    current match    visual selection    (value)",
  "",
  "  Error     undefined variable 'result'",
  "  Warning   unused local 'count'",
  "  Info      inferred type: string",
  "  Hint      parameter can be optional",
  "",
  "  Completion menu",
  "    greet(name)             Function  [LSP]",
  "    enabled                 Variable  [Buffer]",
  "",
  "+ added: new greeting",
  "~ changed: return value",
  "- removed: old greeting",
  "",
  "  ┌─ Floating window ──────────────────────┐",
  "  │ Documentation and signature help      │",
  "  └───────────────────────────────────────┘",
  "",
  "  Transparent backgrounds use a solid preview canvas.",
  "  Enter: apply theme   Esc: cancel   Ctrl-D/U: scroll",
}

function M.draw(buf, win, theme, frame, err)
  if not api.nvim_buf_is_valid(buf) or not api.nvim_win_is_valid(win) then
    return
  end
  if not frame and not err then
    -- Keep the last complete sample while another theme is being prepared.
    if not vim.b[buf].theme_tools_preview then
      local writable = vim.bo[buf].modifiable
      vim.bo[buf].modifiable = true
      api.nvim_buf_set_lines(
        buf,
        0,
        -1,
        false,
        { "  " .. (theme.label or theme.name), "", "  Preparing theme preview…" }
      )
      vim.bo[buf].modifiable = writable
    end
    return
  end
  if frame then
    for name in pairs(previous) do
      if not frame.highlights[name] then
        api.nvim_set_hl(ns, name, {})
      end
    end
    for name, attrs in pairs(frame.highlights) do
      local value = vim.tbl_extend("force", {}, attrs)
      value.default = nil
      if name == "Normal" or name == "NormalNC" then
        value.link, value.bg = nil, frame.canvas
      end
      api.nvim_set_hl(ns, name, value)
    end
    -- A floating pane normally uses NormalFloat. Render the code canvas as an
    -- editor while preserving the theme's real float colors for the float sample.
    local floating = vim.tbl_extend("force", {}, frame.highlights.NormalFloat or {})
    floating.default = nil
    api.nvim_set_hl(ns, "ThemeToolsSampleFloat", floating)
    local normal = vim.tbl_extend("force", {}, frame.normal, { bg = frame.canvas })
    normal.default = nil
    api.nvim_set_hl(ns, "Normal", normal)
    api.nvim_set_hl(ns, "NormalNC", normal)
    api.nvim_set_hl(ns, "NormalFloat", normal)
    previous = frame.highlights
  end
  local text = vim.deepcopy(lines)
  text[1] = "  " .. (theme.label or theme.name) .. (frame and (" · " .. frame.background) or "")
  if frame then
    text[1] = text[1] .. " · transparent " .. (frame.transparent and "on" or "off")
    text[32] = "  Transparency: " .. (frame.transparent and "on" or "off") .. " · solid preview canvas."
  end
  if err then
    text = {
      text[1],
      "",
      "  Preview unavailable",
      "  " .. tostring(err):gsub("[\r\n]", " "),
      "",
      "  Enter still applies the theme; Esc cancels.",
    }
  end
  local writable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = writable
  api.nvim_buf_clear_namespace(buf, marks, 0, -1)
  local function span(row, token, group)
    local first, last = text[row]:find(token, 1, true)
    if first then
      api.nvim_buf_set_extmark(buf, marks, row - 1, first - 1, { end_col = last, hl_group = group })
    end
  end
  local function line(row, group)
    api.nvim_buf_set_extmark(buf, marks, row - 1, 0, {
      end_row = row,
      end_col = 0,
      hl_group = group,
      hl_eol = true,
    })
  end
  line(1, "Title")
  if not err then
    line(2, "StatusLine")
    span(2, "NORMAL", "Function")
    span(2, "INSERT", "String")
    span(2, "VISUAL", "Statement")
    line(4, "Comment")
    span(5, "local", "Keyword")
    span(5, "function", "Keyword")
    span(5, "greet", "Function")
    span(6, "local", "Keyword")
    span(6, "true", "Boolean")
    span(7, "local", "Keyword")
    span(7, "42", "Number")
    span(8, "print", "Function")
    span(8, '"Hello, "', "String")
    span(9, "return", "Keyword")
    span(10, "end", "Keyword")
    span(11, "greet", "Function")
    span(11, '"Neovim"', "String")
    span(13, "Search", "Search")
    span(13, "current match", "CurSearch")
    span(13, "visual selection", "Visual")
    span(13, "(value)", "MatchParen")
    for offset, kind in ipairs({ "Error", "Warn", "Info", "Hint" }) do
      line(14 + offset, "Diagnostic" .. kind)
    end
    line(20, "Title")
    line(21, "PmenuSel")
    line(22, "Pmenu")
    line(24, "DiffAdd")
    line(25, "DiffChange")
    line(26, "DiffDelete")
    line(28, "FloatBorder")
    line(29, "ThemeToolsSampleFloat")
    line(30, "FloatBorder")
    line(32, "Comment")
    line(33, "Comment")
  else
    line(3, "DiagnosticError")
  end
  vim.wo[win].winhighlight = ""
  api.nvim_win_set_hl_ns(win, ns)
  for key, value in pairs({
    wrap = false,
    number = false,
    relativenumber = false,
    cursorline = false,
    signcolumn = "no",
    foldcolumn = "0",
    winblend = 0,
  }) do
    vim.wo[win][key] = value
  end
  vim.b[buf].theme_tools_preview = theme.name
  vim.b[buf].theme_tools_preview_error = err
  vim.b[buf].theme_tools_preview_transparent = frame and frame.transparent
end

return M
