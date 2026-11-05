"""Check rendered completion colors and the isolated independent Dracula preview."""
import os
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Dracula UI timed out")))
signal.alarm(40)
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code):
    return ui.request("nvim_exec_lua", [code, []])


def keys(value):
    ui.request("nvim_input", [value])
    lua("vim.wait(60); vim.cmd('redraw!')")


def cells(word):
    lua("vim.cmd('redraw!')")
    for row in ui.grid:
        text = "".join(char for char, _ in row)
        if "hello" in text and word in text:
            start = text.index(word)
            return [ui.attrs[attr] for _, attr in row[start:start + len(word)]]
    raise AssertionError("missing menu text: " + word)


try:
    ui.request("nvim_ui_attach", [100, 34, {"rgb": True, "ext_linegrid": True}])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd())
      vim.opt.rtp:append(vim.fn.getcwd()..'/../completion-tools.nvim')
      t=require('theme_tools')
      t.setup({persist=false,catppuccin=false,dracula=false,
        themes={'theme-tools-dracula','theme-tools-mocha'},default='theme-tools-dracula'})
      c=require('completion_tools')
      c.setup({auto_show=false,sources={'fixture'},min_keyword_length=0,
        providers={fixture={complete=function(_,done)
          done({items={{label='hello',kind=3},{label='help',kind=3}}})
        end}},menu={columns={{'label'},{'kind'},{'source'}},highlight={treesitter=false}},
        documentation={auto_show=false}})
    """)
    keys("ihel")
    lua("c.show(); assert(vim.wait(2000,function() return c.is_menu_visible() end))")
    # Capture each column's unselected color, then ensure selection preserves it.
    before = {word: cells(word)[0]["foreground"] for word in ("hello", "Function", "fixture")}
    keys("<C-n>")
    assert lua("return c.get_selected_item().label") == "hello"
    for word, color in before.items():
        attributes = cells(word)
        assert all(a.get("foreground") == color for a in attributes), (word, attributes)
        assert all(a.get("background") == 0x44475A and a.get("bold") for a in attributes), (word, attributes)
    keys("<Tab><Esc>")
    assert lua("return vim.api.nvim_get_current_line()") == "hello()"
    lua("c.dispose(); assert(t.set('theme-tools-mocha')); assert(t.pick())")
    keys("dracula")
    assert lua("""
      return vim.wait(5000,function()
        for _,win in ipairs(vim.api.nvim_list_wins()) do
          local buf=vim.api.nvim_win_get_buf(win)
          if vim.b[buf].theme_tools_preview=='theme-tools-dracula'
            and not vim.b[buf].theme_tools_preview_error then
            preview_win=win; return true
          end
        end
      end)
    """)
    assert lua("return vim.g.colors_name") == "theme-tools-mocha"
    # Transparent preview must use Dracula's base rather than the generic fallback.
    preview = lua("""
      local ns=vim.api.nvim_get_hl_ns({winid=preview_win})
      return {normal=vim.api.nvim_get_hl(ns,{name='Normal'}),selected=vim.api.nvim_get_hl(ns,{name='PmenuSel'})}
    """)
    assert preview["normal"]["bg"] == 0x282A36, preview
    assert preview["selected"]["bg"] == 0x44475A and not preview["selected"].get("fg"), preview
    keys("<CR>")
    assert lua("return vim.g.colors_name") == "theme-tools-dracula"
    assert lua("return package.loaded.dracula == nil and package.loaded.catppuccin == nil")
finally:
    ui.close()
print("Dracula UI: selected completion keeps column colors, acceptance, isolated preview canvas and confirmation passed")
