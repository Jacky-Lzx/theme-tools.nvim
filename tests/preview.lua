vim.opt.rtp:prepend(vim.fn.getcwd())
local colors = require("theme_tools.colors")
local accent = { fg = "#123abc" }
require("theme_tools").setup({
  persist = false,
  catppuccin = false,
  dracula = false,
  default = "habamax",
  themes = { "habamax" },
  picker = {
    preview_after = function()
      vim.api.nvim_set_hl(0, "PreviewOnly", accent)
      vim.g.preview_after_called = true
    end,
  },
})
local original = colors.snapshot()
local palettes = 0
require("theme_tools").on_change("preview-test", function()
  palettes = palettes + 1
end)
local viewer = require("theme_tools.preview").new()
local frame, failure
viewer:show({ name = "day", colorscheme = "morning", background = "light" }, function(result, err)
  frame, failure = result, err
end)
assert(
  vim.wait(5000, function()
    return frame ~= nil or failure ~= nil
  end),
  "worker did not respond"
)
assert(not failure, failure)
assert(frame.background == "light" and frame.highlights.PreviewOnly.fg == 0x123abc)
assert(not vim.g.preview_after_called, "worker executed configuration in host")
assert(palettes == 1, "isolated preview notified host subscribers")
assert(vim.deep_equal(original, colors.snapshot()), "isolated preview changed host colors")
local calls, latest = 0
viewer:show({
  name = "slow",
  colorscheme = "morning",
  background = "light",
  before = function()
    vim.wait(200)
  end,
}, function(result, err)
  if result or err then
    calls = calls + 1
  end
end)
vim.wait(30)
viewer:show({ name = "last", colorscheme = "desert", background = "dark" }, function(result, err)
  assert(not err, err)
  latest = result
end)
assert(vim.wait(5000, function()
  return latest ~= nil
end))
assert(latest.background == "dark" and calls == 0, "stale worker result was painted")
local job = viewer.job
viewer:close()
assert(vim.fn.jobwait({ job }, 2000)[1] ~= -1, "preview process leaked")
assert(vim.deep_equal(original, colors.snapshot()), "worker changed global editor state")
local encode = require("theme_tools.serialize").encode
local cyclic = {}
cyclic.self = cyclic
local restored = assert(loadstring(encode(cyclic)))()
assert(restored.self == restored)
assert(not pcall(encode, print), "C closures must fail explicitly")
print("preview worker: configuration closures, isolation, stale results, coalescing and process cleanup passed")
