return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    lazy = true,
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Review Git changes" },
    },
    opts = {},
  },
  {
    "NeogitOrg/neogit",
    lazy = true,
    dependencies = {
      "sindrets/diffview.nvim",
      "ibhagwan/fzf-lua",
    },
    cmd = "Neogit",
    keys = {
      { "<leader>gg", "<cmd>Neogit<cr>", desc = "Show Neogit UI" },
    },
  },
}
