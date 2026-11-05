"""Inspect live theme colors and selection-tools UI using the actual checkout."""
import os
from pathlib import Path
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Selection theme UI timed out")))
signal.alarm(30)
selection = Path(os.environ.get("THEME_TOOLS_SELECTION", Path(__file__).resolve().parent.parent.parent / "selection-tools.nvim"))
assert selection.is_dir(), "selection-tools checkout is required"
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code):
    return ui.request("nvim_exec_lua", [code, []])


def keys(text):
    ui.request("nvim_input", [text])
    lua("vim.wait(30)")


def screen():
    lua("vim.cmd('redraw!')")
    return "\n".join("".join(char for char, _ in row) for row in ui.grid)


try:
    ui.request("nvim_ui_attach", [100, 34, {"rgb": True, "ext_linegrid": True}])
    ui.request("nvim_exec_lua", ["vim.opt.rtp:append(...)", [str(selection)]])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd())
      s=require('selection_tools'); t=require('theme_tools')
      local original=s.open
      s.open=function(...) p=original(...); return p end
      s.setup({keys={next={'<A-j>','<C-n>','<Down>'},previous={'<A-k>','<C-p>','<Up>'}}})
      path=vim.fn.tempname()
      t.setup({catppuccin=false,state_file=path,picker={backend='selection_tools',group_by_background=false,preview_mode='live'},themes={'habamax','morning','desert'}})
      assert(t.set('habamax')); assert(t.pick())
    """)
    assert "Themes" in screen() and "morning" in screen()
    keys("<A-j>")
    assert lua("return vim.g.colors_name") == "morning"
    screen()
    light_bg = ui.bg
    assert lua("""
      return vim.api.nvim_get_hl(0,{name='SelectionToolsSelected',link=false}).bg
        == vim.api.nvim_get_hl(0,{name='Visual',link=false}).bg
    """)
    keys("<A-k><Down>")
    assert lua("return vim.g.colors_name") == "morning"
    keys("<Esc>")
    assert lua("return #vim.api.nvim_list_wins()") == 1
    assert lua("return vim.fn.mode()") == "n"
    screen()
    assert ui.bg != light_bg
    assert lua("return vim.g.colors_name") == "habamax"
    lua("assert(t.pick())")
    keys("des<CR>")
    assert lua("return vim.g.colors_name") == "desert"
    assert lua("return #vim.api.nvim_list_wins()") == 1
    assert lua("return vim.json.decode(table.concat(vim.fn.readfile(path))).name") == "desert"
    lua("assert(t.pick())")
    keys("zzzzzz")
    assert "No results" in screen(), screen()
    assert lua("return vim.g.colors_name") == "desert"
    keys("<C-u>morn")
    assert lua("return vim.g.colors_name") == "morning"
    ui.request("nvim_ui_try_resize", [26, 12])
    lua("vim.wait(30)")
    assert "morning" in screen(), screen()
    keys("<C-c>")
    assert lua("return vim.g.colors_name") == "desert"
    assert lua("return #vim.api.nvim_list_wins()") == 1
    print("selection UI: inherited mappings, live colors, rapid search/confirm, zero matches, resize and cancellation passed")
finally:
    ui.close()
