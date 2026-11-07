# theme-tools.nvim

The selection-tools theme and icon-provider pickers use text components and inherit `component_defaults.text`. Explicit `picker.selection.components` lists, including `{}` and `false`, remain supported.

Theme selection, independent color palettes and shared icon display.

## Features

- Preview themes without changing the source editor until confirmation.
- Remember dark/light selections and restore cancelled previews.
- Share semantic palettes and icon providers with other plugins.

## Requirements

Neovim **0.11+**. No required plugin dependency for built-in themes and picker. Managed external themes/icons are installed explicitly.

## Installation

With lazy.nvim:

```lua
{
  "Jacky-Lzx/theme-tools.nvim",
  main = "theme_tools",
  opts = { default = "theme-tools-mocha" },
}
```

Or put this repository and its required dependencies on `runtimepath`, then call:

```lua
require("theme_tools").setup({ default = "theme-tools-mocha" })
```

## Usage

```vim
:ThemeTools
:ThemeToolsInfo
```

## Documentation

- [Complete reference](doc/theme-tools.txt) — `:help theme-tools`.
- [Workflow and integration guide](doc/guide.md).

## Development

Run from the repository root:

```sh
python3 tests/run.py unit --filter docs
python3 tests/run.py default
```

See [the test workflow](tests/README.md) for dependencies, optional suites and
retained failure evidence. Local development overrides belong in your package
manager configuration; public installation uses the repository above.

[License](LICENSE).
