-- Personal Dracula highlights, applied after the inherited groups.
return function(c)
  local groups = {
    Normal = { fg = c.fg },
    NormalFloat = { fg = c.fg },
    SignColumn = {},
    StatusLine = { fg = c.white },
    TabLineFill = {},
    ThemeToolsAccent = { fg = c.purple },
    ThemeToolsGitAdd = { fg = c.green },
    ThemeToolsGitChange = { fg = c.yellow },
    ThemeToolsGitDelete = { fg = c.red },
    GitToolsAdd = { link = "ThemeToolsGitAdd" },
    GitToolsChange = { link = "ThemeToolsGitChange" },
    GitToolsDelete = { link = "ThemeToolsGitDelete" },
    MotionToolsMatch = { link = "Search" },
    MotionToolsLabel = { bg = c.pink, fg = c.black, bold = true },
    MotionToolsCurrent = { link = "CurSearch" },
    MotionToolsLens = { link = "Comment" },
    -- Like Mocha, selection adds a background without replacing column colors.
    PmenuSel = { bg = c.selection, bold = true },
    PmenuKind = { fg = c.cyan },
    PmenuKindSel = { fg = c.cyan, bg = c.selection, bold = true },
    PmenuExtra = { fg = c.comment },
    PmenuExtraSel = { fg = c.comment, bg = c.selection, bold = true },
    PmenuMatch = { fg = c.fg, bold = true },
    PmenuMatchSel = { bold = true },
  }
  for name, value in pairs(require("theme_tools.languages.tex").groups()) do
    groups[name] = value
  end
  return groups
end
