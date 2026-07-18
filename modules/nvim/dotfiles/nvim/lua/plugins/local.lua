local function lsp_on_attach(_, bufnr)
  local options = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, vim.tbl_extend("force", options, { desc = "Go to definition" }))
  vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, vim.tbl_extend("force", options, { desc = "Find references" }))
  vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", options, { desc = "Code action" }))
end

return {
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
  },
  { "mason-org/mason.nvim", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    opts = { ensure_installed = { "basedpyright", "gopls", "rust_analyzer" } },
  },
  {
    "saghen/blink.cmp",
    version = "*",
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      for _, server in ipairs({ "basedpyright", "gopls", "rust_analyzer" }) do
        vim.lsp.config(server, { capabilities = capabilities, on_attach = lsp_on_attach })
        vim.lsp.enable(server)
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        go = { "gofmt" },
        rust = { "rustfmt" },
      },
      default_format_opts = { lsp_format = "fallback" },
    },
  },
}
