"""Inspect the real shared frame and pane placement, with optional grid captures."""

import json
import os
import signal
from pathlib import Path

from grid_capture import capture
from rpc import Capture

signal.signal(
    signal.SIGALRM,
    lambda *_: (_ for _ in ()).throw(TimeoutError("Picker layout timed out")),
)
signal.alarm(40)
root = Path(__file__).resolve().parent.parent
selection = Path(
    os.environ.get("THEME_TOOLS_SELECTION", root.parent / "selection-tools.nvim")
)


for backend in ("builtin", "selection_tools"):
    ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])

    def lua(code, ui=ui):
        return ui.request("nvim_exec_lua", [code, []])

    def screen(ui=ui):
        lua("vim.cmd('redraw!')")
        return "\n".join("".join(char for char, _ in row) for row in ui.grid)

    def geometry():
        return lua("""
          local parts={}
          if backend=='selection_tools' then
            for _,name in ipairs({'frame','input','list','preview'}) do
              local win=p[name..'_win']
              if win and vim.api.nvim_win_is_valid(win) then parts[name]=vim.api.nvim_win_get_config(win) end
            end
          else
            for _,win in ipairs(vim.api.nvim_list_wins()) do
              local role=vim.b[vim.api.nvim_win_get_buf(win)].theme_tools_picker_role
              if role and role~='separator' then parts[role]=vim.api.nvim_win_get_config(win) end
            end
          end
          return parts
        """)

    try:
        ui.request("nvim_ui_attach", [120, 40, {"rgb": True, "ext_linegrid": True}])
        lua(
            "vim.opt.rtp:prepend("
            + json.dumps(str(root))
            + "); vim.opt.rtp:append("
            + json.dumps(str(selection))
            + ")"
        )
        lua(
            """
          s=require('selection_tools'); local original=s.open
          s.open=function(...) p=original(...); return p end
          s.setup({layout={width=0.8,height=0.9,min_width=60,input_position='bottom',reverse=true,preview_height=0.6},
            select={layout={width=0.35,height=0.4,input_position='top',reverse=false}}})
          s.select=function() error('theme/icon selectors must bypass the compact select profile') end
          s.files({cwd=vim.fn.getcwd()})
          files_geometry=vim.deepcopy(p.resolved)
          files_layout=vim.deepcopy(p.opts.layout)
          p:close()
          t=require('theme_tools'); backend="""
            + json.dumps(backend)
            + """
          t.setup({catppuccin=false,dracula=false,persist=false,default='theme-tools-mocha',
            themes={'theme-tools-mocha','morning','desert'},icons={default='ascii'},
            picker={backend=backend,group_by_background=false}})
          assert(t.pick())
          assert(vim.wait(5000,function()
            for _,win in ipairs(vim.api.nvim_list_wins()) do
              if vim.b[vim.api.nvim_win_get_buf(win)].theme_tools_preview=='theme-tools-mocha' then return true end
            end
          end))
        """
        )
        parts = geometry()
        assert parts["preview"]["row"] < parts["list"]["row"] < parts["input"]["row"], (
            parts
        )
        if backend == "builtin":
            assert parts["frame"]["width"] >= 110 and parts["frame"]["height"] >= 34, (
                parts
            )
        else:
            assert lua("""
              for _,name in ipairs({'frame','input','list','preview'}) do
                for _,key in ipairs({'row','col','width','height'}) do
                  if p.resolved[name][key]~=files_geometry[name][key] then return false end
                end
              end
              return vim.deep_equal(p.opts.layout,files_layout)
                and vim.api.nvim_win_get_cursor(p.list_win)[1]==p.height
            """), "theme selector did not inherit the Files layout"
        assert parts["list"]["col"] == parts["preview"]["col"] == parts["input"]["col"]
        text = screen()
        assert "1/3" in text and "├" in text and "┤" in text, text
        capture(ui, backend + "-themes")
        ui.request("nvim_input", ["morn"])
        lua("vim.wait(50)")
        assert "1/1" in screen()
        ui.request("nvim_input", ["<Esc>"])
        lua("vim.wait(30); assert(t.icons.pick())")
        parts = geometry()
        assert parts["list"]["row"] < parts["input"]["row"], parts
        if backend == "builtin":
            assert parts["frame"]["width"] >= 110
        else:
            assert lua(
                "return vim.deep_equal(p.opts.layout,files_layout) and p.resolved.frame.width==files_geometry.frame.width and p.resolved.frame.height==files_geometry.frame.height"
            )
        assert "Icons" in screen() and "4" in screen()
        capture(ui, backend + "-icons")
        ui.request("nvim_ui_try_resize", [28, 12])
        lua("vim.wait(50)")
        parts = geometry()
        assert parts["frame"]["width"] <= 24 and parts["input"]["width"] >= 1
        ui.request("nvim_input", ["none<CR>"])
        lua(
            "vim.wait(50); assert(t.icons.current()=='none'); assert(#vim.api.nvim_list_wins()==1)"
        )
        if backend == "selection_tools":
            lua("""
              t.setup({persist=false,catppuccin=false,dracula=false,themes={'habamax'},
                picker={backend='selection_tools',group_by_background=false,
                  selection={layout={width=0.5,input_position='top',reverse=false}}}})
              assert(t.pick())
              assert(p.opts.layout.width==0.5 and p.opts.layout.input_position=='top' and not p.opts.layout.reverse)
              assert(p.opts.layout.height==files_layout.height and p.opts.layout.min_width==files_layout.min_width)
              t.close()
            """)
        print(
            backend
            + ": frame placement, Files layout inheritance, explicit overrides, counts, resize and confirmation passed"
        )
    finally:
        ui.close()
