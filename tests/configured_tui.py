"""Exercise the installed personal configuration with real terminal input."""

import json
import os
from pathlib import Path
import re
import shutil
import signal
import tempfile
from tui import Terminal

signal.signal(
    signal.SIGALRM,
    lambda *_: (_ for _ in ()).throw(TimeoutError("Configured theme TUI timed out")),
)
signal.alarm(40)
config = Path(os.environ.get("THEME_TOOLS_NVIM_CONFIG", Path.home() / ".config/nvim"))
assert (config / "lua/plugins/ui/theme-tools.lua").is_file(), (
    "theme-tools must be installed in the config first"
)


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
        palette = term.lua(
            "local c=require('catppuccin.palettes').get_palette('latte'); return {base=tonumber(c.base:sub(2),16),mantle=tonumber(c.mantle:sub(2),16)}"
        )
        for group in ("Normal", "NormalNC"):
            assert backgrounds.get(group) == palette["base"], (group, backgrounds)
        for group in ("NormalFloat", "FloatBorder", "FloatTitle"):
            assert backgrounds.get(group) == palette["mantle"], (group, backgrounds)
        rgb = ";".join(str((palette["base"] >> shift) & 255) for shift in (16, 8, 0))
        assert re.search(
            rb"\x1b\[[0-9;]*48;2;" + rgb.encode() + rb"(?:;[0-9]+)*m", term.output
        ), "opaque Latte background was not sent to the terminal"
    else:
        assert not backgrounds, backgrounds


def wait_preview(term, name):
    encoded = json.dumps(name)
    assert term.lua(
        """
      return vim.wait(5000,function()
        for _,win in ipairs(vim.api.nvim_list_wins()) do
          local buf=vim.api.nvim_win_get_buf(win)
          if vim.b[buf].theme_tools_preview == """
        + encoded
        + """ then
            theme_sample_buf,theme_sample_win=buf,win
            return true
          end
        end
      end)
    """
    ), "sample did not render: " + name
    assert term.lua("return vim.b[theme_sample_buf].theme_tools_preview_error") is None


def sample_hl(term, name):
    return term.lua(
        "return vim.api.nvim_win_call(theme_sample_win,function() local ns=vim.api.nvim_get_hl_ns({winid=theme_sample_win}); return vim.api.nvim_get_hl(ns,{name="
        + json.dumps(name)
        + ",link=false}) end)"
    )


def remember(term):
    term.lua("""
      theme_original={name=vim.g.colors_name,background=vim.o.background,groups={},terminal={}}
      for _,name in ipairs({'Normal','NormalNC','Visual','Search','Comment','UiToolsLineNr'}) do
        theme_original.groups[name]=vim.api.nvim_get_hl(0,{name=name})
      end
      for i=0,15 do theme_original.terminal[i]=vim.g['terminal_color_'..i] end
      theme_original.terminal.background=vim.g.terminal_color_background
      theme_original.terminal.foreground=vim.g.terminal_color_foreground
      theme_scheme_events=0
      vim.api.nvim_create_autocmd('ColorScheme',{callback=function() theme_scheme_events=theme_scheme_events+1 end})
    """)


def stable(term):
    assert term.lua("""
      if vim.g.colors_name~=theme_original.name or vim.o.background~=theme_original.background then return false end
      for name,value in pairs(theme_original.groups) do
        if not vim.deep_equal(value,vim.api.nvim_get_hl(0,{name=name})) then return false end
      end
      for i=0,15 do if theme_original.terminal[i]~=vim.g['terminal_color_'..i] then return false end end
      return theme_original.terminal.background==vim.g.terminal_color_background
        and theme_original.terminal.foreground==vim.g.terminal_color_foreground
        and theme_scheme_events==0
    """), "browsing changed the editor theme"


