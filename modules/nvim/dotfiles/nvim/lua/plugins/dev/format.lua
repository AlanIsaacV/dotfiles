return {
  {
    "stevearc/conform.nvim",
    lazy = true,
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "Format buffer",
      },
    },
    opts = {
      formatters_by_ft = require("lang").formatters_by_ft(),
      default_format_opts = { lsp_format = "fallback" },
    },
  },
}
