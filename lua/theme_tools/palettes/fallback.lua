local M = {}

function M.highlight(name, field)
  local value = vim.api.nvim_get_hl(0, { name = name, link = false, create = false })[field]
  if type(value) == "number" and value >= 0 then
    return string.format("#%06x", value)
  end
end

function M.resolve(base)
  local h = M.highlight
  local light = vim.o.background == "light"
  local p = vim.tbl_extend("force", {
    bg = h("Normal", "bg") or (light and "#ffffff" or "#14161b"),
    fg = h("Normal", "fg") or (light and "#14161b" or "#e0e2ea"),
    red = h("DiagnosticError", "fg") or "#e05f65",
    orange = h("Number", "fg") or "#d19a66",
    yellow = h("DiagnosticWarn", "fg") or "#d7ba7d",
    green = h("String", "fg") or "#98c379",
    cyan = h("DiagnosticHint", "fg") or "#56b6c2",
    blue = h("Function", "fg") or "#61afef",
    purple = h("Statement", "fg") or "#c678dd",
    pink = h("Special", "fg") or "#e06c9f",
  }, base or {})
  for name, color in pairs(p) do
    p[name] = color:lower()
  end
  local bg = h("Normal", "bg")
  local muted = h("Comment", "fg") or p.fg
  return {
    name = vim.g.colors_name or "default",
    background = vim.o.background,
    transparent = bg == nil,
    palette = p,
    ui = {
      fg = h("Normal", "fg") or p.fg,
      bg = bg or "NONE",
      float_fg = h("NormalFloat", "fg") or p.fg,
      float_bg = h("NormalFloat", "bg") or "NONE",
      muted = muted,
      subtle = h("NonText", "fg") or muted,
      border = h("FloatBorder", "fg") or muted,
      accent = h("Function", "fg") or p.blue,
      selection_fg = h("Visual", "fg") or p.fg,
      selection_bg = h("Visual", "bg") or p.purple,
      search_fg = h("Search", "fg") or p.bg,
      search_bg = h("Search", "bg") or p.yellow,
      cursorline_bg = h("CursorLine", "bg") or "NONE",
    },
    diagnostic = {
      error = h("DiagnosticError", "fg") or p.red,
      warn = h("DiagnosticWarn", "fg") or p.yellow,
      info = h("DiagnosticInfo", "fg") or p.blue,
      hint = h("DiagnosticHint", "fg") or p.cyan,
      ok = h("DiagnosticOk", "fg") or p.green,
    },
    git = {
      add = h("Added", "fg") or p.green,
      change = h("Changed", "fg") or p.yellow,
      delete = h("Removed", "fg") or p.red,
    },
  }
end

return M
