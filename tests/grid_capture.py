"""Render an actual Neovim grid captured by tests.rpc as an optional PNG."""

import html
import os
import subprocess
from pathlib import Path


def capture(ui, name):
    destination = os.environ.get("THEME_TOOLS_CAPTURE_DIR")
    if not destination:
        return
    directory = Path(destination)
    directory.mkdir(parents=True, exist_ok=True)
    cell_width, cell_height = 11, 22
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{len(ui.grid[0]) * cell_width}" height="{len(ui.grid) * cell_height}">'
    ]
    for row, cells in enumerate(ui.grid):
        for col, (char, attribute) in enumerate(cells):
            attrs = ui.attrs.get(attribute, {})
            fg, bg = attrs.get("foreground", ui.fg), attrs.get("background", ui.bg)
            if attrs.get("reverse"):
                fg, bg = bg, fg
            x, y = col * cell_width, row * cell_height
            svg.append(
                f'<rect x="{x}" y="{y}" width="{cell_width}" height="{cell_height}" fill="#{bg:06x}"/>'
            )
            if char and char != " ":
                svg.append(
                    f'<text x="{x}" y="{y + 17}" fill="#{fg:06x}" font-family="Cascadia Mono NF,monospace" font-size="17" font-weight="{"bold" if attrs.get("bold") else "normal"}">{html.escape(char)}</text>'
                )
    svg.append("</svg>")
    path = directory / (name + ".svg")
    path.write_text("".join(svg))
    subprocess.run(
        ["rsvg-convert", str(path), "-o", str(directory / (name + ".png"))], check=True
    )
