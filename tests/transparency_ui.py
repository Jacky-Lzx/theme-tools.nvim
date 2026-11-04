"""Toggle transparency in both pickers without committing previews or stale caches."""
import json
import os
from pathlib import Path
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Transparency UI timed out")))
signal.alarm(40)
selection = Path(os.environ.get("THEME_TOOLS_SELECTION", Path(__file__).resolve().parents[2] / "selection-tools.nvim"))

for backend in ("builtin", "selection_tools"):
    for mode in ("window", "live"):
        ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])

        def lua(code):
            return ui.request("nvim_exec_lua", [code, []])

        def keys(value):
            ui.request("nvim_input", [value])
            lua("vim.wait(30)")

        def preview(name, enabled):
            if mode == "live":
                assert lua("return t.palette().transparent") == enabled
            else:
                assert lua("""
                  return vim.wait(5000,function()
                    for _,win in ipairs(vim.api.nvim_list_wins()) do
                      local buf=vim.api.nvim_win_get_buf(win)
                      if vim.b[buf].theme_tools_preview==""" + json.dumps(name) + """
                        and vim.b[buf].theme_tools_preview_transparent==""" + str(enabled).lower() + """ then return true end
                    end
                  end)
                """), (backend, mode, name, enabled)

        def saved(name):
            return lua("local _,_,p=require('theme_tools.state').read(path); return (p or {})[" + json.dumps(name) + "]")

        try:
            ui.request("nvim_ui_attach", [110, 42, {"rgb": True, "ext_linegrid": True}])
            ui.request("nvim_exec_lua", ["vim.opt.rtp:append(...)", [str(selection)]])
            lua("""
              vim.opt.rtp:prepend(vim.fn.getcwd())
              t=require('theme_tools'); path=vim.fn.tempname(); published=0
              opts={state_file=path,catppuccin=false,dracula=false,default='theme-tools-mocha',
                themes={'theme-tools-mocha',{name='day',colorscheme='morning',background='light'}},
                picker={backend=""" + json.dumps(backend) + ",preview_mode=" + json.dumps(mode) + """,group_by_background=false}}
              t.setup(opts)
              t.on_change('test',function(c) published=published+1 end)
              assert(t.pick())
            """)
            preview("theme-tools-mocha", True)
            keys("<C-t>")
            preview("theme-tools-mocha", False)
            if mode == "window":
                assert lua("return t.palette().transparent and published==1")
            assert saved("theme-tools-mocha") is None
            keys("<Esc>")
            assert lua("return t.palette().transparent")
            assert saved("theme-tools-mocha") is None
            lua("assert(t.pick())")
            preview("theme-tools-mocha", True)
            keys("<C-t><CR>")
            assert not lua("return t.palette().transparent")
            assert saved("theme-tools-mocha") is False
            lua("t.setup(opts)")
            assert not lua("return t.palette().transparent")
            # A different theme gets its own preference; rapid toggle/confirm is authoritative.
            lua("assert(t.set('day')); assert(t.pick())")
            preview("day", False)
            keys("<C-t><C-t><C-t><CR>")
            assert lua("return t.palette().transparent")
            assert saved("day") is True
            assert saved("theme-tools-mocha") is False
            lua("assert(t.set('theme-tools-mocha')); assert(t.pick())")
            preview("theme-tools-mocha", False)
            keys("<C-t>")
            preview("theme-tools-mocha", True)
            keys("<C-t>")
            preview("theme-tools-mocha", False)
            keys("<Esc>")
            assert not lua("return t.palette().transparent")
            # Groups are navigation only; an unconfirmed edit must not leak across them.
            lua("opts.picker.group_by_background=true; t.setup(opts); assert(t.pick())")
            preview("theme-tools-mocha", False)
            keys("<C-t><C-g>")
            keys("light<CR>")
            preview("day", True)
            keys("<C-t><CR>")
            assert not lua("return t.palette().transparent")
            assert saved("day") is False and saved("theme-tools-mocha") is False
            lua("vim.fn.delete(path)")
        finally:
            ui.close()
        print(backend + "/" + mode + ": transparency preview, rapid toggle, confirm, cancel, groups and saved restore passed")
