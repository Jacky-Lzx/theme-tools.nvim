return {
  {
    dir = vim.fn.expand("~/Documents/Github/nvim_plugins/theme-tools.nvim"),
    name = "theme-tools.nvim",
    main = "theme_tools",
    lazy = false,
    priority = 1000,
    dependencies = {
      {
        dir = vim.fn.expand("~/Documents/Github/nvim_plugins/selection-tools.nvim"),
        name = "selection-tools.nvim",
      },
    },
    opts = {
      catppuccin = { transparent_background = true },
      dracula = { transparent_bg = true },
      default = "theme-tools-mocha",
      picker = { backend = "selection_tools" },
      themes = {
        "theme-tools-mocha",
        "dracula",
        "catppuccin-latte",
        "catppuccin-frappe",
        "catppuccin-macchiato",
        "catppuccin-mocha",
        "habamax",
      },
    },
    keys = {
      { "<leader>ut", "<cmd>ThemeTools<cr>", desc = "Preview themes" },
    },
  },
}
