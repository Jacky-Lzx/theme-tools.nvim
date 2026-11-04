"""Exercise both icon selectors with native terminal input and real selection-tools."""

import json
import os
import signal
import tempfile
from pathlib import Path

from tui import Terminal

signal.signal(
    signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Icon TUI timed out"))
)
signal.alarm(50)
root = Path(__file__).resolve().parent.parent
selection = Path(
    os.environ.get("THEME_TOOLS_SELECTION", root.parent / "selection-tools.nvim")
)
assert selection.is_dir(), "selection-tools checkout is required"

with tempfile.TemporaryDirectory(prefix="/tmp/theme-icons-tui-") as directory:
    directory = Path(directory)
    for backend in ("builtin", "selection_tools"):
        state = directory / (backend + ".json")
        init = directory / (backend + ".lua")
        init.write_text(f"""
vim.opt.rtp:prepend({json.dumps(str(root))})
vim.opt.rtp:append({json.dumps(str(selection))})
vim.o.swapfile=false
icon_warnings={{}}
vim.notify=function(message) icon_warnings[#icon_warnings+1]=message end
require('selection_tools').setup({{keys={{next={{'<A-j>','<C-n>'}},previous={{'<A-k>','<C-p>'}}}}}})
t=require('theme_tools'); i=t.icons
t.setup({{catppuccin=false,dracula=false,persist=false,themes={{'habamax'}},default='habamax',
  picker={{backend={json.dumps(backend)}}},
  icons={{default='ascii',persist=true,state_file={json.dumps(str(state))},
    install={{root={json.dumps(str(directory / "managed"))},timeout=500}},
    sources={{mini={{url={json.dumps(str(directory / "missing"))}}}}}}}}})
vim.api.nvim_buf_set_lines(0,0,-1,false,{{'source text'}})
icon_events=0
i.on_change('test-ui',function() icon_events=icon_events+1 end)
vim.keymap.set('n','<F5>',i.pick)
""")
        term = Terminal(init, directory / (backend + ".sock"))
        try:
            assert term.lua("return i.current()") == "ascii"
            assert not state.exists()
            term.keys(b":ThemeToolsIcons\r")
            assert term.lua("return vim.fn.mode()") == "i"
            assert b"provider samples" in term.output
            if backend == "selection_tools":
                term.keys(b"\x1bj\x1bk")  # User's Alt-j / Alt-k mappings.
            else:
                term.keys(b"\x0e\x10")
            assert term.lua("return i.current()") == "ascii"
            term.keys(b"none")
            assert term.lua("return icon_events") == 1
            term.keys(b"\x1b")
            assert term.lua("return #vim.api.nvim_list_wins()") == 1
            assert term.lua("return i.current()") == "ascii" and not state.exists()
            term.keys(b":ThemeToolsIcons\rnone\r")  # Fast typeahead + confirmation.
            assert term.lua("return i.current()") == "none"
            assert term.lua("return i.get('file','init.lua')") == ""
            assert term.lua("return #vim.api.nvim_list_wins()") == 1
            assert json.loads(state.read_text())["name"] == "none"
            assert term.lua("return vim.g.colors_name") == "habamax"
            assert term.lua("return vim.api.nvim_get_current_line()") == "source text"
            term.keys(b":ThemeToolsIcons\rmini")
            term.keys(b"\r")
            assert term.lua("return i.current()") == "none", (
                "failed installation switched provider"
            )
            assert term.lua("return #vim.api.nvim_list_wins()") > 1, (
                "failure must keep selector open"
            )
            assert term.lua("return #icon_warnings") > 0
            term.keys(b"\x1b")
            # Repeated opens, empty results, resize, confirmation and editing.
            term.keys(b":ThemeToolsIcons\rzzzzzz")
            assert term.lua("return i.current()") == "none"
            term.resize(38, 16)
            term.drain(0.1)
            term.keys(b"\x1b")
            term.resize(90, 28)
            term.drain(0.1)
            term.keys(b":ThemeToolsIcons\rascii\r")
            assert term.lua("return i.current()") == "ascii"
            assert term.lua("return i.get('file','init.lua')") == "f"
            term.keys(b"A edited\x1b")
            assert (
                term.lua("return vim.api.nvim_get_current_line()")
                == "source text edited"
            )
            assert term.lua("return vim.fn.mode()") == "n"
        except Exception:
            print(backend, term.output[-5000:].decode(errors="replace"))
            raise
        finally:
            term.close()
        term = Terminal(init, directory / (backend + "-restart.sock"))
        try:
            assert term.lua("return i.current()") == "ascii"
            assert json.loads(state.read_text())["name"] == "ascii"
        finally:
            term.close()

print(
    "icon PTY: both selectors, Alt-j/k, cancellation, fast confirmation, failure, resize and restart passed"
)
