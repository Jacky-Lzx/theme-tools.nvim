vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname()
local repository = root .. "/source"
vim.fn.mkdir(repository .. "/lua", "p")
vim.fn.writefile({
  "return {setup=function(opts) vim.wait(opts.delay or 0); vim.g.icon_worker_setup=true; vim.api.nvim_set_hl(0,'PreviewLua',{fg='#123abc'}) end,",
  "get_icon=function() return 'λ','PreviewLua' end, get_icon_by_filetype=function() return 'λ','PreviewLua' end,",
  "get_icon_by_operating_system=function() return 'λ','PreviewLua' end}",
}, repository .. "/lua/nvim-web-devicons.lua")
local function git(args)
  local result = vim.system(vim.list_extend({ "git" }, args), { cwd = repository, text = true }):wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end
git({ "init", "--quiet", "--template=" })
git({ "add", "." })
git({
  "-c",
  "user.name=Fixture",
  "-c",
  "user.email=fixture@example.invalid",
  "-c",
  "commit.gpgsign=false",
  "commit",
  "--quiet",
  "-m",
  "icons",
})
local themes = require("theme_tools")
themes.setup({ persist = false, catppuccin = false, dracula = false, themes = { "habamax" }, default = "habamax" })
local icons = themes.icons
icons.setup({
  default = "ascii",
  persist = true,
  state_file = root .. "/selection.json",
  install = { root = root .. "/managed", timeout = 3000 },
  devicons = { delay = 150 },
  sources = {
    devicons = { url = repository, commit = git({ "rev-parse", "HEAD" }) },
    mini = { url = root .. "/missing" },
  },
})
assert(icons.set("ascii"))
local saved = table.concat(vim.fn.readfile(root .. "/selection.json"))
local colors = require("theme_tools.colors").snapshot()
local events = 0
icons.on_change("test-preview", function()
  events = events + 1
end)
local function viewer()
  return require("theme_tools.preview").new({
    worker = "theme_tools.icons.preview_worker",
    options = icons._preview_options(),
  })
end
local view = viewer()
local frame, failure
view:show({ name = "devicons" }, function(value, err)
  frame, failure = value, err
end)
assert(
  vim.wait(5000, function()
    return frame ~= nil or failure ~= nil
  end),
  "icon worker did not respond"
)
assert(not failure, failure)
assert(frame.name == "devicons" and frame.count >= 100)
assert(vim.deep_equal(
  vim.tbl_map(function(group)
    return group.title
  end, frame.groups),
  { "Files", "Directories", "Diagnostics", "Git", "Tasks", "UI", "LSP types", "Operating systems" }
))
assert(#frame.groups[5].entries == 5, "task preview must include running, stopping and terminal states")
assert(frame.groups[1].entries[1].icon == "λ" and frame.highlights.PreviewLua.fg == 0x123abc)
assert(not package.loaded["nvim-web-devicons"] and not vim.g.icon_worker_setup, "provider setup ran in host")
assert(icons.current() == "ascii" and events == 1)
assert(vim.deep_equal(colors, require("theme_tools.colors").snapshot()), "preview changed host colors")
vim.o.columns, vim.o.lines = 120, 40
local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_open_win(buf, false, { relative = "editor", row = 0, col = 0, width = 100, height = 20 })
require("theme_tools.icons.sample").draw(buf, win, { name = "devicons" }, frame)
local ns = vim.api.nvim_get_hl_ns({ winid = win })
assert(ns > 0 and vim.api.nvim_get_hl(ns, { name = "PreviewLua", link = false }).fg == 0x123abc)
local contents = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
for _, word in ipairs({ "init.lua", "main.rs", "Directories", "Diagnostics", "Git", "LSP types", "Operating systems" }) do
  assert(contents:find(word, 1, true), word)
end
vim.api.nvim_win_close(win, true)
vim.api.nvim_buf_delete(buf, { force = true })
-- A later request owns the callback even when an earlier provider setup is slow.
view:close()
view = viewer()
local stale, latest = 0, nil
view:show({ name = "devicons" }, function(value, err)
  if value or err then
    stale = stale + 1
  end
end)
vim.wait(40)
view:show({ name = "none" }, function(value, err)
  assert(not err, err)
  latest = value
end)
assert(vim.wait(5000, function()
  return latest ~= nil
end))
assert(latest.name == "none" and stale == 0)
for _, group in ipairs(latest.groups) do
  for _, entry in ipairs(group.entries) do
    assert(entry.icon == "")
  end
end
local failed
view:show({ name = "mini" }, function(value, err)
  if err then
    failed = err
  end
  assert(value == nil)
end)
assert(
  vim.wait(5000, function()
    return failed ~= nil
  end),
  "missing provider must report a preview error"
)
local job = view.job
view:close()
assert(vim.fn.jobwait({ job }, 2000)[1] ~= -1, "icon worker leaked")
assert(table.concat(vim.fn.readfile(root .. "/selection.json")) == saved and icons.current() == "ascii" and events == 1)
assert(vim.deep_equal(colors, require("theme_tools.colors").snapshot()), "sample colors escaped their namespace")
vim.fn.delete(root, "rf")
print(
  "icon preview: 100+ real lookups, private highlights, state isolation, stale requests, errors and worker cleanup passed"
)
