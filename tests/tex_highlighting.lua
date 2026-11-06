vim.opt.rtp:prepend(vim.fn.getcwd())
for _, scheme in ipairs({ "theme-tools-mocha", "theme-tools-dracula", "theme-tools-mocha" }) do
  vim.cmd.colorscheme(scheme)
  for _, ft in ipairs({ "tex", "plaintex" }) do
    for _, kind in ipairs({ "macro", "type", "enumMember", "string", "comment", "property", "number", "operator" }) do
      local group = vim.api.nvim_get_hl(0, { name = "@lsp.type." .. kind .. "." .. ft, link = false })
      assert(not group.fg and not group.bg, kind .. "." .. ft)
      local modifier = vim.api.nvim_get_hl(0, { name = "@lsp.typemod." .. kind .. ".declaration." .. ft, link = false })
      assert(not modifier.underline and not modifier.fg and not modifier.bg)
    end
    local variable = vim.api.nvim_get_hl(0, { name = "@lsp.type.variable." .. ft, link = false })
    assert(variable.fg == vim.api.nvim_get_hl(0, { name = "@variable", link = false }).fg)
    local declaration = vim.api.nvim_get_hl(0, { name = "@lsp.mod.declaration." .. ft, link = false })
    assert(not declaration.underline and not declaration.fg)
  end
  assert(vim.api.nvim_get_hl(0, { name = "@lsp.type.macro", link = false }).fg)
  assert(not package.loaded["languages.latex.highlighting"])
end
local definitions = require("theme_tools.mocha.groups.custom")(require("theme_tools.mocha.palette"))
assert(definitions["@lsp.type.macro.tex"] and definitions["@lsp.type.variable.tex"].link == "@variable")
print("TeX theme groups: semantic policy survives scheme changes and preserves other languages")
