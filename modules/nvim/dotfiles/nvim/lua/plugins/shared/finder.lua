return {
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = true,
    keys = {
      { "<leader>ff", function() require("fzf-lua").files() end, desc = "Find files" },
      { "<leader>fg", function() require("fzf-lua").live_grep() end, desc = "Find text" },
      { "<leader>fj", function() require("fzf-lua").jumps() end, desc = "Find jumps" },
      { "grr", function() require("fzf-lua").lsp_references() end, desc = "LSP References" },
    },
    opts = {
      winopts = {
        preview = {
          default = "builtin",
        },
        files = {
          hidden = true,
          cmd = "fd --type f --hidden --exclude .git",
        },
        grep = {
          hidden = true,
          rg_opts = "--hidden --column --line-number --no-heading --color=always --smart-case --g '! .git'",
        },
        lsp = {
          async_or_timeout = 5000,
          includeDeclaration = false,
          symbols = { symbol_style = 1 },
        },
      },
    },
  },
}