with tempfile.TemporaryDirectory(prefix="/tmp/theme-config-") as directory:
    directory = Path(directory)
    shutil.copyfile(config / "lazy-lock.json", directory / "lazy-lock.json")
    os.environ.update(
        {
            "NVIM_SMOKE_TEST": "1",
            "NVIM_TEST_SCENARIO": "minimal",
            "NVIM_CONFIG_ROOT": str(config),
            "NVIM_LAZY_LOCKFILE": str(directory / "lazy-lock.json"),
            "XDG_STATE_HOME": str(directory / "state"),
            "XDG_CACHE_HOME": str(directory / "cache"),
            "NVIM_LOG_FILE": str(directory / "nvim.log"),
        }
    )
    os.environ.pop("XDG_DATA_HOME", None)
    before = ["--cmd", "lua dofile(vim.env.NVIM_CONFIG_ROOT .. '/tests/setup.lua')"]
    term = Terminal(config / "init.lua", directory / "first.sock", before)
    try:
        assert term.lua("return vim.g.colors_name") == "theme-tools-mocha"
        assert term.lua(
            "return require('lazy.core.config').plugins['theme-tools.nvim'].dir"
        ) == str(Path(__file__).resolve().parent.parent)
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        check_backgrounds(term, False)
        remember(term)
        assert (
            term.lua("return vim.fn.maparg('<leader>ut','n')") == "<Cmd>ThemeTools<CR>"
        )
        term.keys(b" ut")
        wait_preview(term, "theme-tools-mocha")
        assert sample_hl(term, "Normal").get("bg") == 0x1E1E2E
        term.keys(b"dracula")
        wait_preview(term, "dracula")
        assert sample_hl(term, "Normal")["fg"] == 0xF8F8F2
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        stable(term)
        term.keys(b"\x1b")
        stable(term)
        term.keys(b" utlatte")
        stable(term)
        term.keys(b"\x07")
        term.keys(b"\x0e")
        stable(term)
        term.keys(b"\r")
        wait_preview(term, "catppuccin-latte")
        assert sample_hl(term, "Normal")["bg"] == 0xEFF1F5
        assert sample_hl(term, "ThemeToolsSampleFloat")["bg"] == 0xE6E9EF
        # Personal ColorScheme overrides also run in the worker.
        assert sample_hl(term, "UiToolsLineNr")["fg"] == 0xACB0BE
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        stable(term)
        term.keys(b"\x04")
        stable(term)
        term.keys(b"\x1b")
        stable(term)
        assert term.lua("return vim.fn.mode()") == "n"
        # Confirm without waiting for a preview response.
        term.keys(b" ut")
        term.keys(b"\x07")
        term.keys(b"light\r")
        term.keys(b"latte\r")
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        check_backgrounds(term, True)
        path = Path(
            term.lua("return vim.fn.stdpath('state') .. '/theme-tools/selection.json'")
        )
        assert json.loads(path.read_text())["name"] == "catppuccin-latte"
        assert (
            term.lua("return require('lualine').get_config().options.theme") == "auto"
        )
        assert term.lua("return vim.fn.maparg('<leader>u]','n')") == ""
        assert term.lua("return vim.fn.maparg('<leader>u[','n')") == ""
        assert "MiniBracketed.treesitter" in term.lua("return vim.fn.maparg(']t','n')")
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "light.sock", before)
    try:
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        remember(term)
        term.keys(b" ut")
        wait_preview(term, "catppuccin-latte")
        term.keys(b"\x07")
        assert term.lua("return vim.fn.mode()") == "i"
        term.keys(b"dark\r")
        term.keys(b"dracula")
        wait_preview(term, "dracula")
        stable(term)
        term.keys(b"\r")
        assert term.lua("return vim.g.colors_name") == "dracula"
        assert json.loads(path.read_text())["name"] == "dracula"
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "dracula.sock", before)
    try:
        assert term.lua("return vim.g.colors_name") == "dracula"
        assert term.lua("return package.loaded.catppuccin==nil")
        assert term.lua("return require('theme_tools').set('theme-tools-mocha')")
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "personal.sock", before)
    try:
        assert term.lua("return vim.g.colors_name") == "theme-tools-mocha"
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        check_backgrounds(term, False)
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
print(
    "configured PTY: namespaced Mocha/Dracula/Latte samples, custom highlights, global isolation, scrolling, immediate confirm, cancel and restart passed"
)
