local lang = require("lang")

-- The filetypes the registry declares debug configurations for, which is deliberately not
-- lang.filetypes(): a language may declare a server and no debugger, and a <leader>d key in
-- its buffers would lead nowhere. Bound to a local because every accessor call re-requires
-- every lua/lang/*.lua, and the ten bindings below want the same answer.
local debug_filetypes = lang.debug_filetypes()

-- One view object for the whole session, shared by the toggle key and by the listeners
-- below: a second call to widgets.sidebar() would build a second window that neither knows
-- about the first nor closes with it. Built on first use rather than in `config`, so a
-- session that is never started never opens a window.
local scopes
local function scopes_sidebar()
  if not scopes then
    local widgets = require("dap.ui.widgets")
    -- widgets.scopes is the local-variable view; the sidebar builder gives it its own
    -- refresh listener on `event_stopped`, so stepping updates it without any help here.
    scopes = widgets.sidebar(widgets.scopes)
  end
  return scopes
end

return {
  {
    "mfussenegger/nvim-dap",
    lazy = true,
    -- Every ]-prefixed pair the debugger would want is already taken buffer-locally: the
    -- runtime ftplugins for go, python and rust map ]] and [[ themselves, and Neovim 0.11's
    -- defaults claim ]b ]q ]a ]t ]d. A global map loses to a buffer-local one, and these are
    -- precisely the filetypes the debugger exists for, so everything stays under <leader>d.
    --
    -- Every binding carries `ft`, which lazy's keys handler honours by setting the mapping
    -- buffer-locally on FileType. The alternative was to leave them global and have the
    -- callbacks report "no debug configuration for <filetype>", and it was rejected because a
    -- global trigger buys nothing else: in a go, python or rust buffer mason-nvim-dap has
    -- already pulled nvim-dap in through its `dependencies`, so the only load a global
    -- <leader>d can still cause is the one whose whole purpose is to announce that it has
    -- nothing to offer. The price is that the "Debug" group which plugins/shared/ui.lua
    -- registers is empty in a markdown or fish buffer, which is what "Language" already is
    -- wherever no LSP attaches.
    keys = {
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle breakpoint", ft = debug_filetypes },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Conditional breakpoint", ft = debug_filetypes },
      { "<leader>dc", function() require("dap").continue() end, desc = "Start or continue", ft = debug_filetypes },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into", ft = debug_filetypes },
      { "<leader>do", function() require("dap").step_over() end, desc = "Step over", ft = debug_filetypes },
      { "<leader>dO", function() require("dap").step_out() end, desc = "Step out", ft = debug_filetypes },
      { "<leader>dv", function() scopes_sidebar().toggle() end, desc = "Toggle variables", ft = debug_filetypes },
      { "<leader>dh", function() require("dap.ui.widgets").hover() end, desc = "Inspect value", mode = { "n", "v" }, ft = debug_filetypes },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Toggle REPL", ft = debug_filetypes },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate session", ft = debug_filetypes },
    },
    config = function()
      local dap = require("dap")

      for _, adapter in ipairs(lang.debug_adapters()) do
        local definition = {}
        for key, value in pairs(adapter) do
          -- `name` is the registry's key for the adapter, the way `server.name` is in
          -- lang/<name>.lua, and not a field nvim-dap reads. Same split as lsp.lua's
          -- vim.lsp.config(server.name, ...).
          if key ~= "name" then
            definition[key] = value
          end
        end
        dap.adapters[adapter.name] = definition
      end

      -- Assigned, not extended: the registry is the only thing that declares configurations,
      -- so a filetype's list here is exactly what its lang/<name>.lua says it is.
      for filetype, configurations in pairs(lang.debug_configurations_by_ft()) do
        dap.configurations[filetype] = configurations
      end

      -- Stopping at a breakpoint without seeing the locals is half a debugger, and the one
      -- keypress that would show them is the one nobody remembers under a stopped program.
      dap.listeners.after.event_stopped["dotfiles"] = function()
        scopes_sidebar().open()
      end
      -- And closes when the last session goes, rather than on `event_terminated`: measured
      -- against delve, a client-side dap.terminate() produces `disconnect` and no terminated
      -- or exited event at all, so an event listener leaves a dead session's locals on screen
      -- for the rest of the editing day. on_session is called with a nil successor exactly
      -- once nothing is being debugged any more, whichever way the session ended.
      dap.listeners.on_session["dotfiles"] = function(_, new)
        if not new then
          scopes_sidebar().close()
        end
      end
    end,
  },
  {
    "jay-babu/mason-nvim-dap.nvim",
    -- mason.nvim is `cmd = "Mason"` and nothing else, so naming it here is the only thing
    -- that gets it loaded on the first Go, Python or Rust file rather than only when someone
    -- types :Mason. nvim-dap is named for the same reason its own trigger cannot cover:
    -- mason-nvim-dap's setup requires dap.ext.vscode itself, and leaving that to lazy's
    -- require hook would make this spec's load order an accident rather than a statement.
    dependencies = { "mason-org/mason.nvim", "mfussenegger/nvim-dap" },
    lazy = true,
    -- Same trigger as mason-lspconfig, for the same reason: a fresh machine installs its
    -- adapters on the first file of a registered language, not on the first Neovim.
    ft = lang.filetypes(),
    -- This plugin is here to install binaries and for nothing else. Its `handlers` key is
    -- what makes it register adapters and configurations of its own shape, and omitting the
    -- key entirely is not the same as passing an empty table: setup only calls
    -- setup_handlers() when the setting is non-nil, so leaving it out is what keeps the
    -- registry the single source of truth for what an adapter is.
    opts = { ensure_installed = lang.debug_adapter_names() },
  },
}
