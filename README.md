# theme-tools.nvim

Theme installation and live colorscheme switching for Neovim 0.11+. An independent,
personal Mocha theme is included, with Catppuccin and Dracula as managed sources.
Search themes, inspect a sample window, and apply the one you like.

- Moving through the picker changes only the preview window; the editor keeps its theme.
- Dark and light themes have separate lists; category navigation never previews.
- Enter confirms and remembers your choice for the next startup.
- Escape or Ctrl-C restores the original colorscheme, background, custom
  highlights and terminal palette globals.
- Direct switching, cycling, command completion and a Lua API are included.
- Managed themes download once at fixed revisions and work offline afterward.
- Independent Mocha applies generated highlights directly, without loading Catppuccin.
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
    dracula = { transparent_bg = true },
    default = "theme-tools-mocha",
    themes = {
      "theme-tools-mocha",
      "dracula",
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
fetches the upstream source on the first Catppuccin selection into `stdpath("data")/theme-tools/themes/catppuccin/`
at its pinned commit, adds it to runtimepath, and calls its setup with your
`catppuccin` options. You do not need a separate Catppuccin plugin-manager entry.
Existing checkouts are reused without fetching. Starting with another theme skips
Catppuccin installation, setup, integration detection and compiled-cache checks.
Picker previews and direct `:colorscheme catppuccin-mocha` calls initialize it on
demand, once per setup. `:ThemeToolsInstall` explicitly installs and reconfigures
all enabled managed sources.
With Lazy and `vim.loader`, installed plugins are read from the existing inventory
to resolve Catppuccin integrations without probing unused package managers.
Explicit integration options keep their upstream precedence; other environments
use Catppuccin's detector.

[Dracula](https://github.com/Mofiqul/dracula.nvim) follows the same download and
lazy initialization flow, under `stdpath("data")/theme-tools/themes/dracula/`.
Register `dracula` (or `dracula-soft`) and pass upstream setup options in `dracula`.
Selecting Dracula initializes only its source. Independent Mocha starts without
loading either managed source. Set `dracula = false` to disable this provider.

Keep startup colorscheme selection here: a later `vim.cmd.colorscheme(...)` in
your config would override the restored selection. See [examples/lazy.lua](examples/lazy.lua)
for a complete local setup with selection-tools.

Without a plugin manager, add this directory to `runtimepath`, then call
`require("theme_tools").setup({})`. An empty setup discovers colorschemes on
runtimepath. Register Catppuccin variants explicitly to select them before the
managed source has loaded. Providing `themes` uses that ordered list
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
filtering updates a separate theme sample; Enter applies and saves the theme.
Cancelling leaves the editor unchanged. Existing selection-tools key bindings apply.
`picker.selection` accepts per-picker layout, matcher and key overrides.

## Use

Run `:ThemeTools` and type to filter within the current brightness group. The builtin picker matches every
space-separated word against the name, label and colorscheme, ignoring case.
The selection-tools backend uses its configured matching and key bindings.

| Key / command | Action |
| --- | --- |
| Down / Ctrl-N / Tab | Preview the next match |
| Up / Ctrl-P / Shift-Tab | Preview the previous match |
| Enter | Confirm and save |
| Escape / Ctrl-C | Cancel and restore |
| Ctrl-G | Open the theme category menu; Enter opens a category |
| Ctrl-D / Ctrl-U | Scroll the theme sample (selection-tools inherits its own preview keys) |
| `:ThemeTools catppuccin-latte` | Apply a theme by its registered name |
| `:ThemeToolsNext` / `:ThemeToolsPrev` | Cycle the configured order, wrapping at the ends |

Builtin picker navigation stops at the first and last match. Leaving or closing the
picker cancels it. The picker fits terminal resizes and closes when space is too
small. No global mappings are installed.

The preview contains syntax-colored Lua, search matches, visual selections,
diagnostics, completion items, diff colors, a statusline and a floating-window
sample. Theme code runs in a disposable background Neovim; its highlights are
applied only in the sample window's namespace. The editor, picker, background
mode, terminal palette and saved choice remain unchanged until Enter. Preview
requests are coalesced, stale results are ignored, and the worker closes with
the picker. It adds no process or preview modules to startup.

Transparent themes use a solid canvas inside the sample so their colors remain
visible against both dark and light editor themes. Enter still applies the
theme's actual transparency. On very small screens the sample may be hidden;
confirmation remains available without a preview.

Set `picker.preview_mode = "live"` to restore editor-wide previews. The default is
`"window"`. Post-ColorScheme custom highlights can be mirrored in the worker with
`picker.preview_after = function(theme) ... end`; your host autocommands are not
run during browsing. Lua configuration closures and their upvalues are copied to
the worker. Nontransferable values show an error in the pane; Enter still tries
the actual theme in the editor.

The picker opens the active theme's **Dark** or **Light** list. Moving or searching
inside one list cannot select a theme from the other. Press **Ctrl-G**, choose a
category, then press Enter to browse it. Merely highlighting a category keeps the
editor palette unchanged. Cancelling preserves the theme active when the
picker opened; category selection is never saved as a theme choice.

Independent Mocha, the four Catppuccin variants, Dracula and Dracula Soft have
built-in background metadata. Give other registered themes `background = "dark"`
or `"light"` to classify them. Unknown themes appear under **Unclassified** and can
also be inspected safely in the sample. In legacy live mode, unknown themes apply
only on Enter and empty searches retain the last preview. Set
`picker.group_by_background = false` to use a combined list; preview isolation
is controlled separately by `picker.preview_mode`.

For installation paths, theme options, custom labels, light/dark variants, persistence and
events, see the [configuration reference](doc/theme-tools.txt) or
`:help theme-tools` after your plugin manager generates helptags.

## Development

### Personal Mocha

`theme-tools-mocha` derives from Catppuccin Mocha at
`edefef779ab08ce1a4a404713e3012b0d202bd35`, with the current personal highlight
overrides and a fixed set of plugin integrations. It has transparent editor and
floating backgrounds. It is maintained independently: Catppuccin setup options,
automatic integration detection and upstream updates do not change this theme.
The original variants keep their own Catppuccin configuration.

- Edit `lua/theme_tools/mocha/palette.lua` for colors.
- Edit `lua/theme_tools/mocha/groups/{editor,syntax,integrations,custom}.lua`
  for highlight definitions. Custom groups replace earlier definitions.
- Run `nvim --headless -u NONE -l scripts/build_mocha.lua` and commit both the
  editable source and `colors/theme-tools-mocha.lua`.
- Use `require("theme_tools.mocha.palette")` for statusline palette references.

The generator runs offline without upstream installed. Its deterministic output
contains direct `nvim_set_hl` calls with merged overrides and literal colors.
Startup reads only that file; it never loads the source groups or generator.
Portable Lua source is committed; Neovim's `vim.loader` can cache local bytecode.
Catppuccin's MIT notice is retained in [LICENSE.catppuccin](LICENSE.catppuccin).

### Validation

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
`tests/real_mocha.lua` compares all independent highlight groups and terminal
colors against the configured original Mocha. Run it inside the complete personal
configuration, after theme-tools setup.
