"""Both picker backends must separate brightness and keep group navigation inert."""
import json
import os
from pathlib import Path
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Grouped picker timed out")))
signal.alarm(35)
selection = Path(os.environ.get("THEME_TOOLS_SELECTION", Path(__file__).resolve().parent.parent.parent / "selection-tools.nvim"))

for backend in ("builtin", "selection_tools"):
    ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])

    def lua(code):
        return ui.request("nvim_exec_lua", [code, []])

    def keys(text):
        ui.request("nvim_input", [text])
        lua("vim.wait(40)")

    def screen():
        lua("vim.cmd('redraw!')")
        return "\n".join("".join(char for char, _ in row) for row in ui.grid)

    try:
        ui.request("nvim_ui_attach", [110, 36, {"rgb": True, "ext_linegrid": True}])
        ui.request("nvim_exec_lua", ["vim.opt.rtp:append(...)", [str(selection)]])
        lua("""
          vim.opt.rtp:prepend(vim.fn.getcwd())
          t=require('theme_tools'); path=vim.fn.tempname(); changes=0
          t.setup({catppuccin=false,dracula=false,state_file=path,default='night',
            picker={preview_mode='live',backend=""" + json.dumps(backend) + """},themes={
              {name='night',colorscheme='habamax',background='dark'},
              {name='dusk',colorscheme='desert',background='dark'},
              {name='day',colorscheme='morning',background='light'},
              {name='mystery',colorscheme='evening'},
            }})
          vim.api.nvim_create_autocmd('User',{pattern='ThemeToolsChanged',callback=function() changes=changes+1 end})
          vim.api.nvim_set_hl(0,'PersonalCheck',{fg='#123456'})
          assert(t.pick())
        """)
        text = screen()
        assert "Dark themes" in text and "Ctrl-G" in text, text
        assert "day" not in text and "mystery" not in text, text
        keys("<C-n>")
        assert lua("return vim.g.colors_name") == "desert"
        keys("day")
        assert "No " in screen()
        assert lua("return vim.g.colors_name") == "desert", "zero matches must retain the last preview"
        keys("<C-g>")
        text = screen()
        assert "Theme groups" in text and "Light themes" in text, text
        assert lua("return vim.g.colors_name") == "habamax"
        keys("<C-n>")
        assert lua("return vim.o.background") == "dark", "highlighting Light must not preview"
        keys("<CR>")
        text = screen()
        assert "Light themes" in text and "day" in text and "night" not in text, text
        assert lua("return vim.o.background") == "light"
        assert lua("return changes") == 0
        keys("<Esc>")
        assert lua("return vim.g.colors_name") == "habamax"
        assert lua("return vim.api.nvim_get_hl(0,{name='PersonalCheck'}).fg") == 0x123456
        lua("assert(t.pick())")
        keys("<C-g>")
        keys("<C-n><C-n>")
        assert lua("return vim.g.colors_name") == "habamax"
        keys("<CR>")
        assert "Unclassified" in screen() and "mystery" in screen()
        assert lua("return vim.g.colors_name") == "habamax", "unknown themes must not auto-preview"
        keys("<CR>")
        assert lua("return vim.g.colors_name") == "evening"
        assert lua("return changes") == 1
        assert lua("return vim.json.decode(table.concat(vim.fn.readfile(path))).name") == "mystery"
        lua("""
          assert(t.pick())
          local switch=vim.fn.maparg('<C-g>','i',false,true).callback
          switch()
          assert(t.set('night'))
          vim.wait(30)
          assert(#vim.api.nvim_list_wins()==1, 'a cancelled transition reopened the picker')
          assert(vim.g.colors_name=='habamax')
        """)
        lua("vim.fn.delete(path)")
        print(backend + ": brightness isolation, explicit group changes, inert category menu and unknown-theme confirmation passed")
    finally:
        ui.close()
