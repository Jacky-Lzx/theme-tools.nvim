return {
  {
    dir = vim.fn.expand("~/Documents/Github/nvim_plugins/theme-tools.nvim"),
    name = "theme-tools.nvim",
    main = "theme_tools",
    lazy = false,
    priority = 1000,
    dependencies = {
      { "catppuccin/nvim", name = "catppuccin", opts = {} },
      {
        dir = vim.fn.expand("~/Documents/Github/nvim_plugins/selection-tools.nvim"),
        name = "selection-tools.nvim",
      },
      -- Add more colorscheme plugins here.
    },
    opts = {
      default = "catppuccin-mocha",
      picker = { backend = "selection_tools" },
      themes = {
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
