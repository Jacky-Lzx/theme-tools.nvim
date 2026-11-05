"""Render actual namespaced theme samples in both picker UIs."""

import json
import os
from pathlib import Path
import signal
from rpc import Capture

signal.signal(
    signal.SIGALRM,
    lambda *_: (_ for _ in ()).throw(TimeoutError("Theme sample UI timed out")),
)
signal.alarm(40)
selection = Path(
    os.environ.get(
        "THEME_TOOLS_SELECTION",
        Path(__file__).resolve().parent.parent.parent / "selection-tools.nvim",
    )
)

for backend in ("builtin", "selection_tools"):
    ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])

    def lua(code):
        return ui.request("nvim_exec_lua", [code, []])

    def keys(text):
        ui.request("nvim_input", [text])
        lua("vim.wait(30)")

    def preview(name, error=False):
        assert lua(
            """
          return vim.wait(5000,function()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              local buf=vim.api.nvim_win_get_buf(win)
              if vim.b[buf].theme_tools_preview == """
            + json.dumps(name)
            + """ then
                sample_buf, sample_win=buf,win
                return true
              end
            end
          end)
        """
        ), name
        message = lua("return vim.b[sample_buf].theme_tools_preview_error")
        assert bool(message) == error, message

    def stable():
        assert lua("""
          if vim.g.colors_name~='habamax' or vim.o.background~='dark' then return false end
          for name,value in pairs(original) do
            if not vim.deep_equal(value,vim.api.nvim_get_hl(0,{name=name})) then return false end
          end
          return true
        """), "sample changed global colors"

    try:
        ui.request("nvim_ui_attach", [112, 42, {"rgb": True, "ext_linegrid": True}])
        ui.request("nvim_exec_lua", ["vim.opt.rtp:append(...)", [str(selection)]])
        lua(
            """
          vim.opt.rtp:prepend(vim.fn.getcwd())
          t=require('theme_tools'); path=vim.fn.tempname(); changes=0; schemes=0
          t.setup({catppuccin=false,dracula=false,state_file=path,default='night',
            picker={group_by_background=false,backend="""
            + json.dumps(backend)
            + """},themes={
              {name='night',colorscheme='habamax',background='dark'},
              {name='day',colorscheme='morning',background='light'},
              {name='broken',colorscheme='habamax',before=function()
                vim.g.bad_before_called=true; error('sample failure')
              end},
              {name='dusk',colorscheme='desert',background='dark'},
            }})
          original={}
          for _,name in ipairs({'Normal','Visual','Search','Comment','Function'}) do
            original[name]=vim.api.nvim_get_hl(0,{name=name})
          end
          vim.api.nvim_create_autocmd('User',{pattern='ThemeToolsChanged',callback=function() changes=changes+1 end})
          vim.api.nvim_create_autocmd('ColorScheme',{callback=function() schemes=schemes+1 end})
          assert(t.pick())
        """
        )
        preview("night")
        keys("day")
        preview("day")
        stable()
        assert lua("return schemes==0 and changes==0")
        assert (
            lua("return vim.json.decode(table.concat(vim.fn.readfile(path))).name")
            == "night"
        )
        assert lua(
            "return vim.api.nvim_win_call(sample_win,function() local ns=vim.api.nvim_get_hl_ns({winid=sample_win}); return ns>0 and vim.api.nvim_get_hl(ns,{name='Normal',link=false}).bg ~= original.Normal.bg end)"
        )
        contents = lua(
            "return table.concat(vim.api.nvim_buf_get_lines(sample_buf,0,-1,false),string.char(10))"
        )
        assert all(
            word in contents
            for word in (
                "greet",
                "Completion menu",
                "Error",
                "Floating window",
                "Search",
                "Files / sidebar",
                "Tasks",
                "[Copilot]",
                "Statusline",
            )
        ), contents
        keys("<C-d><C-d><C-d>")
        stable()
        ui.request("nvim_ui_try_resize", [64, 22])
        lua("vim.wait(80)")
        stable()
        ui.request("nvim_ui_try_resize", [40, 12])
        lua("vim.wait(80)")
        stable()
        assert lua("return #vim.api.nvim_list_wins()") > 1, "small viewport closed the picker"
        ui.request("nvim_ui_try_resize", [112, 42])
        lua("vim.wait(80)")
        keys("<C-w>broken")
        preview("broken", error=True)
        assert lua("return vim.g.bad_before_called == nil"), (
            "before hook ran in the host while browsing"
        )
        stable()
        keys("<Esc>")
        stable()
        assert lua("return schemes==0 and changes==0 and #vim.api.nvim_list_wins()==1")
        lua("assert(t.pick())")
        keys("dusk<CR>")
        assert lua("return vim.g.colors_name") == "desert", (
            "confirm must apply even before the worker responds"
        )
        assert lua("return changes") == 1
        lua("vim.wait(100)")
        assert lua("return #vim.api.nvim_list_wins()") == 1
        lua("vim.fn.delete(path)")
        print(
            backend
            + ": isolated sample, syntax/UI elements, light preview, resize, errors, cancellation and immediate confirm passed"
        )
    finally:
        ui.close()
