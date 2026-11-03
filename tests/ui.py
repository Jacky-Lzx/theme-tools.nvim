"""Exercise actual redraw colors, search, navigation, cancel, confirmation and resize."""
import os
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Theme UI timed out")))
signal.alarm(45)
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code):
    return ui.request("nvim_exec_lua", [code, []])


def keys(text):
    ui.request("nvim_input", [text])
    lua("vim.wait(40)")


def screen():
    lua("vim.cmd('redraw!')")
    return "\n".join("".join(char for char, _ in row) for row in ui.grid)


def closed():
    assert lua("return #vim.api.nvim_list_wins()") == 1
    assert lua("return vim.fn.mode()") == "n"
    assert lua("return vim.api.nvim_get_current_buf() == source")


try:
    ui.request("nvim_ui_attach", [100, 34, {"rgb": True, "ext_linegrid": True}])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd())
      t=require('theme_tools'); colors=require('theme_tools.colors')
      source=vim.api.nvim_get_current_buf()
      vim.api.nvim_buf_set_lines(source,0,-1,false,{'local answer = 42','return answer'})
      vim.bo.filetype='lua'; vim.cmd('syntax on')
      path=vim.fn.tempname()
      t.setup({catppuccin=false,state_file=path,picker={group_by_background=false,preview_mode='live'},themes={'habamax','morning','desert'}})
      assert(t.set('habamax'))
      vim.api.nvim_set_hl(0,'UserCustom',{fg='#123456',bold=true})
      original=colors.snapshot()
      changed=0
      vim.api.nvim_create_autocmd('User',{pattern='ThemeToolsChanged',callback=function() changed=changed+1 end})
      assert(t.pick())
    """)
    assert "Filter themes" in screen() and "morning" in screen()
    assert lua("return vim.fn.mode()") == "i"
    initial_bg = ui.bg
    keys("<Down>")
    assert lua("return vim.g.colors_name") == "morning"
    assert lua("return vim.o.background") == "light"
    screen()
    assert ui.bg != initial_bg, "whole-editor background should preview immediately"
    assert lua("return changed") == 0
    assert lua("return vim.json.decode(table.concat(vim.fn.readfile(path))).name") == "habamax"
    keys("<Esc>")
    closed()
    assert lua("return vim.g.colors_name") == "habamax"
    assert lua("return vim.o.background") == "dark"
    assert lua("return vim.deep_equal(original.highlights.UserCustom,vim.api.nvim_get_hl(0,{name='UserCustom'}))")
    lua("assert(t.pick())")
    keys("MoRn")
    assert "morning" in screen() and "desert" not in screen(), screen()
    assert lua("return vim.g.colors_name") == "morning"
    keys("<CR>")
    closed()
    assert lua("return changed") == 1
    assert lua("return vim.json.decode(table.concat(vim.fn.readfile(path))).name") == "morning"
    # Pending text changes must be consumed before an immediate Enter mapping.
    lua("assert(t.pick())")
    keys("des<CR>")
    closed()
    assert lua("return vim.g.colors_name") == "desert"
    # Reopening while previewing must select the restored committed theme.
    lua("assert(t.set('morning')); assert(t.pick())")
    keys("<Down>")
    assert lua("return vim.g.colors_name") == "desert"
    lua("assert(t.pick())")
    assert lua("return vim.g.colors_name") == "morning"
    keys("<CR>")
    closed()
    assert lua("return vim.json.decode(table.concat(vim.fn.readfile(path))).name") == "morning"
    lua("assert(t.pick())")
    keys("zzzz")
    assert "No matching themes" in screen(), screen()
    keys("<CR>")
    assert lua("return #vim.api.nvim_list_wins()") == 3
    keys("<C-u>des")
    assert lua("return vim.g.colors_name") == "desert"
    ui.request("nvim_ui_try_resize", [28, 12])
    lua("vim.wait(30)")
    assert "desert" in screen(), screen()
    keys("<C-c>")
    closed()
    assert lua("return vim.g.colors_name") == "morning"
    ui.request("nvim_ui_try_resize", [100, 34])
    lua("assert(t.pick())")
    keys("<C-n><C-p><Tab><S-Tab><Up><Up><Up>")
    assert lua("return vim.g.colors_name") == "habamax"
    lua("assert(t.set('desert')); vim.wait(30)")
    closed()
    assert lua("return vim.g.colors_name") == "desert"
    lua("assert(t.pick()); vim.cmd('wincmd p'); vim.wait(30)")
    closed()
    lua("assert(t.pick()); vim.api.nvim_win_close(vim.api.nvim_get_current_win(),true); vim.wait(30)")
    closed()
    lua("assert(t.pick())")
    ui.request("nvim_ui_try_resize", [14, 6])
    lua("vim.wait(30)")
    closed()
    ui.request("nvim_ui_try_resize", [100, 34])
    lua("assert(t.pick()); assert(t.pick()); t.close(); vim.wait(30)")
    closed()
    keys("iuser text<Esc>")
    assert lua("return vim.api.nvim_get_current_line()") == "user textlocal answer = 42"
    assert not lua("return vim.fn.exists('#ThemeToolsPicker') == 1")
    catppuccin = os.environ.get("THEME_TOOLS_CATPPUCCIN")
    if catppuccin:
        ui.request("nvim_exec_lua", ["vim.opt.rtp:prepend(...)", [catppuccin]])
        lua("""
          require('catppuccin').setup({auto_integrations=false,integrations={}})
          t.setup({catppuccin=false,persist=false,picker={group_by_background=false,preview_mode='live'},themes={'catppuccin-mocha','catppuccin-latte','catppuccin-frappe','catppuccin-macchiato'}})
          assert(t.set('catppuccin-mocha')); assert(t.pick())
        """)
        keys("<Down>")
        assert lua("return vim.g.colors_name") == "catppuccin-latte"
        assert lua("return vim.o.background") == "light"
        assert "catppuccin-latte" in screen()
        keys("<Down><Down><Esc>")
        assert lua("return vim.g.colors_name") == "catppuccin-mocha"
        closed()
        lua("t.register('catppuccin-nvim'); assert(t.set('catppuccin-nvim'))")
        assert lua("return t.current()") == "catppuccin-nvim"
        lua("assert(t.next())")
        assert lua("return t.current()") == "catppuccin-mocha"
        print("real Catppuccin: all four flavours and cancel passed")
    print("UI: live redraw, continuous keys, search, save, cancel, resize and lifecycle passed")
finally:
    ui.close()
