"""Render and scroll the actual icon grids in both picker backends."""

import json
import os
import signal
from pathlib import Path

from grid_capture import capture
from rpc import Capture

signal.signal(
    signal.SIGALRM,
    lambda *_: (_ for _ in ()).throw(TimeoutError("Icon preview UI timed out")),
)
signal.alarm(45)
root = Path(__file__).resolve().parent.parent
selection = Path(
    os.environ.get("THEME_TOOLS_SELECTION", root.parent / "selection-tools.nvim")
)

for backend in ("builtin", "selection_tools"):
    ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])

    def lua(code, ui=ui):
        return ui.request("nvim_exec_lua", [code, []])

    def keys(text, ui=ui):
        ui.request("nvim_input", [text])
        lua("vim.wait(40)")

    def wait(name, error=False):
        assert lua(
            """
          return vim.wait(5000,function()
            for _,win in ipairs(vim.api.nvim_list_wins()) do
              local buf=vim.api.nvim_win_get_buf(win)
              if vim.b[buf].theme_tools_icon_preview=="""
            + json.dumps(name)
            + """ then
                if vim.b[buf].theme_tools_icon_preview_ready or vim.b[buf].theme_tools_icon_preview_error then
                  sample_buf,sample_win=buf,win; return true
                end
              end
            end
          end)
        """
        ), name
        message = lua("return vim.b[sample_buf].theme_tools_icon_preview_error")
        assert bool(message) == error, message

    try:
        ui.request("nvim_ui_attach", [120, 44, {"rgb": True, "ext_linegrid": True}])
        lua(
            "vim.opt.rtp:prepend("
            + json.dumps(str(root))
            + "); vim.opt.rtp:append("
            + json.dumps(str(selection))
            + ")"
        )
        lua(
            """
          t=require('theme_tools'); i=t.icons
          require('selection_tools').setup({layout={width=0.8,height=0.9,input_position='bottom',reverse=true}})
          root=vim.fn.tempname(); warnings={}; vim.notify=function(x) warnings[#warnings+1]=x end
          t.setup({persist=false,catppuccin=false,dracula=false,default='theme-tools-mocha',themes={'theme-tools-mocha'},
            picker={backend="""
            + json.dumps(backend)
            + """}, icons={default='ascii',install={root=root,timeout=500},
              sources={mini={url=root..'/missing'}}}})
          events=0; i.on_change('ui-test',function() events=events+1 end)
          original=require('theme_tools.colors').snapshot()
          assert(i.pick())
        """
        )
        wait("ascii")
        # Picker initialization may define its own UI groups; provider previews
        # must preserve the host after those groups have been initialized.
        lua("original=require('theme_tools.colors').snapshot()")
        assert lua("return vim.b[sample_buf].theme_tools_icon_preview_count") >= 100
        contents = lua(
            "return table.concat(vim.api.nvim_buf_get_lines(sample_buf,0,-1,false),string.char(10))"
        )
        assert all(
            name in contents
            for name in (
                "init.lua",
                "main.py",
                "main.rs",
                "LSP types",
                "Function",
                "Diagnostics",
                "Git",
                "UI",
                "Operating systems",
            )
        )
        lua("vim.cmd('redraw!')")
        capture(ui, backend + "-icon-preview-ascii")
        before = lua("return vim.api.nvim_win_get_cursor(sample_win)[1]")
        keys("<C-d><C-d>")
        assert lua("return vim.api.nvim_win_get_cursor(sample_win)[1]") > before
        assert lua(
            "return i.current()=='ascii' and events==1 and vim.deep_equal(original,require('theme_tools.colors').snapshot())"
        )
        # A missing provider reports inside the sample without notifying or changing the host.
        keys("mini")
        wait("mini", error=True)
        assert lua(
            "return #warnings==0 and package.loaded['mini.icons']==nil and i.current()=='ascii' and events==1"
        )
        keys("<C-w>none")
        wait("none")
        assert "labels are shown without icons" in lua(
            "return table.concat(vim.api.nvim_buf_get_lines(sample_buf,0,-1,false),string.char(10))"
        )
        assert lua("return i.current()=='ascii' and events==1")
        ui.request("nvim_ui_try_resize", [32, 14])
        lua("vim.wait(60)")
        wait("none")
        assert lua("""
          local width=vim.api.nvim_win_get_width(sample_win)
          for _,line in ipairs(vim.api.nvim_buf_get_lines(sample_buf,0,-1,false)) do
            if vim.fn.strdisplaywidth(line)>width then return false end
          end
          return true
        """), "resized icon grid retained wide columns"
        keys("<Esc>")
        assert lua(
            "return #vim.api.nvim_list_wins()==1 and i.current()=='ascii' and events==1"
        )
        # Optional real cached sources verify glyph differences without touching personal state.
        installed = os.environ.get("THEME_TOOLS_REAL_ICON_ROOT")
        if installed:
            lua(
                "i.setup({persist=false,default='ascii',install={root="
                + json.dumps(installed)
                + "},picker={backend="
                + json.dumps(backend)
                + "}}); assert(i.pick())"
            )
            ui.request("nvim_ui_try_resize", [120, 44])
            keys("mini")
            wait("mini")
            lua("vim.cmd('redraw!')")
            capture(ui, backend + "-icon-preview-mini")
            keys("<C-w>devicons")
            wait("devicons")
            lua("vim.cmd('redraw!')")
            capture(ui, backend + "-icon-preview-devicons")
            assert lua(
                "return package.loaded['mini.icons']==nil and package.loaded['nvim-web-devicons']==nil and i.current()=='ascii'"
            )
            keys("<Esc>")
        lua("vim.fn.delete(root,'rf')")
        print(
            backend
            + ": 100+ isolated icon samples, scrolling, errors, hidden mode, resize and cancellation passed"
        )
    finally:
        ui.close()
