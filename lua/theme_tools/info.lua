local M = {}
local api = vim.api
local default_groups = {
  "Normal",
  "NormalFloat",
  "FloatBorder",
  "Pmenu",
  "PmenuSel",
  "ThemeToolsAccent",
  "ThemeToolsGitAdd",
  "ThemeToolsGitChange",
  "ThemeToolsGitDelete",
  "ThemeToolsIconGitAdd",
  "ThemeToolsIconGitChange",
  "ThemeToolsIconGitDelete",
  "SelectionToolsMarked",
  "FileToolsRoot",
  "UiToolsScope",
  "CompletionToolsMenu",
  "CompletionToolsBorder",
  "CompletionToolsDocBorder",
  "LspToolsHoverNormal",
  "LspToolsHoverBorder",
}

local function highlight(name)
  local result = { name = name, chain = {}, attributes = {} }
  local seen = {}
  while name do
    result.chain[#result.chain + 1] = name
    if seen[name] then
      result.status = "cycle"
      return result
    end
    seen[name] = true
    -- Read global definitions directly: the current window's winhighlight
    -- remapping must not change the reported chain or create missing groups.
    local value = api.nvim_get_hl(0, { name = name, link = true, create = false })
    if not value.link then
      result.attributes = value
      result.status = vim.tbl_isempty(value) and "undefined" or "defined"
      return result
    end
    name = value.link
  end
end

function M.snapshot(opts)
  opts = opts or {}
  local groups = opts.groups or default_groups
  assert(vim.islist(groups), "groups must be a list of highlight names")
  local highlights = {}
  for _, name in ipairs(groups) do
    assert(type(name) == "string" and name ~= "", "highlight name must be nonempty")
    highlights[#highlights + 1] = highlight(name)
  end
  local themes = require("theme_tools")
  local palette = themes.palette()
  return {
    theme = {
      id = themes.current(),
      colorscheme = vim.g.colors_name,
      background = vim.o.background,
      transparent = palette.transparent,
    },
    icons = themes.icons.info(),
    palette = palette,
    highlights = highlights,
  }
end

local function attributes(value)
  local parts = {}
  for _, key in ipairs(vim.fn.sort(vim.tbl_keys(value))) do
    local item = value[key]
    if type(item) == "number" and (key == "fg" or key == "bg" or key == "sp") then
      item = ("#%06x"):format(item)
    end
    parts[#parts + 1] = key .. "=" .. tostring(item)
  end
  return #parts > 0 and table.concat(parts, " ") or "no attributes"
end

local function report(value)
  local theme, icons = value.theme, value.icons
  local provider = icons.style == "glyph" and (icons.loaded and "loaded" or "not loaded") or "built-in"
  local lines = {
    "Theme tools",
    "q / Esc: close   r: refresh",
    "",
    "Theme: " .. (theme.id or "unregistered"),
    "Colorscheme: " .. (theme.colorscheme or "default"),
    "Background: " .. theme.background .. "   Transparent: " .. (theme.transparent and "yes" or "no"),
    "Icons: " .. icons.name .. "   Style: " .. icons.style .. "   Provider: " .. provider,
  }
  if icons.error then
    for _, line in ipairs(vim.split(icons.error, "\n", { plain = true })) do
      lines[#lines + 1] = "Icon error: " .. line
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Semantic palette (final roles)"
  for _, section in ipairs({ "palette", "ui", "diagnostic", "git" }) do
    for _, key in ipairs(vim.fn.sort(vim.tbl_keys(value.palette[section]))) do
      lines[#lines + 1] = ("  %-24s %s"):format(section .. "." .. key, value.palette[section][key])
    end
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Global highlight links and attributes"
  for _, group in ipairs(value.highlights) do
    lines[#lines + 1] = "  " .. table.concat(group.chain, " -> ")
    lines[#lines + 1] = "    " .. (group.status == "defined" and attributes(group.attributes) or group.status)
  end
  return lines
end

function M.open(opts)
  local value = M.snapshot(opts)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  local function refresh()
    vim.bo[buf].modifiable = true
    api.nvim_buf_set_lines(buf, 0, -1, false, report(value))
    vim.bo[buf].modifiable = false
    vim.bo[buf].modified = false
  end
  refresh()
  local win = api.nvim_open_win(buf, true, { split = "below", height = math.max(1, math.floor(vim.o.lines * 0.6)) })
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].foldenable = false
  vim.wo[win].spell = false
  vim.wo[win].list = false
  vim.wo[win].conceallevel = 0
  vim.wo[win].winhighlight = ""
  vim.wo[win].winbar = ""
  vim.wo[win].wrap = false
  vim.wo[win].winfixheight = true
  local function close()
    if api.nvim_win_is_valid(win) then
      api.nvim_win_close(win, true)
    end
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, close, { buffer = buf, nowait = true, silent = true, desc = "Close theme information" })
  end
  vim.keymap.set("n", "r", function()
    value = M.snapshot(opts)
    refresh()
  end, { buffer = buf, silent = true, desc = "Refresh theme information" })
  return buf, win
end

return M
