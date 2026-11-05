"""Check separate menu/doc borders and the richer isolated sample in real cells."""
import os
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Surface UI timed out")))
signal.alarm(30)
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code):
    return ui.request("nvim_exec_lua", [code, []])


def frame():
    lua("vim.cmd('redraw!')")
    lua("return true")


try:
    ui.request("nvim_ui_attach", [120, 60, {"rgb": True, "ext_linegrid": True}])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd());vim.opt.rtp:append(vim.fn.getcwd()..'/../completion-tools.nvim')
      t=require('theme_tools');t.setup({persist=false,catppuccin=false,dracula=false,icons={default='ascii'},
        default='theme-tools-dracula',themes={
          {name='theme-tools-dracula',colorscheme='theme-tools-dracula',transparent=false},'theme-tools-mocha'}})
      c=require('completion-tools');c.setup({auto_show=false,sources={'fixture'},min_keyword_length=0,
        providers={fixture={complete=function(_,done)
          done({items={{label='hello',kind=3,documentation='Documentation text'}}})
        end}},documentation={auto_show=true,delay_ms=0}})
    """)
    ui.request("nvim_input", ["ihel"])
    lua("vim.wait(20);c.show();assert(vim.wait(1000,function()return c.is_menu_visible()end))")
    ui.request("nvim_input", ["<C-n>"])
    lua("""
      assert(vim.wait(1000,function()
        for _,win in ipairs(vim.api.nvim_list_wins()) do
          local map=vim.wo[win].winhighlight
          if map:find('CompletionToolsDocBorder',1,true) then doc=win end
          if vim.bo[vim.api.nvim_win_get_buf(win)].filetype=='completion-tools-menu' then menu=win end
        end
        return doc and menu
      end))
    """)
    for win, background in (("menu", 0x21222C), ("doc", 0x282A36)):
        position = lua("return vim.api.nvim_win_get_config(" + win + ")")
        frame()
        # Config coordinates identify the top border of these editor-relative floats.
        attr = ui.attrs[ui.grid[int(position["row"])][int(position["col"])][1]]
        assert attr.get("background", ui.bg) == background, (win, position, attr)
    lua("""
      c.dispose();vim.cmd.stopinsert()
      original=require('theme_tools.colors').snapshot()
      viewer=require('theme_tools.preview').new()
      viewer:show({name='sample',colorscheme='theme-tools-mocha',background='dark'},function(value,err)
        assert(not err,err);sample_frame=value
      end)
      assert(vim.wait(3000,function()return sample_frame~=nil end))
      sample_buf=vim.api.nvim_create_buf(false,true)
      sample_win=vim.api.nvim_open_win(sample_buf,false,{relative='editor',row=1,col=1,width=105,height=50,style='minimal'})
      require('theme_tools.sample').draw(sample_buf,sample_win,{name='sample'},sample_frame)
      assert(vim.deep_equal(original,require('theme_tools.colors').snapshot()),'sample changed host highlights')
      assert(t.icons.current()=='ascii' and not package.loaded['nvim-web-devicons'])
    """)
    frame()
    screen = "\n".join("".join(char for char, _ in row) for row in ui.grid)
    for word in ("f init.lua", "R Build running", "O Tests passed", "F Lint failed", "[Copilot]", "+12 ~3 -2"):
        assert word in screen, word
    for row in ui.grid:
        text = "".join(char for char, _ in row)
        if "[Copilot]" in text:
            start = text.index("[Copilot]")
            assert all(ui.attrs[a].get("foreground") == 0xCBA6F7 for _, a in row[start:start + 9])
    lua("viewer:close();vim.api.nvim_win_close(sample_win,true)")
finally:
    ui.close()
print("surfaces UI: matching menu/doc borders, semantic preview samples, icon policy and host isolation passed")
