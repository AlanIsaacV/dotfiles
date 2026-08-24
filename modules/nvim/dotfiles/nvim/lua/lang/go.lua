return {
  server = { name = "gopls" },
  formatters = { "gofmt" },
  debug = {
    adapter = {
      -- mason-nvim-dap's own vocabulary for the adapter, which is a third naming system
      -- beside this file's name (the filetype `go`) and the server name: `ensure_installed`
      -- is derived from it and a name outside that vocabulary silently installs nothing.
      -- Its mason package happens to be called `delve` too; debugpy's is not.
      name = "delve",
      -- dlv speaks DAP over a socket rather than over stdio, so nvim-dap has to be told to
      -- spawn it and then connect; it substitutes the same free port into both sides.
      type = "server",
      port = "${port}",
      -- Unqualified on purpose, so PATH decides at spawn time. mason.nvim prepends its own
      -- bin, which is what makes mason's delve win over the older ~/go/bin/dlv, and an
      -- absolute path here would instead hard-code mason's install root into the registry.
      executable = { command = "dlv", args = { "dap", "-l", "127.0.0.1:${port}" } },
    },
    configurations = {
      -- `type` is the adapter name above, not the filetype: it is how nvim-dap finds the
      -- adapter to start for a configuration.
      --
      -- The package rather than the file comes first because a Go main package is routinely
      -- split across several files, and dlv given a single file of such a package fails to
      -- build it.
      { name = "Debug package", type = "delve", request = "launch", program = "${fileDirname}" },
      { name = "Debug file", type = "delve", request = "launch", program = "${file}" },
    },
  },
}
