-- Two interpreters are in play in a Python debug session and they are not the same one: the
-- adapter runs out of the venv mason built for debugpy, while the debuggee has to run out of
-- the venv the project's own imports resolve against. debugpy names the second one in the
-- launch request under the key `python`; `pythonPath` is a deprecated legacy spelling and
-- passing both is rejected outright, per debugpy's own request handling in
-- src/debugpy/adapter/clients.py ("pythonPath is not valid if python is specified"). Leaving
-- it out falls back to the adapter's sys.executable -- mason's venv -- which is a debuggee
-- that runs and imports nothing the project depends on, so this key is never omitted.
--
-- nvim-dap calls a function it finds in a configuration value while it expands the
-- configuration, so the resolution happens per session rather than at startup, and it is
-- resolved against the current buffer for the same reason `program = "${file}"` is.
local function debuggee_python()
  -- An activated venv is the user saying which interpreter they mean, and it outranks
  -- whatever directory happens to sit above the file.
  if vim.env.VIRTUAL_ENV then
    return vim.env.VIRTUAL_ENV .. "/bin/python"
  end

  local buffer = vim.api.nvim_buf_get_name(0)
  local from = buffer ~= "" and vim.fs.dirname(buffer) or vim.uv.cwd()
  -- Upward from the file, not from the cwd: a repository whose Python lives in a subproject
  -- keeps its venv down there, and Neovim is usually opened at the repository root.
  local found = vim.fs.find({ ".venv", "venv" }, { path = from, upward = true, type = "directory", limit = 1 })
  if found[1] then
    local python = found[1] .. "/bin/python"
    if vim.fn.executable(python) == 1 then
      return python
    end
    -- A venv copied between machines keeps an interpreter symlink into the home directory it
    -- was built under, and a dead one is not a reason to reach for the next interpreter along:
    -- that session would start, run and only fail at the first project import, which reads as
    -- a broken program rather than as a broken venv. Aborting says which of the two it is.
    vim.notify(("dap: %s has no usable interpreter"):format(found[1]), vim.log.levels.ERROR)
    return require("dap").ABORT
  end

  -- No venv anywhere above the file: PATH's python3, which is at least the one a shell in
  -- that directory would have run.
  return "python3"
end

return {
  server = { name = "basedpyright" },
  formatters = { "ruff_format" },
  debug = {
    adapter = {
      -- mason-nvim-dap's adapter name. Its mason package is `debugpy` and the language
      -- server is `basedpyright`: three vocabularies, and only this one drives the install.
      name = "python",
      -- debugpy speaks the DAP over stdio, so unlike dlv and codelldb there is no port and
      -- nvim-dap owns the process. `debugpy-adapter` is the shim mason writes into its bin
      -- directory; left unqualified so PATH resolves it at spawn time.
      type = "executable",
      command = "debugpy-adapter",
    },
    configurations = {
      {
        name = "Debug file",
        -- The adapter name above, which for Python happens to equal the filetype.
        type = "python",
        request = "launch",
        program = "${file}",
        python = debuggee_python,
        -- debugpy's default console is `internalConsole`, which gives the debuggee no stdin
        -- at all and folds its output into the REPL. A program that prompts or serves needs
        -- a real terminal buffer.
        console = "integratedTerminal",
      },
      {
        name = "Debug module",
        type = "python",
        request = "launch",
        -- The shape a packaged entry point actually runs as: `[project.scripts]` points at a
        -- module, and running its file directly is not the same thing to Python's imports.
        module = function()
          return vim.fn.input("Module: ")
        end,
        python = debuggee_python,
        console = "integratedTerminal",
      },
    },
  },
}
