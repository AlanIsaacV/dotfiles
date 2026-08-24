return {
  server = { name = "rust_analyzer" },
  formatters = { "rustfmt" },
  debug = {
    adapter = {
      -- mason-nvim-dap's adapter name, which is also its package name here.
      name = "codelldb",
      -- codelldb's own binary implements the DAP over a socket, like dlv and unlike debugpy.
      type = "server",
      port = "${port}",
      executable = { command = "codelldb", args = { "--port", "${port}" } },
    },
    configurations = {
      {
        name = "Debug binary",
        type = "codelldb",
        request = "launch",
        -- Nothing derives the binary from the current file the way ${fileDirname} does for
        -- Go: cargo writes it under target/debug named after the crate, and a workspace has
        -- one per member. Asked for rather than guessed.
        program = function()
          return vim.fn.input("Path to binary: ", vim.fn.getcwd() .. "/target/debug/", "file")
        end,
        cwd = "${workspaceFolder}",
      },
    },
  },
}
