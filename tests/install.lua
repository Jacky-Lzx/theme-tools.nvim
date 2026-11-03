vim.opt.runtimepath:prepend(vim.fn.getcwd())
local installer = require("theme_tools.install")
local root = vim.fn.tempname()
local repository = root .. "/source"
vim.fn.mkdir(repository .. "/lua/catppuccin", "p")
vim.fn.mkdir(repository .. "/lua/dracula", "p")
vim.fn.mkdir(repository .. "/colors", "p")
vim.fn.writefile({
  "return { setup = function(opts) vim.g.fixture_options = opts; vim.g.fixture_setups = (vim.g.fixture_setups or 0) + 1 end }",
}, repository .. "/lua/catppuccin/init.lua")
vim.fn.writefile({ 'vim.g.colors_name = "catppuccin-mocha"' }, repository .. "/colors/catppuccin-mocha.lua")
vim.fn.writefile({
  "return {setup=function(opts) vim.g.dracula_options=opts; vim.g.dracula_setups=(vim.g.dracula_setups or 0)+1 end}",
}, repository .. "/lua/dracula/init.lua")
vim.fn.writefile({
  'vim.g.colors_name="dracula"',
  'vim.g.terminal_color_background="#282a36"',
}, repository .. "/colors/dracula.lua")
local function git(args)
  local result = vim.system(vim.list_extend({ "git" }, args), { cwd = repository, text = true }):wait()
  assert(result.code == 0, result.stderr)
  return vim.trim(result.stdout)
end
git({ "init", "--quiet", "--template=" })
git({ "add", "." })
git({
  "-c",
  "user.name=Theme fixture",
  "-c",
  "user.email=fixture@example.invalid",
  "-c",
  "commit.gpgsign=false",
  "commit",
  "--quiet",
  "-m",
  "fixture",
})
local source = {
  name = "catppuccin",
  url = repository,
  commit = git({ "rev-parse", "HEAD" }),
  entrypoint = "lua/catppuccin/init.lua",
}
local opts = { root = root .. "/managed", timeout = 5000 }
local path, err = installer.ensure(source, opts)
assert(path, err)
assert(vim.fn.readfile(path .. "/.theme-tools-commit")[1] == source.commit)
assert(vim.fn.filereadable(path .. "/" .. source.entrypoint) == 1)
-- An installed revision must be reusable with neither a reachable remote nor Git.
local environment_path = vim.env.PATH
vim.env.PATH = ""
local offline = vim.tbl_extend("force", source, { url = root .. "/unreachable" })
assert(installer.ensure(offline, opts) == path)
vim.env.PATH = environment_path
local failed = vim.tbl_extend("force", offline, { name = "retry" })
assert(not installer.ensure(failed, opts))
assert(vim.fn.glob(opts.root .. "/retry/*", false, true)[1] == nil, "failed installs must clean temporary checkouts")
failed.url = repository
assert(installer.ensure(failed, opts))
local missing = vim.tbl_extend("force", source, { name = "missing", entrypoint = "does-not-exist.lua" })
assert(not installer.ensure(missing, opts))
assert(vim.fn.glob(opts.root .. "/missing/*", false, true)[1] == nil)
-- Bound hung Git processes too, not just failed downloads.
local wrapper = root .. "/slow-bin"
vim.fn.mkdir(wrapper, "p")
vim.fn.writefile({ "#!/bin/sh", "exec " .. vim.fn.shellescape(vim.fn.exepath("sleep")) .. " 1" }, wrapper .. "/git")
assert(vim.uv.fs_chmod(wrapper .. "/git", 493))
vim.env.PATH = wrapper
local timed_path, timed_error = installer.ensure(vim.tbl_extend("force", source, { name = "timeout" }), {
  root = opts.root,
  timeout = 20,
})
vim.env.PATH = environment_path
assert(not timed_path and timed_error:find("timed out", 1, true), timed_error)
assert(vim.fn.glob(opts.root .. "/timeout/*", false, true)[1] == nil)
local incomplete = vim.tbl_extend("force", source, { name = "incomplete" })
vim.fn.mkdir(opts.root .. "/incomplete/" .. source.commit, "p")
assert(not installer.ensure(incomplete, opts))
assert(
  vim.fn.isdirectory(opts.root .. "/incomplete/" .. source.commit) == 1,
  "do not overwrite incomplete installations"
)
-- Wire the actual provider to the local Git fixture and exercise normal setup.
local provider = require("theme_tools.providers.catppuccin")
provider.source = source
local themes = require("theme_tools")
themes.setup({
  persist = false,
  install = opts,
  catppuccin = { transparent_background = true },
  dracula = false,
  themes = { "theme-tools-mocha", "catppuccin-mocha" },
  default = "theme-tools-mocha",
})
assert(vim.g.colors_name == "theme-tools-mocha")
assert(not package.loaded.catppuccin and not vim.g.fixture_options)
assert(not vim.tbl_contains(vim.opt.runtimepath:get(), path))
assert(themes.set("catppuccin-mocha"))
assert(vim.g.fixture_options.transparent_background)
assert(vim.g.colors_name == "catppuccin-mocha")
assert(themes.current() == "catppuccin-mocha")
assert(vim.tbl_contains(vim.opt.runtimepath:get(), path))
assert(vim.fn.exists(":ThemeToolsInstall") == 2)
assert(themes.set("catppuccin-mocha"))
assert(vim.g.fixture_setups == 1, "repeat previews must reuse initialized Catppuccin")
assert(themes.install())
assert(vim.g.fixture_setups == 2, "explicit install must reconfigure the source")
local dracula = require("theme_tools.providers.dracula")
dracula.source = vim.tbl_extend("force", source, { name = "dracula", entrypoint = "lua/dracula/init.lua" })
themes.setup({
  persist = false,
  install = opts,
  catppuccin = false,
  dracula = { transparent_bg = true },
  themes = { "theme-tools-mocha", "dracula" },
  default = "theme-tools-mocha",
})
assert(not package.loaded.dracula and not vim.g.dracula_options)
assert(themes.set("dracula"))
assert(vim.g.dracula_options.transparent_bg and vim.g.dracula_setups == 1)
assert(vim.g.colors_name == "dracula" and vim.o.background == "dark")
assert(vim.g.terminal_color_background == "#282a36")
vim.env.PATH = ""
assert(themes.set("theme-tools-mocha"))
assert(vim.g.terminal_color_background == nil)
assert(themes.set("dracula"))
assert(vim.g.dracula_setups == 1)
assert(themes.install("dracula"))
vim.env.PATH = environment_path
assert(vim.g.dracula_setups == 2)
themes.setup({ persist = false, catppuccin = false, dracula = false, themes = { "habamax" } })
assert(themes.install())
vim.opt.runtimepath:remove(path)
vim.opt.runtimepath:remove(opts.root .. "/dracula/" .. source.commit)
vim.fn.delete(root, "rf")
print("managed themes: Git download, pinned revision, offline reuse, cleanup, retry and provider startup passed")
