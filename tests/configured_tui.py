"""Exercise the installed personal configuration with real terminal input."""

import json
import os
import re
import shutil
import signal
import tempfile
from pathlib import Path

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


def check_startup(term):
    # Checking the final Normal highlight misses UI redraws before theme setup.
    # Neovim's default dark background must never reach the terminal on startup.
    term.drain()
    assert not re.search(
        rb"\x1b\[(?:[0-9]+;)*48;2;20;22;27(?:;[0-9]+)*m", term.output
    ), "UI redrew Neovim's opaque default background before the saved theme loaded"


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


def check_shared_colors(term):
    assert term.lua("""
      local c=require('theme_tools').palette()
      if c.name~=vim.g.colors_name or c.background~=vim.o.background then return false end
      local bases={['theme-tools-mocha']='#1e1e2e',['catppuccin-mocha']='#1e1e2e',
        ['catppuccin-latte']='#eff1f5',['theme-tools-dracula']='#282a36'}
      if bases[c.name] and c.palette.bg~=bases[c.name] then return false end
      local function color(value) return value=='NONE' and nil or tonumber(value:sub(2),16) end
      local editing
      for _,win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_config(win).relative=='' then editing=win; break end
      end
      local function hl(name)
        return vim.api.nvim_win_call(editing,function() return vim.api.nvim_get_hl(0,{name=name,link=false}) end)
      end
      if hl('Normal').bg~=color(c.ui.bg) then return false end
      if package.loaded['ui_tools.statusline'] then
        if hl('UiToolsStatusNormal').bg~=color(c.ui.accent) then return false end
        if hl('UiToolsStatus').bg~=(color(c.ui.bg) or color(c.palette.bg)) then return false end
      end
      return hl('SelectionToolsMarked').fg==color(c.ui.accent)
        and hl('SelectionToolsSelected').bg==color(c.ui.selection_bg)
    """), term.lua("""
      local result={palette=require('theme_tools').palette(),groups={}}
      for _,name in ipairs({'Normal','UiToolsStatusNormal','UiToolsStatus','SelectionToolsMarked','SelectionToolsSelected'}) do
        result.groups[name]=vim.api.nvim_get_hl(0,{name=name,link=false})
      end
      return result
    """)


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


def check_info_hover(term):
    # The personal CmdlineEnter handlers initialize completion/input highlights
    # for any command; let that finish before checking the report's own effects.
    term.keys(b":\x1b")
    term.lua("""
      require('lazy').load({plugins={'lsp-tools.nvim'}})
      local api=vim.api
      local c=require('theme_tools').palette()
      local _,win=vim.lsp.util.open_floating_preview({'documentation'},'plaintext',{focus_id='textDocument/hover'})
      assert(vim.wo[win].winhighlight:find('LspToolsHoverNormal',1,true))
      local info=require('theme_tools').info({groups={'LspToolsHoverNormal','LspToolsHoverBorder'}})
      local expected=c.ui.float_bg~='NONE' and tonumber(c.ui.float_bg:sub(2),16) or nil
      for _,group in ipairs(info.highlights) do assert(group.attributes.bg==expected) end
      api.nvim_win_close(win,true)
      info_source_win=api.nvim_get_current_win()
      info_original=require('theme_tools.colors').snapshot()
    """)
    term.keys(b":ThemeToolsInfo LspToolsHoverNormal\r")
    assert term.lua("""
      local text=table.concat(vim.api.nvim_buf_get_lines(0,0,-1,false),' ')
      return not vim.bo.modifiable and text:find('LspToolsHoverNormal -> LspToolsDefaultHoverNormal',1,true)~=nil
    """)
    term.keys(b"rq")
    assert term.lua("""
      return vim.api.nvim_get_current_win()==info_source_win
        and vim.deep_equal(require('theme_tools.colors').snapshot(),info_original)
    """), term.lua("""
      local now=require('theme_tools.colors').snapshot()
      local differences={}
      for name,value in pairs(now.highlights) do
        if not vim.deep_equal(value,info_original.highlights[name]) then
          differences[name]={before=info_original.highlights[name],after=value}
        end
      end
      return {window=vim.api.nvim_get_current_win(),source=info_source_win,differences=differences}
    """)


def sample_hl(term, name):
    return term.lua(
        "return vim.api.nvim_win_call(theme_sample_win,function() local ns=vim.api.nvim_get_hl_ns({winid=theme_sample_win}); return vim.api.nvim_get_hl(ns,{name="
        + json.dumps(name)
        + ",link=false}) end)"
    )


