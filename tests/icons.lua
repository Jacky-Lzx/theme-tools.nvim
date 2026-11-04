vim.opt.runtimepath:prepend(vim.fn.getcwd())
local themes = require("theme_tools")
local icons = themes.icons
local root = vim.fn.tempname()
local repository = root .. "/source"
vim.fn.mkdir(repository .. "/lua/mini", "p")
vim.fn.writefile({
  "return {setup=function(opts) vim.g.icon_opts=opts end, get=function(category,name)",
  "if name=='broken' then error('broken provider') end",
  "return 'M', 'Directory', name=='unknown' end}",
}, repository .. "/lua/mini/icons.lua")
vim.fn.writefile({
  "return {setup=function(opts) vim.g.devicon_opts=opts end, refresh=function() vim.g.icon_refresh=(vim.g.icon_refresh or 0)+1 end,",
  "get_icon=function(name,ext) vim.g.icon_lookup={name or '',ext or ''}; if ext=='lua' then return 'D','DevIconLua' end end,",
  "get_icon_by_filetype=function(name) if name=='lua' then return 'T','DevIconLua' end end,",
  "get_icon_by_operating_system=function(name) if name=='linux' then return 'L','Normal' end end}",
}, repository .. "/lua/nvim-web-devicons.lua")
local function git(args)
  local result = vim.system(vim.list_extend({ "git" }, args), { cwd = repository, text = true }):wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end
local function commit()
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
    "fixture",
  })
  return git({ "rev-parse", "HEAD" })
end
git({ "init", "--quiet", "--template=" })
local first = commit()
local opts = {
  state_file = root .. "/state/icons.json",
  install = { root = root .. "/managed", timeout = 5000 },
  sources = {
    mini = { url = repository, commit = first, ref = "HEAD" },
    devicons = { url = repository, commit = first, ref = "HEAD" },
  },
}
local warnings = {}
vim.notify = function(message)
  warnings[#warnings + 1] = message
end
themes.setup({ persist = false, catppuccin = false, dracula = false, icons = opts })
assert(icons == require("theme_tools.icons"))
assert(icons.current() == "devicons")
assert(not package.loaded["nvim-web-devicons"] and not package.loaded["mini.icons"])
assert(vim.fn.isdirectory(opts.install.root) == 0, "setup must not download icons")
assert(vim.fn.exists(":ThemeToolsIcons") == 2 and vim.fn.exists(":ThemeToolsIconsUpdate") == 2)
assert(vim.tbl_contains(vim.fn.getcompletion("ThemeToolsIcons mi", "cmdline"), "mini"))
local changes = {}
icons.on_change("consumer", function(value)
  changes[#changes + 1] = value.name
  value.name = "mutated"
end)
assert(changes[1] == "devicons" and icons.current() == "devicons")
assert(icons.set("ascii"))
assert(icons.get("file", "init.lua") == "f")
assert(icons.get("diagnostic", "error") == "E")
assert(icons.get("directory", "src") == "d")
assert(icons.get("lsp", "Function") == "F")
assert(icons.set("none"))
assert(icons.get("file", "init.lua") == "")
assert(icons.next() and icons.current() == "mini")
local glyph, hl, fallback = icons.get("file", "init.lua")
assert(glyph == "M" and hl == "Directory" and not fallback)
assert(select(3, icons.get("file", "unknown")))
assert(icons.get("file", "broken") ~= nil, "provider exceptions must fall back")
assert(icons.prev() and icons.current() == "none")
assert(icons.set("devicons"))
assert(icons.get("file", "/project/init.lua") == "D")
assert(vim.deep_equal(vim.g.icon_lookup, { "init.lua", "lua" }))
assert(icons.get("filetype", "lua") == "T")
assert(icons.get("os", "linux") == "L")
assert(icons.get("extension", "lua") == "D")
assert(icons.get("diagnostic", "error") == "")
glyph, hl, fallback = icons.get("file", "unknown.zzz")
assert(glyph ~= "" and hl == "Normal" and fallback)
local count = #changes
vim.cmd.colorscheme("habamax")
assert(#changes == count + 1 and vim.g.icon_refresh == 1, "theme changes must refresh consumers/providers")
icons.off_change("consumer")
icons.set("ascii")
assert(#changes == count + 1)
local stale = icons.on_change("same", function() end)
local calls = 0
icons.on_change("same", function()
  calls = calls + 1
end)
stale()
icons.set("none")
assert(calls == 2, "old unsubscribe must not remove replacement")
icons.off_change("same")
assert(not icons.set("unknown") and not icons.update("unknown"))
-- Persist independently from theme selection, including a hidden selection.
opts.persist = true
icons.setup(opts)
assert(icons.set("none"))
icons.setup(opts)
assert(icons.current() == "none")
assert(require("theme_tools.state").read(opts.state_file) == "none")
-- Immutable install/update, offline reuse, failed update retains its old lock.
assert(icons.install())
vim.fn.writefile({ "second" }, repository .. "/version")
local second = commit()
assert(icons.update("devicons"))
local revision = opts.install.root .. "/nvim-web-devicons/revision.json"
assert(require("theme_tools.state").read(revision) == second)
assert(vim.fn.filereadable(opts.install.root .. "/nvim-web-devicons/" .. first .. "/lua/nvim-web-devicons.lua") == 1)
assert(vim.fn.filereadable(opts.install.root .. "/nvim-web-devicons/" .. second .. "/lua/nvim-web-devicons.lua") == 1)
git({ "rm", "--quiet", "lua/nvim-web-devicons.lua" })
commit()
assert(not icons.update("devicons"))
assert(require("theme_tools.state").read(revision) == second)
local environment = vim.env.PATH
vim.env.PATH = ""
assert(icons.install("devicons"), "installed updated revisions must work offline")
vim.env.PATH = environment
-- A saved ID is data, and cannot load an arbitrary provider/module.
vim.fn.writefile({ '{"name":"unregistered"}' }, opts.state_file)
icons.setup(opts)
assert(icons.current() == "devicons")
opts.overrides = { diagnostic = { error = { icon = "!", hl = "DiagnosticError" } } }
icons.setup(opts)
assert(icons.get("diagnostic", "error") == "!")
icons.set("none")
assert(icons.get("diagnostic", "error") == "")
assert(not pcall(icons.get, "invalid", "x"))
assert(not pcall(icons.setup, { providers = {} }))
assert(not pcall(icons.setup, { providers = { "none", "none" }, default = "none" }))
assert(not pcall(icons.setup, { sources = { mini = { name = "unsafe" } } }))
assert(not pcall(icons.setup, { overrides = { file = { bad = {} } } }))
-- Lazy download failure uses a usable fallback, warns once, and can retry.
opts.persist, opts.default, opts.overrides = false, "mini", {}
opts.install.root = root .. "/retry"
opts.sources.mini.url = root .. "/unreachable"
icons.setup(opts)
local before = #warnings
assert(icons.get("file", "a.lua") ~= "")
assert(icons.get("file", "a.lua") ~= "")
assert(#warnings == before + 1)
assert(not icons.set("mini"))
opts.sources.mini.url = repository
icons.setup(opts)
assert(icons.set("mini"))
vim.fn.delete(root, "rf")
print("icons: unified lookup, subscriptions, persistence, installs, updates, offline reuse and recovery passed")
