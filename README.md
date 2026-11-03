# theme-tools.nvim

Live colorscheme switching for Neovim 0.11+. Search installed themes, preview
them across the editor, and keep the one you like. No runtime dependencies.

- Moving through the picker immediately applies the highlighted theme.
- Enter confirms and remembers your choice for the next startup.
- Escape or Ctrl-C restores the original colorscheme, background, custom
  highlights and terminal palette globals.
- Direct switching, cycling, command completion and a Lua API are included.

## Install

For a local checkout with lazy.nvim:

```lua
{
  dir = vim.fn.expand("~/Documents/Github/nvim_plugins/theme-tools.nvim"),
  main = "theme_tools",
  lazy = false,
  priority = 1000,
  dependencies = {
    { "catppuccin/nvim", name = "catppuccin", opts = {} },
  },
  opts = {
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

Install theme plugins through your plugin manager. Theme Tools uses their normal
colorscheme names; the example uses [Catppuccin's four flavours](https://github.com/catppuccin/nvim#usage).
Configure theme-specific options in the dependency's `opts`. Keep startup
colorscheme selection here: a later `vim.cmd.colorscheme(...)` in your config
would override the restored selection. See [examples/lazy.lua](examples/lazy.lua)
for additional cycling mappings.

Without a plugin manager, add this directory and your theme plugins to
`runtimepath`, then call `require("theme_tools").setup({})`. An empty setup
discovers colorschemes on the current runtimepath. Providing `themes` uses that
ordered list instead; add `discover = true` to append other installed schemes.
Explicit names also work with lazy.nvim's colorscheme autoloading.

## Use

Run `:ThemeTools` and type to filter. Filtering is case-insensitive and matches
every space-separated word against the name, label and colorscheme.

| Key / command | Action |
| --- | --- |
| Down / Ctrl-N / Tab | Preview the next match |
| Up / Ctrl-P / Shift-Tab | Preview the previous match |
| Enter | Confirm and save |
| Escape / Ctrl-C | Cancel and restore |
| `:ThemeTools catppuccin-latte` | Apply a theme by its registered name |
| `:ThemeToolsNext` / `:ThemeToolsPrev` | Cycle the configured order, wrapping at the ends |

Picker navigation stops at the first and last match. Leaving or closing the
picker cancels it. The picker fits terminal resizes and closes when space is too
small. No global mappings are installed.

For custom labels, light/dark variants, lazy loading callbacks, persistence and
events, see the [configuration reference](doc/theme-tools.txt) or
`:help theme-tools` after your plugin manager generates helptags.

## Development

Run `sh tests/run.sh` with Neovim, Python 3 and StyLua. Tests exercise failure
rollback, persistence, attached-UI redraws and a real terminal session, including
native Escape handling and resize. To test an installed Catppuccin checkout too:

```sh
THEME_TOOLS_CATPPUCCIN=/path/to/catppuccin sh tests/run.sh
```
