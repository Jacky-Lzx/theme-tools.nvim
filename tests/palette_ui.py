"""Palette reads must ignore the active window's highlight remapping."""
import os
from rpc import Capture

ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])
try:
    ui.request("nvim_ui_attach", [90, 28, {"rgb": True, "ext_linegrid": True}])
    ui.request("nvim_exec_lua", ["""
      vim.opt.rtp:prepend(vim.fn.getcwd())
      themes=require('theme_tools')
      themes.setup({persist=false,catppuccin=false,dracula=false,
        default='theme-tools-mocha',themes={'theme-tools-mocha'}})
      original=themes.palette()
      local api=vim.api
      api.nvim_set_hl(0,'FakeNormal',{bg='#ff0000'})
      api.nvim_set_hl(0,'FakeAccent',{fg='#ff0000'})
      floating=api.nvim_open_win(api.nvim_create_buf(false,true),true,
        {relative='editor',row=1,col=1,width=25,height=5})
      vim.wo[floating].winhighlight='Normal:FakeNormal,Function:FakeAccent,FloatBorder:FakeAccent'
      vim.cmd.redraw()
    """, []])
    ui.request("nvim_exec_lua", ["""
      local mapped=vim.api.nvim_get_hl(0,{name='Normal',link=false})
      assert(mapped.bg==0xff0000,'test did not activate window remapping')
      themes.refresh_palette()
      assert(vim.deep_equal(original,themes.palette()),'window colors contaminated the global palette')
      vim.api.nvim_win_close(floating,true)
      assert(vim.deep_equal(original,themes.palette()))
    """, []])
finally:
    ui.close()
print("palette UI: global semantic colors ignore active floating-window remapping")
