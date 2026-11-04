local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("theme_tools_icon_preview_colors")
local marks = api.nvim_create_namespace("theme_tools_icon_preview_sample")

local function kinds()
  local names, seen = {}, {}
  for _, protocol in ipairs({ vim.lsp.protocol.CompletionItemKind, vim.lsp.protocol.SymbolKind }) do
    for _, name in ipairs(protocol) do
      if not seen[name] then
        names[#names + 1], seen[name] = name, true
      end
    end
  end
  return names
end

local samples = {
  {
    title = "Files",
    category = "file",
    names = {
      "init.lua",
      "main.py",
      "main.rs",
      "main.go",
      "main.c",
      "main.cpp",
      "index.js",
      "index.ts",
      "App.tsx",
      "index.html",
      "style.css",
      "config.json",
      "config.yaml",
      "Cargo.toml",
      "main.tex",
      "refs.bib",
      "README.md",
      "script.sh",
      "shell.zsh",
      "flake.nix",
      "Makefile",
      "Dockerfile",
      ".gitignore",
      "LICENSE",
      "image.png",
      "icon.svg",
      "paper.pdf",
      "archive.zip",
      "query.sql",
      "notes.txt",
    },
  },
  { title = "Directories", category = "directory", names = { "src", "tests", "docs", ".git", ".config", "assets" } },
  {
    title = "Diagnostics",
    category = "diagnostic",
    names = { "error", "warn", "info", "hint", "ok", "debug", "trace" },
  },
  { title = "Git", category = "git", names = { "added", "modified", "removed", "branch", "conflict", "untracked" } },
  {
    title = "UI",
    category = "ui",
    names = {
      "search",
      "close",
      "check",
      "collapsed",
      "expanded",
      "loading",
      "cancelled",
      "lightbulb",
      "cycle",
      "bullet",
      "previous",
      "next",
    },
  },
  { title = "LSP types", category = "lsp", names = kinds() },
  { title = "Operating systems", category = "os", names = { "linux", "windows", "macos", "arch", "ubuntu", "debian" } },
}

-- Runs in the worker: query the chosen provider, never the host's active one.
function M.build(icons)
  local frame = { name = icons.current(), groups = {}, highlights = {}, count = 0 }
  local function highlight(name)
    if not frame.highlights[name] then
      frame.highlights[name] = api.nvim_get_hl(0, { name = name, link = false })
    end
  end
  for _, group in ipairs(samples) do
    local entries = {}
    for _, name in ipairs(group.names) do
      local icon, hl = icons.get(group.category, name)
      entries[#entries + 1] = { label = name .. (group.category == "directory" and "/" or ""), icon = icon, hl = hl }
      highlight(hl)
      frame.count = frame.count + 1
    end
    frame.groups[#frame.groups + 1] = { title = group.title, entries = entries }
  end
  for _, name in ipairs({ "Title", "Comment", "Normal", "NormalFloat" }) do
    highlight(name)
  end
  return frame
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

function M.draw(buf, win, item, frame, err)
  if not api.nvim_buf_is_valid(buf) or not api.nvim_win_is_valid(win) then
    return
  end
  local lines, ranges = {}, {}
  local function line(text, hl)
    text = clip(text, api.nvim_win_get_width(win))
    lines[#lines + 1] = text
    if hl then
      ranges[#ranges + 1] = { #lines - 1, 0, #text, hl }
    end
  end
  if frame then
    for name, attributes in pairs(frame.highlights) do
      api.nvim_set_hl(ns, name, vim.tbl_extend("force", {}, attributes, { default = false }))
    end
    line("  " .. frame.name .. " · " .. frame.count .. " icon samples", "Title")
    line(
      frame.name == "none" and "  Hidden: labels are shown without icons."
        or "  Ctrl-D/U: scroll · Enter: apply · Esc: cancel",
      "Comment"
    )
    line("  Diagnostics, Git and UI share the same semantic icons.", "Comment")
    line("")
    local available = math.max(1, api.nvim_win_get_width(win) - 4)
    local columns = math.max(1, math.floor(available / 26))
    local cell = math.floor(available / columns)
    for _, group in ipairs(frame.groups) do
      line("  " .. group.title, "Title")
      for first = 1, #group.entries, columns do
        local text = "  "
        for index = first, math.min(#group.entries, first + columns - 1) do
          local entry = group.entries[index]
          local prefix = entry.icon ~= "" and (entry.icon:gsub("%c", " ") .. " ") or ""
          local value = clip(prefix .. entry.label, math.max(1, cell - 2))
          local start = #text
          text = text .. value
          if prefix ~= "" then
            ranges[#ranges + 1] = { #lines, start, start + #clip(prefix, cell - 2), entry.hl }
          end
          if index < math.min(#group.entries, first + columns - 1) then
            text = text .. string.rep(" ", math.max(0, cell - vim.fn.strdisplaywidth(value)))
          end
        end
        line(text)
      end
      line("")
    end
  elseif err then
    line("  " .. (item and item.name or "Icons"), "Title")
    line("")
    line("  Preview unavailable", "DiagnosticWarn")
    line("  " .. tostring(err):gsub("[\r\n]", " "), "Comment")
    line("  Enter retries applying this provider; Esc cancels.", "Comment")
  else
    line("  " .. (item and (item.name .. " · preparing icon preview…") or "No matching icon providers"), "Comment")
  end
  local selected = item and item.name
  local same = vim.b[buf].theme_tools_icon_preview == selected
  local cursor = same and api.nvim_win_get_cursor(win) or { 1, 0 }
  local writable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = writable
  api.nvim_buf_clear_namespace(buf, marks, 0, -1)
  for _, range in ipairs(ranges) do
    if range[3] > range[2] then
      api.nvim_buf_set_extmark(buf, marks, range[1], range[2], { end_col = range[3], hl_group = range[4] })
    end
  end
  api.nvim_win_set_hl_ns(win, ns)
  vim.wo[win].winhighlight = ""
  vim.wo[win].wrap, vim.wo[win].number, vim.wo[win].relativenumber = false, false, false
  cursor[1] = math.min(cursor[1], #lines)
  cursor[2] = math.min(cursor[2], #lines[cursor[1]])
  api.nvim_win_set_cursor(win, cursor)
  vim.b[buf].theme_tools_icon_preview = selected
  vim.b[buf].theme_tools_icon_preview_ready = frame ~= nil
  vim.b[buf].theme_tools_icon_preview_error = err
  vim.b[buf].theme_tools_icon_preview_count = frame and frame.count or 0
end

return M
