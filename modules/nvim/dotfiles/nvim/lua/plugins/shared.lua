local is_local = vim.g.dotfiles_nvim_profile == "local"

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "frappe",
	transparent_background = true,
	auto_integrations = true,
	fzf = true,
	neotree = true,
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
       require('lualine').setup()
    end,
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "Find" },
        { "<leader>l", group = "Language" },
        { "<leader>g", group = "Git" },
        { "<leader>c", group = "Code" },
      },
    },
  },
  {'romgrk/barbar.nvim',
    dependencies = {
      'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
      'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
    },
    init = function() vim.g.barbar_auto_setup = false end,
    opts = {
      -- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
      -- animation = true,
      -- insert_at_start = true,
      -- …etc.
    },
  },
  { "nvim-lua/plenary.nvim", lazy = true },
  { "MunifTanjim/nui.nvim", lazy = true },
  { "nvim-tree/nvim-web-devicons", lazy = true },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
    opts = {
      close_if_last_window = true,
      enable_git_status = is_local,
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
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = { winopts = { preview = { default = "builtin" } } },
  },
}
