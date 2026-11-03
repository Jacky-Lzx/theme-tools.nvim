# theme-tools.nvim

Theme installation and live colorscheme switching for Neovim 0.11+. Catppuccin
is included as a managed theme: the plugin downloads, loads and configures it.
Search themes, preview them across the editor, and keep the one you like.

- Moving through the picker immediately applies the highlighted theme.
- Enter confirms and remembers your choice for the next startup.
- Escape or Ctrl-C restores the original colorscheme, background, custom
  highlights and terminal palette globals.
- Direct switching, cycling, command completion and a Lua API are included.
- Catppuccin downloads once at a fixed revision and works offline afterward.
- Restoring an unchanged saved choice skips writing state; picker UI loads on demand.

## Install

For a local checkout with lazy.nvim:

```lua
{
  dir = vim.fn.expand("~/Documents/Github/nvim_plugins/theme-tools.nvim"),
  main = "theme_tools",
  lazy = false,
  priority = 1000,
  opts = {
    catppuccin = { transparent_background = true },
    default = "catppuccin-mocha",
    themes = {
      "catppuccin-latte",
      "catppuccin-frappe",
      "catppuccin-macchiato",
      "catppuccin-mocha",
    },
  },
  keys = {
    { "<leader>ut", "<cmd>ThemeTools<cr>", desc = "Preview themes" },
  },
}
```

Git and network access are needed for the first Catppuccin download. Theme Tools
fetches the upstream source into `stdpath("data")/theme-tools/themes/catppuccin/`
at its pinned commit, adds it to runtimepath, and calls its setup with your
`catppuccin` options. You do not need a separate Catppuccin plugin-manager entry.
Existing checkouts are reused without fetching on subsequent startups.

Keep startup colorscheme selection here: a later `vim.cmd.colorscheme(...)` in
your config would override the restored selection. See [examples/lazy.lua](examples/lazy.lua)
for a complete local setup with selection-tools.

Without a plugin manager, add this directory to `runtimepath`, then call
`require("theme_tools").setup({})`. An empty setup installs Catppuccin and
discovers colorschemes on runtimepath. Providing `themes` uses that ordered list
instead; add `discover = true` to append other installed schemes. Other theme
plugins already on runtimepath remain supported.

Set `catppuccin = false` to disable managed Catppuccin installation and setup.
`:ThemeToolsInstall` retries installation after a failed download. Downloads use
a temporary checkout, verify the pinned revision, then publish the complete
installation. Failed downloads leave the current palette intact and clean up
their temporary files. The default download timeout is 30 seconds in total.

### selection-tools.nvim

Use your existing selection-tools layout, matching and navigation for themes:

```lua
require("theme_tools").setup({
  picker = { backend = "selection_tools" },
  themes = { "catppuccin-mocha", "catppuccin-latte", "habamax" },
})
```

Install `selection-tools.nvim` as a dependency, using a version with the
`on_change` callback. In a local lazy.nvim setup, add its checkout to `dependencies` (see
[examples/lazy.lua](examples/lazy.lua)). `:ThemeTools` then uses its compact
single-selection picker, initially highlighting the active theme. Moving or
filtering previews colors across the editor; Enter commits, and cancelling
restores the opening palette. Existing selection-tools key bindings apply.
`picker.selection` accepts per-picker layout, matcher and key overrides.

## Use

Run `:ThemeTools` and type to filter. The builtin picker matches every
space-separated word against the name, label and colorscheme, ignoring case.
The selection-tools backend uses its configured matching and key bindings.

| Key / command | Action |
| --- | --- |
| Down / Ctrl-N / Tab | Preview the next match |
| Up / Ctrl-P / Shift-Tab | Preview the previous match |
| Enter | Confirm and save |
| Escape / Ctrl-C | Cancel and restore |
| `:ThemeTools catppuccin-latte` | Apply a theme by its registered name |
| `:ThemeToolsNext` / `:ThemeToolsPrev` | Cycle the configured order, wrapping at the ends |

Builtin picker navigation stops at the first and last match. Leaving or closing the
picker cancels it. The picker fits terminal resizes and closes when space is too
small. No global mappings are installed.

For installation paths, theme options, custom labels, light/dark variants, persistence and
events, see the [configuration reference](doc/theme-tools.txt) or
`:help theme-tools` after your plugin manager generates helptags.

## Development

Run `sh tests/run.sh` with Neovim, Python 3 and StyLua. Tests exercise failure
rollback, persistence, attached-UI redraws and a real terminal session, including
native Escape handling and resize. Installer tests use real local Git repositories
and run offline. To test an installed Catppuccin checkout too:

```sh
THEME_TOOLS_CATPPUCCIN=/path/to/catppuccin sh tests/run.sh
```

The selection-tools integration tests use the actual sibling checkout by
default; set `THEME_TOOLS_SELECTION=/path/to/selection-tools.nvim` to override it.
`python3 tests/configured_tui.py` checks the installed personal Neovim configuration
with temporary state, cache and lock files; set `THEME_TOOLS_NVIM_CONFIG` to its path.
