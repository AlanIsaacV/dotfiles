local lang = require("lang")

local function on_attach(_, bufnr)
  local options = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, vim.tbl_extend("force", options, { desc = "Go to definition" }))
  vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, vim.tbl_extend("force", options, { desc = "Find references" }))
  vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", options, { desc = "Code action" }))
end

return {
  -- A dependent that names mason.nvim gets it loaded ahead of itself whatever trigger it
  -- carries, so a command is the cheapest trigger that still leaves that door open.
  { "mason-org/mason.nvim", lazy = true, cmd = "Mason", opts = {} },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim", "neovim/nvim-lspconfig" },
    lazy = true,
    -- ensure_installed consequently runs on the first open of a filetype that declares a
    -- server instead of at startup: a fresh machine installs its servers on the first Go,
    -- Python or Rust file, not on the first Neovim.
    ft = lang.server_filetypes(),
    opts = { ensure_installed = lang.server_names() },
  },
  {
    "saghen/blink.cmp",
    version = "*",
    lazy = true,
    -- Not `ft`: a markdown, YAML or JSON buffer has no language server and would then have
    -- no completion of any kind.
    event = "InsertEnter",
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    -- The capabilities call below reaches into blink.cmp, which InsertEnter would not have
    -- loaded yet on the first file opened. lazy loads a dependency ahead of its dependent
    -- regardless of the dependency's own trigger, and that is the whole of what keeps the
    -- wiring alive: without this link completion silently stops offering LSP items.
    dependencies = { "saghen/blink.cmp" },
    lazy = true,
    -- Only the filetypes that declare a server: a JSON buffer has nothing here to attach and
    -- loading this pair for it costs a startup's worth of work for no client.
    ft = lang.server_filetypes(),
    config = function()
      vim.diagnostic.config({
        signs = true,
        -- The full message, wrapped, under the line the cursor is on. Inline virtual_text
        -- truncates what basedpyright and rust_analyzer produce, and scoping the lines to
        -- the cursor is what keeps a file full of diagnostics readable.
        virtual_text = false,
        virtual_lines = { current_line = true },
      })

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      for _, server in ipairs(lang.servers()) do
        local config = { capabilities = capabilities, on_attach = on_attach }
        -- Only languages that declare settings get the key at all: passing an empty
        -- table is not the same as passing nothing to vim.lsp.config.
        if server.settings then
          config.settings = server.settings
        end
        vim.lsp.config(server.name, config)
        vim.lsp.enable(server.name)
      end
    end,
  },
}
