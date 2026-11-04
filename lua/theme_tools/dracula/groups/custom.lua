-- Personal Dracula highlights, applied after the inherited groups.
return function(c)
  return {
    Normal = { fg = c.fg },
    NormalFloat = { fg = c.fg },
    SignColumn = {},
    StatusLine = { fg = c.white },
    TabLineFill = {},
    -- Like Mocha, selection adds a background without replacing column colors.
    PmenuSel = { bg = c.selection, bold = true },
    PmenuKind = { fg = c.cyan },
    PmenuKindSel = { fg = c.cyan, bg = c.selection, bold = true },
    PmenuExtra = { fg = c.comment },
    PmenuExtraSel = { fg = c.comment, bg = c.selection, bold = true },
    PmenuMatch = { fg = c.fg, bold = true },
    PmenuMatchSel = { bold = true },
  }
end
