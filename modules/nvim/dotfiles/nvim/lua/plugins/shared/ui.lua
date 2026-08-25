return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("catppuccin").setup({
        flavour = "frappe",
        transparent_background = true,
        auto_integrations = true,
        fzf = true,
        neotree = true,

        float = { transparent = true },
        dim_inactive = { enabled = false },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    config = function()
      require("lualine").setup()
    end,
  },
  {
    "folke/which-key.nvim",
    lazy = true,
    event = "VeryLazy",
    opts = {
      spec = {
        { "<leader>f", group = "Find" },
        { "<leader>l", group = "Language" },
        { "<leader>g", group = "Git" },
        { "<leader>c", group = "Code" },
        -- Labelled here rather than from plugins/dev/dap.lua, exactly as "Language" is while
        -- the LSP specs it labels live under plugins/dev/. The cost is the same one: the
        -- label exists under the remote profile too, where no dap plugin is ever resolved.
        { "<leader>d", group = "Debug" },
      },
    },
  },
  {
    "romgrk/barbar.nvim",
    dependencies = {
      "lewis6991/gitsigns.nvim", -- git status in the tabline
      "nvim-tree/nvim-web-devicons",
    },
    -- keys plus an explicit lazy = false: the placeholder mappings are replaced by the
    -- real ones inside the same lazy.setup call, so the tabline is painted at startup.
    lazy = false,
    keys = {
      { "<A-,>", "<Cmd>BufferPrevious<CR>", desc = "Prev Tab" },
      { "<A-.>", "<Cmd>BufferNext<CR>", desc = "Next Tab" },
      -- Not `:BufferClose` directly: on the last tab barbar's close path runs `:enew` so the
      -- window survives and then labels that unnamed listed buffer `[buffer N]`, a tab that
      -- cannot be closed away. core.tabs fills the window with the landing view first and
      -- delegates every other case straight back to `:BufferClose`.
      { "<A-c>", function() require("core.tabs").close_current() end, desc = "Close Tab" },
    },
    init = function()
      vim.g.barbar_auto_setup = false
    end,
    opts = {},
  },
}
