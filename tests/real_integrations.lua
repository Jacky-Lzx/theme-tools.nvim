-- Run inside the actual configuration, after theme-tools has initialized.
local cat = require("catppuccin")
assert(not package.loaded["catppuccin.lib.detect_integrations"], "startup used the slow detector")
local actual = vim.deepcopy(cat.options.integrations)
local plugin = require("lazy.core.config").plugins["theme-tools.nvim"]
local opts = require("lazy.core.plugin").values(plugin, "opts", false).catppuccin
local function definitions()
  local result, previous = {}, cat.flavour
  for _, flavour in ipairs({ "mocha", "latte", "frappe", "macchiato" }) do
    cat.flavour = flavour
    result[flavour] = vim.deepcopy(require("catppuccin.lib.mapper").apply(flavour))
  end
  cat.flavour = previous
  return result
end
local rendered = definitions()
cat.setup(require("theme_tools.providers.integrations").with_managed_icons(cat, vim.deepcopy(opts)))
assert(vim.deep_equal(actual, cat.options.integrations), "fast integrations differ from upstream")
assert(vim.deep_equal(rendered, definitions()), "fast theme definitions differ from upstream")
assert(require("theme_tools").install())
