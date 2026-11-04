#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_root=$(mktemp -d "${TMPDIR:-/tmp}/theme-tools-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
export XDG_STATE_HOME="$test_root/state" XDG_CACHE_HOME="$test_root/cache" XDG_DATA_HOME="$test_root/data"
export NVIM_LOG_FILE="$test_root/nvim.log" PYTHONDONTWRITEBYTECODE=1
export NVIM_BIN="${NVIM_BIN:-nvim}"
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/core.lua
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/install.lua
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/integrations.lua
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/mocha.lua
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/palette.lua
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l scripts/build_mocha.lua --check
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/selection.lua
"$NVIM_BIN" --headless -n -u NONE -i NONE --noplugin -l tests/preview.lua
python3 tests/ui.py
python3 tests/palette_ui.py
python3 tests/selection_ui.py
python3 tests/groups_ui.py
python3 tests/window_ui.py
python3 tests/tui.py
stylua --check lua plugin colors scripts tests examples
