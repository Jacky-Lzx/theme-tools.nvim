-- Exercise real sibling consumers, including cached views already on screen.
local root = vim.fn.getcwd()
vim.opt.rtp:prepend(root)
for _, name in ipairs({ "selection", "completion", "lsp", "ui", "notification" }) do
  local path = vim.fs.dirname(root) .. "/" .. name .. "-tools.nvim"
  assert(vim.fn.isdirectory(path) == 1, "missing sibling checkout: " .. path)
  vim.opt.rtp:append(path)
end
vim.o.swapfile = false
vim.o.columns, vim.o.lines = 100, 36
local api = vim.api
local kinds = require("completion_tools.kinds")
assert(not package.loaded.theme_tools, "consumers must not load theme-tools implicitly")
assert(select(2, kinds.get(3)) ~= "")
local themes = require("theme_tools")
themes.setup({ persist = false, catppuccin = false, dracula = false, icons = { default = "ascii" } })
local icons = themes.icons
assert(select(2, kinds.get(3)) == "F")
assert(require("lsp-tools.symbols.icons").get("Namespace") == "N")
assert(require("ui_tools.icons").get("ui", "search", "custom") == "/")
assert(require("notification-tools.icons").get("diagnostic", "error", "custom") == "E")

local selection = require("selection_tools")
local picker = selection.open({
  items = { { file = "/tmp/init.lua", text = "init.lua" } },
  format_item = function(item)
    return item.text
  end,
})
assert(table.concat(api.nvim_buf_get_lines(picker.list_buf, 0, -1, false)):find("f init.lua", 1, true))
local input = picker.input_buf
assert(icons.set("none"))
assert(not picker.closed and picker.input_buf == input)
assert(select(2, require("lsp-tools.symbols.icons").get("Namespace")) == "Include")
assert(not picker.entries[1].icon, "hidden mode must invalidate resolved file icons")
assert(select(2, kinds.get(3, { Function = "custom" })) == "", "global hidden mode wins over local glyph overrides")
assert(icons.set("ascii"))
assert(picker.entries[1].icon.text == "f")
picker:close()

local completion = require("completion_tools.config").validate({}).menu
local render = require("completion_tools.render")
local candidates = { { source_id = "lsp", item = { label = "function_name", kind = 3 } } }
local visible = render.prepare(candidates, completion, 80)
assert(icons.set("none"))
local hidden = render.prepare(candidates, completion, 80, visible)
for _, column in ipairs(hidden.columns) do
  assert(column.name ~= "kind_icon", "hidden icon column must not retain spacing")
end

local dashboard = require("ui_tools.dashboard")
assert(icons.set("ascii"))
dashboard.open({
  autostart = false,
  header = "",
  footer = "",
  keys = { { key = "f", desc = "Search", icon = "󰈔 ", action = "enew" } },
})
local screen = dashboard.state()
assert(table.concat(api.nvim_buf_get_lines(screen.buf, 0, -1, false)):find("/ Search", 1, true))
assert(icons.set("none"))
assert(not table.concat(api.nvim_buf_get_lines(screen.buf, 0, -1, false)):find("/ Search", 1, true))
dashboard.close()

-- A bufferline consumer needs a real listed editor buffer, not the empty
-- startup placeholder restored after closing the dashboard.
local editor = api.nvim_create_buf(true, false)
api.nvim_set_current_buf(editor)
api.nvim_buf_set_name(editor, vim.fn.tempname() .. ".lua")
vim.bo[editor].filetype = "lua"
local bufferline = require("ui_tools.bufferline")
assert(icons.set("ascii"))
bufferline.setup({ force = true, close_buttons = true, refresh = 0 })
assert(vim.wait(1000, function()
  return bufferline.render():find(".close_click@", 1, true)
end))
assert(icons.set("none"))
assert(vim.wait(1000, function()
  return not bufferline.render():find(".close_click@", 1, true)
end))
bufferline.disable()

local results = require("lsp-tools.results")
results.setup({ auto_preview = false })
local source = api.nvim_get_current_win()
local source_buf = api.nvim_get_current_buf()
api.nvim_buf_set_name(source_buf, "/tmp/icon-consumer.lua")
api.nvim_buf_set_lines(source_buf, 0, -1, false, { "source" })
assert(icons.set("ascii"))
local result = results.open({ { bufnr = source_buf, pos = { 1, 0 }, severity = 1, text = "failure" } })
local rows = table.concat(api.nvim_buf_get_lines(result.out, 0, -1, false), "\n")
assert(rows:find("E failure", 1, true), rows)
assert(icons.set("none"))
rows = table.concat(api.nvim_buf_get_lines(result.out, 0, -1, false), "\n")
assert(not rows:find("E failure", 1, true) and rows:find("failure", 1, true), rows)
results.disable()
api.nvim_set_current_win(source)

local layout = require("notification-tools.layout")
local config = require("notification-tools.config").resolve({ notification = { timestamp = false } })
local notice = { message = "Message", title = "Title", level = 4, count = 1, time = os.time(), markdown = false }
assert(icons.set("ascii"))
local plan = layout.notification(notice, config, 60, 20)
assert(table.concat(plan.lines, "\n"):find("E Title", 1, true))
assert(icons.set("none"))
local hidden_plan = layout.notification(notice, config, 60, 20)
assert(hidden_plan ~= plan and not table.concat(hidden_plan.lines, "\n"):find("E Title", 1, true))
local task =
  { id = "task", title = "Build", source = "", message = "", started = 0, updated = 0, done = true, status = "success" }
assert(icons.set("ascii"))
local progress = layout.progress({ task }, config, 60, 20, nil, 0)
assert(table.concat(progress.lines, "\n"):find("+ Build", 1, true))
assert(icons.set("none"))
local hidden_progress = layout.progress({ task }, config, 60, 20, nil, 0)
assert(hidden_progress ~= progress and not table.concat(hidden_progress.lines, "\n"):find("+ Build", 1, true))
assert(#icons.catalog() == 0)
assert(icons.set("ascii") and #icons.catalog() > 25)
print(
  "shared icons: five real consumers, live cache invalidation, hidden spacing, semantic symbols and inventory passed"
)
