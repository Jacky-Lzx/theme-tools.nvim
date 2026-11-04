vim.opt.rtp:prepend(vim.fn.getcwd())
local checkout = vim.env.THEME_TOOLS_SELECTION or vim.fn.fnamemodify(vim.fn.getcwd(), ":h") .. "/selection-tools.nvim"
assert(vim.fn.isdirectory(checkout) == 1, "selection-tools integration requires its real checkout")
vim.opt.rtp:append(checkout)
local selection, themes = require("selection_tools"), require("theme_tools")
local original_select, picker = selection.select
selection.select = function(...)
  picker = original_select(...)
  return picker
end
local notices, changed = {}, 0
vim.notify = function(message)
  notices[#notices + 1] = message
end
local path = vim.fn.tempname()
local opts = {
  catppuccin = false,
  state_file = path,
  picker = { backend = "selection_tools", group_by_background = false, preview_mode = "live" },
  themes = {
    "habamax",
    "morning",
    {
      name = "broken",
      colorscheme = "habamax",
      before = function()
        error("broken theme")
      end,
    },
    "desert",
  },
}
themes.setup(opts)
assert(themes.set("habamax"))
vim.api.nvim_create_autocmd("User", {
  pattern = "ThemeToolsChanged",
  callback = function()
    changed = changed + 1
  end,
})
vim.api.nvim_set_hl(0, "UserCustom", { fg = "#123456", bold = true })
assert(themes.pick())
assert(picker:current().name == "habamax")
assert(not picker.opts.resume and not picker.opts.multi and not picker.preview_win)
picker:move(1)
assert(vim.g.colors_name == "morning" and changed == 0)
assert(vim.json.decode(table.concat(vim.fn.readfile(path))).name == "habamax")
picker:set_query("no matching theme")
assert(vim.g.colors_name == "habamax")
local selected_hl = vim.api.nvim_get_hl(0, { name = "SelectionToolsSelected", link = false })
local visual_hl = vim.api.nvim_get_hl(0, { name = "Visual", link = false })
assert(selected_hl.bg == visual_hl.bg, vim.inspect(selected_hl))
picker:close()
assert(vim.api.nvim_get_hl(0, { name = "UserCustom" }).fg == 0x123456)
assert(themes.pick())
picker:set_query("broken")
assert(vim.g.colors_name == "habamax")
picker:confirm()
assert(not picker.closed and changed == 0)
assert(notices[#notices]:find("broken theme", 1, true))
picker:set_query("desert")
picker:confirm()
assert(picker.closed and vim.g.colors_name == "desert" and changed == 1)
assert(vim.json.decode(table.concat(vim.fn.readfile(path))).name == "desert")
assert(themes.pick())
assert(picker:current().name == "desert", "active theme should be initially selected")
picker:move(1)
assert(vim.g.colors_name == "habamax")
assert(themes.pick())
assert(picker:current().name == "desert" and vim.g.colors_name == "desert")
local old = picker
assert(themes.set("morning"))
assert(old.closed and vim.g.colors_name == "morning")
old:move(1)
assert(vim.g.colors_name == "morning")
assert(themes.pick())
picker:move(1)
themes.setup(opts)
assert(picker.closed and vim.g.colors_name == "morning")
assert(#vim.api.nvim_list_wins() == 1)
themes.setup({
  catppuccin = false,
  persist = false,
  themes = { "habamax" },
  picker = {
    backend = "selection_tools",
    selection = { layout = { border = "invalid-border" } },
  },
})
assert(not themes.pick())
assert(#vim.api.nvim_list_wins() == 1)
vim.fn.delete(path)
print("selection integration: live preview, cancel, failed confirmation, replacement and state passed")
