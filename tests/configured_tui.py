"""Exercise the installed personal configuration with real terminal input."""
import json
import os
from pathlib import Path
import re
import shutil
import signal
import tempfile
from tui import Terminal

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Configured theme TUI timed out")))
signal.alarm(40)
config = Path(os.environ.get("THEME_TOOLS_NVIM_CONFIG", Path.home() / ".config/nvim"))
assert (config / "lua/plugins/ui/theme-tools.lua").is_file(), "theme-tools must be installed in the config first"


def check_backgrounds(term, light):
    # Read in the editing window: the picker maps Normal to NormalFloat.
    backgrounds = term.lua("""
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative == '' then
          return vim.api.nvim_win_call(win, function()
            local result = vim.empty_dict()
            for _, group in ipairs({'Normal','NormalNC','NormalFloat','FloatBorder','FloatTitle'}) do
              result[group] = vim.api.nvim_get_hl(0, {name=group,link=false}).bg
            end
            return result
          end)
        end
      end
    """)
    if light:
        palette = term.lua("local c=require('catppuccin.palettes').get_palette('latte'); return {base=tonumber(c.base:sub(2),16),mantle=tonumber(c.mantle:sub(2),16)}")
        for group in ("Normal", "NormalNC"):
            assert backgrounds.get(group) == palette["base"], (group, backgrounds)
        for group in ("NormalFloat", "FloatBorder", "FloatTitle"):
            assert backgrounds.get(group) == palette["mantle"], (group, backgrounds)
        rgb = ";".join(str((palette["base"] >> shift) & 255) for shift in (16, 8, 0))
        assert re.search(rb"\x1b\[[0-9;]*48;2;" + rgb.encode() + rb"(?:;[0-9]+)*m", term.output), "opaque Latte background was not sent to the terminal"
    else:
        assert not backgrounds, backgrounds


with tempfile.TemporaryDirectory(prefix="/tmp/theme-config-") as directory:
    directory = Path(directory)
    shutil.copyfile(config / "lazy-lock.json", directory / "lazy-lock.json")
    os.environ.update({
        "NVIM_SMOKE_TEST": "1",
        "NVIM_TEST_SCENARIO": "minimal",
        "NVIM_CONFIG_ROOT": str(config),
        "NVIM_LAZY_LOCKFILE": str(directory / "lazy-lock.json"),
        "XDG_STATE_HOME": str(directory / "state"),
        "XDG_CACHE_HOME": str(directory / "cache"),
        "NVIM_LOG_FILE": str(directory / "nvim.log"),
    })
    # run.sh isolates data for plugin tests; the real config needs installed plugins.
    os.environ.pop("XDG_DATA_HOME", None)
    before = ["--cmd", "lua dofile(vim.env.NVIM_CONFIG_ROOT .. '/tests/setup.lua')"]
    term = Terminal(config / "init.lua", directory / "first.sock", before)
    try:
        assert term.lua("return vim.g.colors_name") == "catppuccin-mocha"
        check_backgrounds(term, False)
        assert term.lua("return require('lazy.core.config').plugins['theme-tools.nvim'].dir") == str(Path(__file__).resolve().parent.parent)
        assert term.lua("return require('lazy.core.config').plugins.catppuccin == nil")
        assert term.lua("local p=require('theme_tools.providers.catppuccin').source; local dir=vim.fn.stdpath('data') .. '/theme-tools/themes/' .. p.name .. '/' .. p.commit; return debug.getinfo(require('catppuccin').setup,'S').source:sub(1,#dir+1) == '@' .. dir")
        assert term.lua("return vim.fn.maparg('<leader>ut','n')") == "<Cmd>ThemeTools<CR>"
        term.keys(b" ut")
        assert term.lua("return vim.bo.filetype") == "selection_tools_input"
        term.keys(b"\x0e")
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        assert term.lua("return vim.o.background") == "light"
        check_backgrounds(term, True)
        assert term.lua("return vim.api.nvim_get_hl(0,{name='UiToolsLineNr'}).fg == tonumber(require('catppuccin.palettes').get_palette('latte').surface2:sub(2),16)")
        assert term.lua("return require('lualine').get_config().options.theme") == "auto"
        term.keys(b"\x1b")
        assert term.lua("return vim.g.colors_name") == "catppuccin-mocha"
        check_backgrounds(term, False)
        assert term.lua("return vim.fn.mode()") == "n"
        term.keys(b" utlatte\r")
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        check_backgrounds(term, True)
        assert term.lua("return vim.bo.filetype") != "selection_tools_input"
        path = Path(term.lua("return vim.fn.stdpath('state') .. '/theme-tools/selection.json'"))
        assert json.loads(path.read_text())["name"] == "catppuccin-latte"
        assert term.lua("return vim.fn.maparg('<leader>u]','n')") == ""
        assert term.lua("return vim.fn.maparg('<leader>u[','n')") == ""
        term.keys(b":ThemeToolsNext\r")
        actual = term.lua("return vim.g.colors_name")
        assert actual == "catppuccin-frappe", actual
        check_backgrounds(term, False)
        term.keys(b":ThemeToolsPrev\r")
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        check_backgrounds(term, True)
        assert "MiniBracketed.treesitter" in term.lua("return vim.fn.maparg(']t','n')")
        assert term.lua("return #config_test_errors") == 0, term.lua("return config_test_errors")
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "restart.sock", before)
    try:
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        assert term.lua("return vim.o.background") == "light"
        check_backgrounds(term, True)
        assert term.lua("return #config_test_errors") == 0, term.lua("return config_test_errors")
    finally:
        term.close()
print("configured PTY: local installation, Space u t, Catppuccin, custom highlights, lualine, cycling and restart passed")
