"""Git icon colors must preserve both editor and selected-row backgrounds."""
import os
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Git icons UI timed out")))
signal.alarm(20)
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code, args=None):
    return ui.request("nvim_exec_lua", [code, args or []])


try:
    ui.request("nvim_ui_attach", [80, 24, {"rgb": True, "ext_linegrid": True}])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd());vim.wo.number=false;vim.wo.signcolumn='no';vim.o.laststatus=0
      t=require('theme_tools');t.setup({persist=false,catppuccin=false,dracula=false,icons={default='ascii'},
        themes={'theme-tools-mocha','theme-tools-dracula','morning'},default='theme-tools-mocha'})
      function draw_icons()
        local api=vim.api
        api.nvim_set_hl(0,'Normal',{fg='#ffffff',bg='#171720'})
        api.nvim_set_hl(0,'GitIconsSelected',{bg='#334455'})
        api.nvim_buf_set_lines(0,0,-1,false,{'+  ~  -','+  ~  -'})
        local ns=api.nvim_create_namespace('GitIconsUI');api.nvim_buf_clear_namespace(0,ns,0,-1)
        api.nvim_buf_set_extmark(0,ns,0,0,{line_hl_group='GitIconsSelected',priority=90})
        for index,name in ipairs({'added','modified','removed'}) do
          local _,group=t.icons.get('git',name)
          for row=0,1 do api.nvim_buf_set_extmark(0,ns,row,(index-1)*3,
            {end_col=(index-1)*3+1,hl_group=group,priority=120}) end
        end
        vim.cmd('redraw!')
      end
    """)
    for theme in ("theme-tools-mocha", "theme-tools-dracula", "morning"):
        lua("assert(t.set(...));draw_icons()", [theme])
        palette = lua("return t.palette()")
        lua("return true")
        for row, bg in ((0, 0x334455), (1, 0x171720)):
            for col, role in ((0, "add"), (3, "change"), (6, "delete")):
                attrs = ui.attrs[ui.grid[row][col][1]]
                assert attrs.get("foreground") == int(palette["git"][role][1:], 16), (theme, role, attrs)
                assert attrs.get("background", ui.bg) == bg, (theme, role, attrs)
finally:
    ui.close()
print("Git icons UI: semantic foregrounds preserve normal and selected surfaces across dark/light themes")
