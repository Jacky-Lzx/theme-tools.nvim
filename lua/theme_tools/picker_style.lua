-- Builtin frame geometry. The selection-tools backend inherits its own layout.
local M = {}

function M.resolve(opts, preview)
  local columns, available = vim.o.columns, vim.o.lines - vim.o.cmdheight
  if columns < 16 or available < 7 then
    return nil
  end
  local function size(value, total)
    return math.floor(value <= 1 and value * total or value)
  end
  local width = math.max(4, math.min(columns - 4, size(opts.width, columns)))
  local height = math.max(4, math.min(available - 2, size(opts.height, available)))
  local sample = preview and height >= 7 and math.max(1, math.min(height - 5, size(opts.preview_height or 0.6, height)))
    or 0
  local list_height = height - 2 - (sample > 0 and sample + 1 or 0)
  local row, col = math.floor((available - height - 2) / 2), math.floor((columns - width - 2) / 2)
  local common = { relative = "editor", style = "minimal", border = "none", width = width, col = col + 1, zindex = 61 }
  local result = {
    frame = {
      relative = "editor",
      style = "minimal",
      row = row,
      col = col,
      width = width,
      height = height,
      border = opts.border,
      title = " " .. (opts.prompt or "Themes") .. " ",
      title_pos = "center",
      focusable = false,
      zindex = 60,
    },
    input = vim.tbl_extend("force", common, { row = row + height, height = 1 }),
    list = vim.tbl_extend(
      "force",
      common,
      { row = row + 1 + (sample > 0 and sample + 1 or 0), height = list_height, focusable = false }
    ),
    separators = { height - 2 },
    height = height,
    width = width,
  }
  if sample > 0 then
    result.preview = vim.tbl_extend("force", common, { row = row + 1, height = sample, focusable = false })
    table.insert(result.separators, 1, sample)
  end
  return result
end

return M
