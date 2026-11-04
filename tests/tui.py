"""Run the real terminal UI, including Escape parsing, resize and restart."""
import fcntl
import json
import os
from pathlib import Path
import pty
import select
import signal
import socket
import struct
import tempfile
import termios
import time
from rpc import pack, unpack

root = Path(__file__).resolve().parent.parent


class Terminal:
    def __init__(self, init, address, before=None):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ["TERM"] = "xterm-256color"
            binary = os.environ.get("NVIM_BIN", "nvim")
            os.execvp(binary, [binary, "-n", *(before or []), "-u", str(init), "-i", "NONE", "--listen", str(address)])
        self.resize(90, 28)
        self.output = b""
        self.query_tail = b""
        self.serial = 0
        self.socket = socket.socket(socket.AF_UNIX)
        deadline = time.monotonic() + 5
        while True:
            try:
                self.socket.connect(str(address))
                break
            except (FileNotFoundError, ConnectionRefusedError):
                if time.monotonic() > deadline:
                    os.kill(self.pid, signal.SIGKILL)
                    os.waitpid(self.pid, 0)
                    os.close(self.fd)
                    raise TimeoutError("Terminal Neovim did not start: " + self.output.decode(errors="replace"))
                self.drain(0.02)
        self.socket.settimeout(5)
        self.stream = self.socket.makefile("rb", buffering=0)
        while self.lua("return vim.v.vim_did_enter") != 1:
            if time.monotonic() > deadline:
                self.close()
                raise TimeoutError("Neovim startup did not complete")
            self.drain(0.02)

    def resize(self, width, height):
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", height, width, 0, 0))
        os.kill(self.pid, signal.SIGWINCH)

    def drain(self, delay=0.08):
        deadline = time.monotonic() + delay
        while time.monotonic() < deadline:
            if select.select([self.fd], [], [], min(0.02, max(0, deadline - time.monotonic())))[0]:
                try:
                    chunk = os.read(self.fd, 65536)
                    self.output += chunk
                    # Behave like a terminal during startup color detection. A
                    # missing DSR reply makes Nvim draw an unrelated E1568 warning.
                    pending = self.query_tail + chunk
                    while b"\x1b[5n" in pending:
                        query, pending = pending.split(b"\x1b[5n", 1)
                        if b"\x1b]11;?" in query:
                            os.write(self.fd, b"\x1b]11;rgb:1e1e/1e1e/2e2e\x07")
                        os.write(self.fd, b"\x1b[0n")
                    self.query_tail = pending[-64:]
                except OSError:
                    break

    def lua(self, code):
        self.drain(0.02)
        self.serial += 1
        self.socket.sendall(pack([0, self.serial, "nvim_exec_lua", [code, []]]))
        while True:
            message = unpack(self.stream)
            if message[0] == 1 and message[1] == self.serial:
                if message[2] is not None:
                    raise RuntimeError(message[2])
                return message[3]

    def keys(self, value):
        os.write(self.fd, value)
        self.drain(0.15)
        self.lua("return 1")

    def close(self):
        self.stream.close()
        self.socket.close()
        os.kill(self.pid, signal.SIGTERM)
        deadline = time.monotonic() + 2
        while time.monotonic() < deadline:
            if os.waitpid(self.pid, os.WNOHANG)[0]:
                break
            self.drain(0.02)
        else:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        os.close(self.fd)


def main():
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("Theme TUI timed out")))
    signal.alarm(40)
    with tempfile.TemporaryDirectory(prefix="/tmp/theme-tui-") as directory:
        directory = Path(directory)
        init = directory / "init.lua"
        state = directory / "selection.json"
        init.write_text(f"""vim.opt.rtp:prepend({json.dumps(str(root))})
    vim.o.swapfile=false
    t=require('theme_tools')
    t.setup({{catppuccin=false,state_file={json.dumps(str(state))},picker={{group_by_background=false,preview_mode='live'}},default='habamax',themes={{'habamax','morning','desert'}}}})
    vim.keymap.set('n','<F5>',t.pick)
    """)
        term = Terminal(init, directory / "first.sock")
        try:
            term.keys(b":ThemeTools\r")
            assert term.lua("return vim.fn.mode()") == "i"
            assert b"Themes" in term.output and b"morning" in term.output
            term.keys(b"\x0e")  # Ctrl-N through the terminal input decoder.
            assert term.lua("return vim.g.colors_name") == "morning"
            term.keys(b"\x1b")
            assert term.lua("return vim.fn.mode()") == "n"
            assert term.lua("return #vim.api.nvim_list_wins()") == 1
            assert term.lua("return vim.g.colors_name") == "habamax"
            term.keys(b":ThemeTools\rmorn")
            assert term.lua("return vim.g.colors_name") == "morning"
            term.resize(30, 13)
            term.drain(0.1)
            assert term.lua("return vim.o.columns") == 30
            assert term.lua("return #vim.api.nvim_list_wins()") >= 4
            term.keys(b"\r")
            assert term.lua("return vim.fn.mode()") == "n"
            assert json.loads(state.read_text())["name"] == "morning"
            term.keys(b"ieditor text\x1b")
            assert term.lua("return vim.api.nvim_get_current_line()") == "editor text"
        finally:
            term.close()
        term = Terminal(init, directory / "second.sock")
        try:
            actual = term.lua("return vim.g.colors_name")
            assert actual == "morning", (actual, state.read_text())
            assert term.lua("return vim.o.background") == "light"
        finally:
            term.close()
    print("PTY: native input, Escape, live preview, SIGWINCH, editing and persisted restart passed")


if __name__ == "__main__":
    main()
