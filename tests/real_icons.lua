-- Optional network acceptance test; the normal suite uses local Git fixtures.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local icons = require("theme_tools").icons
local root = assert(vim.env.THEME_TOOLS_ICON_ROOT, "set THEME_TOOLS_ICON_ROOT to an isolated installation directory")
icons.setup({ persist = false, install = { root = root, timeout = 30000 } })
assert(icons.install())
for _, name in ipairs({ "devicons", "mini" }) do
  assert(icons.set(name))
  assert(#icons.catalog() > 50, name .. ": managed inventory is incomplete")
  for _, pair in ipairs({
    { "file", "/tmp/init.lua" },
    { "extension", "lua" },
    { "filetype", "lua" },
    { "directory", "src" },
    { "os", "linux" },
    { "lsp", "Function" },
    { "diagnostic", "error" },
  }) do
    local icon, hl = icons.get(pair[1], pair[2])
    assert(type(icon) == "string" and icon ~= "" and type(hl) == "string", name .. ": " .. pair[1])
    assert(vim.fn.strdisplaywidth(icon) > 0)
  end
  vim.cmd.colorscheme("morning")
  local _, hl = icons.get("file", "init.lua")
  assert(next(vim.api.nvim_get_hl(0, { name = hl, link = false })), name .. ": missing icon highlights")
  vim.cmd.colorscheme("habamax")
end
assert(icons.update())
print("real icon sources: pinned downloads, both adapters, light/dark highlights and updates passed")