def capture_files_layout(term):
    term.lua("""
      local s=require('selection_tools'); local original=s.open
      s.open=function(opts) configured_picker=original(opts); return configured_picker end
      assert(require('theme_tools').icons.set('ascii'))
    """)
    term.keys(b" sf")
    term.lua("""
      configured_files_geometry=vim.deepcopy(configured_picker.resolved)
      configured_files_layout=vim.deepcopy(configured_picker.opts.layout)
    """)
    term.keys(b"\x1b")


def check_files_layout(term):
    assert term.lua("""
      local p=configured_picker
      if not vim.deep_equal(p.opts.layout,configured_files_layout) then return false end
      for _,name in ipairs({'frame','list','input','preview'}) do
        for _,key in ipairs({'row','col','width','height'}) do
          if p.resolved[name][key]~=configured_files_geometry[name][key] then return false end
        end
      end
      return p.opts.layout.reverse and vim.api.nvim_win_get_cursor(p.list_win)[1]==p.height
    """), "theme/icon picker differs from the configured Space sf layout"


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
      require('theme_tools').on_change('configured-test',function() theme_palette_events=(theme_palette_events or 0)+1 end)
      theme_palette_events=0
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
        and theme_palette_events==0
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
        check_startup(term)
        check_shared_colors(term)
        assert term.lua("return vim.g.colors_name") == "theme-tools-mocha"
        assert term.lua(
            "return require('lazy.core.config').plugins['theme-tools.nvim'].dir"
        ) == str(Path(__file__).resolve().parent.parent)
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        check_backgrounds(term, False)
        capture_files_layout(term)
        remember(term)
        assert (
            term.lua("return vim.fn.maparg('<leader>ut','n')") == "<Cmd>ThemeTools<CR>"
        )
        term.keys(b" ut")
        wait_preview(term, "theme-tools-mocha")
        check_files_layout(term)
        assert sample_hl(term, "Normal").get("bg") == 0x1E1E2E
        term.keys(b"dracula")
        wait_preview(term, "theme-tools-dracula")
        assert sample_hl(term, "Normal")["fg"] == 0xF8F8F2
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        stable(term)
        term.keys(b"\x1b")
        stable(term)
        term.keys(b":ThemeToolsIcons\r")
        check_files_layout(term)
        term.keys(b"\x1b")
        stable(term)
        term.keys(b" utlatte")
        stable(term)
        term.keys(b"\x07")
        term.keys(b"\x10")
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
        check_shared_colors(term)
        path = Path(
            term.lua("return vim.fn.stdpath('state') .. '/theme-tools/selection.json'")
        )
        assert json.loads(path.read_text())["name"] == "catppuccin-latte"
        if term.lua("return package.loaded.lualine ~= nil"):
            assert (
                term.lua("return require('lualine').get_config().options.theme")
                == "auto"
            )
        else:
            assert term.lua(
                "return package.loaded['ui_tools.statusline'] ~= nil and vim.wo.statusline ~= ''"
            )
        assert term.lua("return vim.fn.maparg('<leader>u]','n')") == ""
        assert term.lua("return vim.fn.maparg('<leader>u[','n')") == ""
        assert (
            term.lua("return vim.fn.maparg(']t','n',false,true).desc")
            == "[Motion] next treesitter"
        )
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "light.sock", before)
    try:
        check_startup(term)
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        check_shared_colors(term)
        check_info_hover(term)
        remember(term)
        term.keys(b" ut")
        wait_preview(term, "catppuccin-latte")
        term.keys(b"\x07")
        assert term.lua("return vim.fn.mode()") == "i"
        term.keys(b"dark\r")
        term.keys(b"dracula")
        wait_preview(term, "theme-tools-dracula")
        stable(term)
        term.keys(b"\r")
        assert term.lua("return vim.g.colors_name") == "theme-tools-dracula"
        check_shared_colors(term)
        assert json.loads(path.read_text())["name"] == "theme-tools-dracula"
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "dracula.sock", before)
    try:
        check_startup(term)
        assert term.lua("return vim.g.colors_name") == "theme-tools-dracula"
        check_shared_colors(term)
        check_info_hover(term)
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        # Use the configured completion engine and native Alt-j/Tab input.
        term.lua("""
          vim.cmd.enew(); vim.bo.filetype='text'
          vim.api.nvim_buf_set_lines(0,0,-1,false,{'health help',''})
          vim.api.nvim_win_set_cursor(0,{2,0})
        """)
        term.keys(b"ihel")
        assert term.lua("""
          cmp=require('completion-tools'); cmp.show({sources={'buffer'}})
          return vim.wait(2000,function() return cmp.is_menu_visible() end)
        """)
        term.keys(b"\x1bj")
        accepted = term.lua("return cmp.get_selected_item().label")
        assert accepted in ("health", "help"), accepted
        term.keys(b"\t\x1b")
        assert term.lua("return vim.api.nvim_get_current_line()") == accepted
        assert term.lua("""
          local h=vim.api.nvim_get_hl(0,{name='CompletionToolsSelected',link=false})
          return h.bg==0x44475a and h.bold and h.fg==nil
        """)
        assert term.lua("return require('theme_tools').set('theme-tools-mocha')")
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "personal.sock", before)
    try:
        check_startup(term)
        assert term.lua("return vim.g.colors_name") == "theme-tools-mocha"
        assert term.lua(
            "return package.loaded.catppuccin==nil and package.loaded.dracula==nil"
        )
        check_backgrounds(term, False)
        check_shared_colors(term)
        check_info_hover(term)
        # Exercise global previews using the actual configured Alt-j/Alt-k mappings.
        term.lua("""
          local plugin=require('lazy.core.config').plugins['theme-tools.nvim']
          local opts=vim.deepcopy(require('lazy.core.plugin').values(plugin,'opts',false))
          opts.persist=false
          opts.picker.preview_mode='live'
          opts.picker.group_by_background=false
          require('theme_tools').setup(opts)
        """)
        term.keys(b" ut")
        # The global reverse=true layout starts at the bottom; Alt-k moves up
        # to the next item, while Alt-j still moves down on screen.
        term.keys(b"\x1bk")
        assert term.lua("return vim.g.colors_name") == "theme-tools-dracula"
        check_shared_colors(term)
        term.keys(b"\x1bk\x1bk\x1bj")
        assert term.lua("return vim.g.colors_name") == "catppuccin-mocha"
        check_shared_colors(term)
        term.keys(b"\x1b")
        assert term.lua("return vim.g.colors_name") == "theme-tools-mocha"
        check_shared_colors(term)
        term.keys(b":colorscheme catppuccin-latte\r")
        check_shared_colors(term)
        assert term.lua("return require('theme_tools').set('theme-tools-mocha')")
        if term.lua("return package.loaded.lualine ~= nil"):
            term.lua(
                "dofile(require('lazy.core.config').plugins['theme-tools.nvim'].dir .. '/tests/real_bars.lua')"
            )
        # Toggle the current theme through the configured selector, then restart.
        term.lua("""
          local plugin=require('lazy.core.config').plugins['theme-tools.nvim']
          local opts=vim.deepcopy(require('lazy.core.plugin').values(plugin,'opts',false))
          opts.persist=true
          opts.picker.preview_mode='window'
          opts.picker.group_by_background=false
          require('theme_tools').setup(opts)
        """)
        term.keys(b" ut")
        wait_preview(term, "theme-tools-mocha")
        term.keys(b"\x14")
        assert term.lua(
            "return vim.wait(5000,function() return vim.b[theme_sample_buf].theme_tools_preview_transparent==false end)"
        )
        assert term.lua("return require('theme_tools').palette().transparent"), (
            "window toggle changed the host"
        )
        term.keys(b"\x14\x14\r")
        assert not term.lua("return require('theme_tools').palette().transparent")
        check_shared_colors(term)
        assert (
            json.loads(path.read_text())["transparency"]["theme-tools-mocha"] is False
        )
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "opaque.sock", before)
    try:
        check_startup(term)
        assert not term.lua("return require('theme_tools').palette().transparent")
        assert (
            term.lua("return vim.api.nvim_get_hl(0,{name='Normal',link=false}).bg")
            == 0x1E1E2E
        )
        check_shared_colors(term)
        term.keys(b" ut")
        wait_preview(term, "theme-tools-mocha")
        term.keys(b"\x14\r")
        assert term.lua("return require('theme_tools').palette().transparent")
        assert json.loads(path.read_text())["transparency"]["theme-tools-mocha"] is True
        # Explicit transparency takes precedence over Latte's configured solid override.
        assert term.lua("return require('theme_tools').set('catppuccin-latte')")
        term.keys(b" ut")
        wait_preview(term, "catppuccin-latte")
        term.keys(b"\x14\r")
        assert term.lua("return require('theme_tools').palette().transparent")
        check_shared_colors(term)
    finally:
        term.close()
    term = Terminal(config / "init.lua", directory / "transparent.sock", before)
    try:
        check_startup(term)
        assert term.lua("return vim.g.colors_name") == "catppuccin-latte"
        assert term.lua("return require('theme_tools').palette().transparent")
        assert (
            term.lua("return vim.api.nvim_get_hl(0,{name='Normal',link=false}).bg")
            is None
        )
        check_shared_colors(term)
        assert term.lua("return #config_test_errors") == 0, term.lua(
            "return config_test_errors"
        )
    finally:
        term.close()
print(
    "configured PTY: isolated samples, semantic colors, hover/info, live keys, transparency toggle, confirm, cancel and restart passed"
)
