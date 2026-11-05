"""Exercise diagnostic report focus, resize, refresh and close in a real UI."""
import os
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Theme info UI timed out")))
signal.alarm(25)
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code):
    return ui.request("nvim_exec_lua", [code, []])


def input_keys(keys):
    ui.request("nvim_input", [keys])
    lua("vim.wait(30);vim.cmd('redraw!')")
    lua("return true")


def screen():
    return "\n".join("".join(cell[0] for cell in row) for row in ui.grid)


try:
    ui.request("nvim_ui_attach", [100, 36, {"rgb": True, "ext_linegrid": True}])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd());vim.o.laststatus=0
      t=require('theme_tools');t.setup({persist=false,catppuccin=false,dracula=false,
        themes={'theme-tools-dracula','morning'},default='theme-tools-dracula',icons={default='mini',persist=false}})
      api=vim.api;source=api.nvim_get_current_buf();source_win=api.nvim_get_current_win()
      api.nvim_buf_set_lines(source,0,-1,false,{'unsaved source'})
      api.nvim_set_hl(0,'InfoUI',{link='NormalFloat'})
      vim.wo.number=true;vim.wo.relativenumber=true;vim.wo.foldenable=true
    """)
    for width, height, close in ((100, 36, "q"), (56, 16, "<Esc>")):
        ui.request("nvim_ui_try_resize", [width, height])
        lua("assert(t.set('theme-tools-dracula'));api.nvim_set_hl(0,'InfoUI',{link='NormalFloat'});vim.cmd('ThemeToolsInfo InfoUI');report_buf=api.nvim_get_current_buf();report_win=api.nvim_get_current_win();vim.cmd('redraw!')")
        lua("return true")
        assert "Theme tools" in screen() and "unsaved source" in screen(), screen()
        assert lua("return not vim.bo.modifiable and not vim.wo.number and not vim.wo.relativenumber and not vim.wo.foldenable")
        input_keys("G")
        assert "InfoUI -> NormalFloat" in screen(), screen()
        lua("assert(t.set('morning'))")
        input_keys("rgg")
        assert "Colorscheme: morning" in screen(), screen()
        input_keys("G")
        assert "undefined" in screen(), screen()
        input_keys(close)
        assert lua("return api.nvim_get_current_win()==source_win and not api.nvim_buf_is_valid(report_buf) and not api.nvim_win_is_valid(report_win)")
        assert lua("return vim.bo[source].modified and api.nvim_buf_get_lines(source,0,-1,false)[1]=='unsaved source'")
    assert lua("return not package.loaded['mini.icons'] and not package.loaded['theme_tools.icons.providers']")
finally:
    ui.close()
print("theme info UI: wide/narrow layouts, scrolling, live refresh, focus and unsaved source preservation passed")
