"""Match backgrounds must retain text colors, including syntax and selected rows."""
import os
import signal
from rpc import Capture

signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Search UI timed out")))
signal.alarm(20)
ui = Capture(os.environ.copy(), ["-u", "NONE", "-i", "NONE", "--noplugin"])


def lua(code):
    return ui.request("nvim_exec_lua", [code, []])


def matches():
    lua("vim.cmd('redraw!')")
    rows = []
    for row in ui.grid:
        text = "".join(char for char, _ in row)
        if "target one" in text or "target two" in text:
            start = text.index("target")
            rows.append([ui.attrs[attr] for _, attr in row[start:start + 6]])
    assert len(rows) == 2, rows
    return rows


try:
    ui.request("nvim_ui_attach", [100, 34, {"rgb": True, "ext_linegrid": True}])
    lua("""
      vim.opt.rtp:prepend(vim.fn.getcwd())
      vim.opt.rtp:append(vim.fn.getcwd()..'/../selection-tools.nvim')
      t=require('theme_tools')
      t.setup({persist=false,catppuccin=false,dracula=false,icons={default='none'},
        themes={'theme-tools-mocha','theme-tools-dracula'},default='theme-tools-mocha'})
      function open_picker()
        vim.api.nvim_set_hl(0,'SearchTestSyntax',{fg='#abcdef'})
        p=require('selection_tools').open({items={'target one','target two'},query='target',
          highlight_item=function() return {{0,10,hl='SearchTestSyntax',priority=100}} end,
          history={persist=false},layout={width=60,height=12}})
        vim.wait(20)
      end
      open_picker()
    """)
    for row in matches():
        assert all(a.get("foreground") == 0xABCDEF and a.get("background") == 0x604482 for a in row), row
    # Explicit theme foregrounds still override syntax, and rollback restores inheritance.
    lua("""
      p:close(); vim.cmd.stopinsert()
      original=require('theme_tools.colors').snapshot()
      assert(require('theme_tools.colors').apply({colorscheme='theme-tools-dracula'}))
      open_picker()
    """)
    for row in matches():
        assert all(a.get("foreground") == 0x191A21 and a.get("background") == 0xFFB86C for a in row), row
    lua("p:close(); vim.cmd.stopinsert(); require('theme_tools.colors').restore(original); open_picker()")
    for row in matches():
        assert all(a.get("foreground") == 0xABCDEF for a in row), row
finally:
    ui.close()
print("search UI: inherited syntax foregrounds, selected rows, explicit colors and preview rollback passed")
