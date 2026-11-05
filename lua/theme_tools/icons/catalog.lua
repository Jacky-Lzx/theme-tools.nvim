-- Shared semantic icons also cover categories absent from individual providers.
local M = {}
M.categories = { "file", "extension", "filetype", "directory", "os", "lsp", "diagnostic", "git", "task", "ui" }
M.defaults = {
  file = { "󰈔", "f", "Normal" },
  extension = { "󰈔", "f", "Normal" },
  filetype = { "󰈔", "f", "Normal" },
  directory = { "󰉋", "d", "Directory" },
  os = { "", "o", "Normal" },
  lsp = { "󰘦", "?", "Identifier" },
  diagnostic = { "󰋽", "i", "DiagnosticInfo" },
  git = { "", "g", "Normal" },
  task = { "󰔟", "R", "DiagnosticInfo" },
  ui = { "󰋽", "?", "Normal" },
}
M.values = {
  diagnostic = {
    error = { "", "E", "DiagnosticError" },
    warn = { "", "W", "DiagnosticWarn" },
    info = { "", "I", "DiagnosticInfo" },
    hint = { "󰌵", "H", "DiagnosticHint" },
    ok = { "󰄬", "O", "DiagnosticOk" },
    debug = { "󰃤", "D", "Comment" },
    trace = { "󰙎", "T", "Comment" },
  },
  task = {
    failure = { "", "F", "DiagnosticError" },
    stopped = { "󰜺", "S", "Comment" },
    success = { "󰄬", "O", "DiagnosticOk" },
    running = { "󰔟", "R", "DiagnosticInfo" },
    stopping = { "󰜺", "S", "DiagnosticWarn" },
  },
  git = {
    added = { "", "+", "DiffAdd" },
    modified = { "", "~", "DiffChange" },
    removed = { "", "-", "DiffDelete" },
    branch = { "", "@", "Identifier" },
    conflict = { "", "!", "DiagnosticWarn" },
    untracked = { "", "?", "DiagnosticInfo" },
  },
  ui = {
    search = { "", "/", "Normal" },
    close = { "󰅖", "x", "Normal" },
    check = { "󰄬", "+", "DiagnosticOk" },
    collapsed = { "", ">", "Normal" },
    expanded = { "", "v", "Normal" },
    loading = { "󰔟", "*", "Normal" },
    cancelled = { "󰜺", "-", "Comment" },
    lightbulb = { "", "!", "DiagnosticHint" },
    cycle = { "↻", "@", "Special" },
    bullet = { "", "*", "NonText" },
    previous = { "‹", "<", "Normal" },
    next = { "›", ">", "Normal" },
  },
  lsp = {},
}
local kinds = {
  "󰉿",
  "󰆧",
  "󰊕",
  "",
  "󰜢",
  "󰀫",
  "󰠱",
  "",
  "",
  "󰜢",
  "󰑭",
  "󰎠",
  "",
  "󰌋",
  "",
  "󰏘",
  "󰈙",
  "󰈇",
  "󰉋",
  "",
  "󰏿",
  "󰙅",
  "",
  "󰆕",
  "󰅲",
}
local kind_highlights = {
  "Comment",
  "Function",
  "Function",
  "Special",
  "Identifier",
  "Identifier",
  "Type",
  "Type",
  "Include",
  "Identifier",
  "Number",
  "Constant",
  "Type",
  "Keyword",
  "Special",
  "Special",
  "Directory",
  "Identifier",
  "Directory",
  "Identifier",
  "Constant",
  "Structure",
  "Type",
  "Operator",
  "Type",
}
for i, name in ipairs(vim.lsp.protocol.CompletionItemKind) do
  M.values.lsp[name] = { kinds[i] or "󰘦", name:sub(1, 1), kind_highlights[i] or "Identifier" }
end
-- SymbolKind contains additional names used by outlines and breadcrumbs.
for name, value in pairs({
  Namespace = { "󰅪", "N", "Include" },
  Package = { "󰏗", "P", "Include" },
  String = { "󰀬", "S", "String" },
  Number = { "󰎠", "N", "Number" },
  Boolean = { "◩", "B", "Boolean" },
  Array = { "󰅪", "A", "Type" },
  Object = { "󰅩", "O", "Type" },
  Key = { "󰌆", "K", "Type" },
  Null = { "󰟢", "N", "Type" },
}) do
  M.values.lsp[name] = value
end

function M.get(category, name, ascii)
  local value = (M.values[category] or {})[name]
  local fallback = value == nil
  value = value or M.defaults[category]
  return value[ascii and 2 or 1], value[3], fallback
end

return M
