-- Read at spec-evaluation time, so init.lua must set the global before lazy.setup runs.
local is_dev = vim.g.dotfiles_nvim_profile == "dev"

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
    lazy = true,
    keys = {
      { "<leader>e", function() require("neo-tree.command").execute({}) end, desc = "Open file tree" },
      { "<leader>E", function() require("neo-tree.command").execute({ action = "close" }) end, desc = "Close file tree" },
    },
    opts = {
      close_if_last_window = true,
      enable_git_status = is_dev,
      enable_diagnostics = false,
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_ignored = false,
        },
      },
      window = { position = "left", width = 34 },
    },
  },
}
