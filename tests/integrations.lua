vim.opt.runtimepath:prepend(vim.fn.getcwd())
local integrations = require("theme_tools.providers.integrations")
local original_lazy = package.loaded["lazy.core.config"]
local original_loader = package.loaded["vim.loader"]
local original_path, original_cpath = package.path, package.cpath
package.path, package.cpath = "", ""
package.loaded["lazy.core.config"] = { plugins = { ["alpha.nvim"] = {}, ["mini.ai"] = {} } }
local found = {}
package.loaded["vim.loader"] = {
  enabled = true,
  find = function()
    return found
  end,
}
package.preload["catppuccin.utils.integration_mappings"] = function()
  return { ["alpha.nvim"] = "alpha", ["mini.nvim"] = "mini", ["native.nvim"] = "native" }
end
local has_pack = vim.fn.has("nvim-0.12.0") == 1
local pack_get = has_pack and vim.pack.get
local native, pack_reads = {}, 0
if has_pack then
  vim.pack.get = function(_, opts)
    assert(opts.info == false, "native package detection must not ask for Git info")
    pack_reads = pack_reads + 1
    return native
  end
end
local function catppuccin()
  return {
    default_options = {
      auto_integrations = true,
      integrations = { alpha = { style = "default" }, mini = false, manual = false },
    },
  }
end
local opts = { integrations = { alpha = { style = "custom" }, manual = true } }
local original = vim.deepcopy(opts)
local theme = catppuccin()
local original_defaults = vim.deepcopy(theme.default_options)
local resolved = integrations.resolve(theme, opts)
assert(resolved.auto_integrations == false)
assert(resolved.integrations.alpha.enabled and resolved.integrations.alpha.style == "custom")
assert(resolved.integrations.mini == false, "upstream defaults retain precedence over detection")
assert(resolved.integrations.manual == true)
assert(vim.deep_equal(opts, original), "resolving must not mutate user options")
assert(vim.deep_equal(theme.default_options, original_defaults), "resolving must not mutate upstream defaults")
assert(not package.loaded.pckr and not package.loaded["catppuccin.lib.detect_integrations"])
-- Explicit false wins over a detected integration, and new inventory is read.
opts.integrations.alpha = false
resolved = integrations.resolve(theme, opts)
assert(resolved.integrations.alpha == false)
package.loaded["lazy.core.config"].plugins["alpha.nvim"] = nil
resolved = integrations.resolve(theme, {})
assert(not resolved.integrations.alpha.enabled, "removed plugins must not be retained")
if has_pack then
  native = { { spec = { name = "native.nvim" } } }
  resolved = integrations.resolve(catppuccin(), {})
  assert(resolved.integrations.native == true, "native packages must be automatically recognized")
end
-- Opting out and unsupported managers must leave normal upstream setup intact.
local explicit = { auto_integrations = false }
local before = pack_reads
assert(integrations.resolve(catppuccin(), explicit) == explicit and before == pack_reads)
package.loaded["vim.loader"].enabled = false
assert(integrations.resolve(catppuccin(), opts) == opts)
package.loaded["vim.loader"].enabled = true
package.loaded["lazy.core.config"].plugins["pckr.nvim"] = {}
assert(integrations.resolve(catppuccin(), opts) == opts)
package.loaded["lazy.core.config"].plugins["pckr.nvim"] = nil
found = { { modpath = "/fixture/pckr/init.lua" } }
assert(integrations.resolve(catppuccin(), opts) == opts)
found = {}
package.preload.pckr = function()
  error("must not load pckr during resolution")
end
assert(integrations.resolve(catppuccin(), opts) == opts)
package.preload.pckr = nil
if has_pack then
  native = { { spec = { name = "pckr.nvim" } } }
  assert(integrations.resolve(catppuccin(), opts) == opts)
  vim.pack.get = function()
    error("native manager unavailable")
  end
  assert(integrations.resolve(catppuccin(), opts) == opts)
end
package.loaded["lazy.core.config"] = nil
assert(integrations.resolve(catppuccin(), opts) == opts)
package.loaded["lazy.core.config"], package.loaded["vim.loader"] = original_lazy, original_loader
package.path, package.cpath = original_path, original_cpath
if has_pack then
  vim.pack.get = pack_get
end
-- Managed sources must participate even without a package manager or module load.
local original_icons = package.loaded["theme_tools.icons"]
package.loaded["theme_tools.icons"] = {
  list = function()
    return { { name = "mini" } }
  end,
}
local managed = integrations.with_managed_icons(catppuccin(), {})
assert(managed.integrations.mini.enabled)
assert(not package.loaded["mini.icons"], "integration detection eagerly loaded icons")
for _, mini in ipairs({ false, true, { enabled = false }, { indentscope_color = "blue" } }) do
  local original_options = { integrations = { mini = mini } }
  local copy = vim.deepcopy(original_options)
  managed = integrations.with_managed_icons(catppuccin(), original_options)
  assert(vim.deep_equal(original_options, copy), "managed detection mutated options")
  if type(mini) == "table" then
    assert(managed.integrations.mini.enabled == (mini.enabled ~= false))
    assert(managed.integrations.mini.indentscope_color == mini.indentscope_color)
  else
    assert(managed.integrations.mini == mini)
  end
end
local disabled = { auto_integrations = false }
assert(integrations.with_managed_icons(catppuccin(), disabled) == disabled)
package.loaded["theme_tools.icons"] = original_icons
print("integrations: inventory, native packages, option precedence and upstream fallbacks passed")
