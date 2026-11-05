"""Offline acceptance with cached real Catppuccin/mini.icons sources."""
import os
from pathlib import Path
import signal
import tempfile
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Managed icons UI timed out")))
signal.alarm(30)
sources = Path(os.environ["THEME_TOOLS_REAL_DATA"])
assert (sources / "themes/catppuccin").is_dir() and (sources / "icons/mini-icons").is_dir()

with tempfile.TemporaryDirectory(prefix="theme-managed-icons-") as directory:
    env = dict(os.environ, XDG_STATE_HOME=directory + "/state", XDG_CACHE_HOME=directory + "/cache")
    ui = Capture(env, ["-u", "NONE", "-i", "NONE", "--noplugin"])

    def lua(code, args=None):
        return ui.request("nvim_exec_lua", [code, args or []])

    def check(theme, expected):
        lua("assert(t.set(...)); vim.wait(30); vim.cmd('redraw!')", [theme])
        actual = lua("""
          local icon,group=t.icons.get('file','sample.lua')
          return {icon=icon,hl=vim.api.nvim_get_hl(0,{name=group,link=false})}
        """)
        assert actual["hl"].get("fg") == expected, (theme, actual)
        lua("""
          p=require('selection_tools').open({items={{file='/tmp/sample.lua',label='sample.lua'}},
            format_item=function(item) return item.label end, history={persist=false}})
          vim.wait(20); vim.cmd('redraw!')
        """)
        lua("return true")
        attrs = [ui.attrs[attr] for row in ui.grid for char, attr in row if char == actual["icon"]]
        assert attrs and all(a.get("foreground") == expected for a in attrs), (theme, attrs)
        lua("p:close(); vim.cmd.stopinsert()")

    try:
        ui.request("nvim_ui_attach", [100, 34, {"rgb": True, "ext_linegrid": True}])
        lua("""
          vim.opt.rtp:prepend(vim.fn.getcwd())
          vim.opt.rtp:append(vim.fn.getcwd()..'/../selection-tools.nvim')
          local sources=...
          t=require('theme_tools')
          t.setup({persist=false,dracula=false,default='theme-tools-dracula',
            install={root=sources..'/themes'},icons={default='mini',install={root=sources..'/icons'}},
            themes={'theme-tools-dracula','theme-tools-mocha','catppuccin-latte','catppuccin-mocha'}})
          assert(t.icons.get('file','sample.lua') ~= '')
          assert(not package.loaded['lazy.core.config'], 'test must cover manager-free setup')
        """, [str(sources)])
        for theme, expected in (("theme-tools-dracula", 0xA4FFFF), ("catppuccin-latte", 0x209FB5),
                                ("theme-tools-mocha", 0x74C7EC), ("catppuccin-latte", 0x209FB5),
                                ("catppuccin-mocha", 0x74C7EC)):
            check(theme, expected)
        lua("""
          original=require('theme_tools.colors').snapshot()
          assert(require('theme_tools.colors').apply({colorscheme='catppuccin-latte',background='light'}))
          local _,group=t.icons.get('file','sample.lua')
          assert(vim.api.nvim_get_hl(0,{name=group,link=false}).fg==0x209fb5)
          require('theme_tools.colors').restore(original)
          assert(vim.api.nvim_get_hl(0,{name=group,link=false}).fg==0x74c7ec)
          -- Clearing is also required when a new scheme omits plugin groups.
          vim.api.nvim_set_hl(0,'OldThemeOnly',{fg='#abcdef'})
          assert(require('theme_tools.colors').apply({colorscheme='morning',background='light'}))
          assert(vim.tbl_isempty(vim.api.nvim_get_hl(0,{name='OldThemeOnly',create=false})))
        """)
    finally:
        ui.close()
print("managed icons UI: dark/light colors, rendered picker icons, manager-free integration and preview rollback passed")
