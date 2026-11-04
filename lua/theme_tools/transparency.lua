local M = {}
local editor = {
  "Normal",
  "NormalNC",
  "SignColumn",
  "FoldColumn",
  "LineNr",
  "EndOfBuffer",
  "MsgArea",
  "StatusLine",
  "StatusLineNC",
  "TabLineFill",
}
local floating = { "NormalFloat", "FloatBorder", "FloatTitle" }

function M.apply(enabled)
  if enabled == nil then
    return
  end
  assert(type(enabled) == "boolean", "transparent must be a boolean")
  local c = require("theme_tools.palettes").resolve()
  local raw = require("theme_tools.palettes.fallback").definition
  local function apply(groups, background)
    for _, name in ipairs(groups) do
      local hl = raw(name)
      if enabled then
        hl.bg, hl.ctermbg = "NONE", nil
      else
        hl.bg = hl.bg or background
      end
      hl.default = nil
      vim.api.nvim_set_hl(0, name, hl)
    end
  end
  apply(editor, c.palette.bg)
  apply(floating, c.ui.float_bg ~= "NONE" and c.ui.float_bg or c.palette.bg)
end

function M.key(opts)
  if opts.transparency_key == false then
    return false
  end
  return opts.transparency_key or "<C-t>"
end

function M.label(theme, frame)
  local enabled = theme and theme.transparent
  if enabled == nil and frame then
    enabled = frame.transparent
  end
  return enabled == nil and "default" or enabled and "on" or "off"
end

function M.toggle(theme, frame)
  theme.transparent = M.label(theme, frame) ~= "on"
end

function M.title(prompt, theme, frame, opts)
  local key = M.key(opts)
  return key and (prompt .. " · " .. key .. ": transparent " .. M.label(theme, frame)) or prompt
end

return M
