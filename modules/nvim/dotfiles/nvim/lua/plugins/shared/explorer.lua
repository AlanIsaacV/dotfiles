-- Read at spec-evaluation time, so init.lua must set the global before lazy.setup runs.
local is_dev = vim.g.dotfiles_nvim_profile == "dev"

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
    lazy = true,
    keys = {
      { "<leader>e", function() require("neo-tree.command").execute({}) end, desc = "Open file tree" },
      { "<leader>E", function() require("neo-tree.command").execute({ action = "close" }) end, desc = "Close file tree" },
    },
    -- `keys` alone cannot make `nvim <dir>` land here: everything that takes a directory
    -- over lives inside neo-tree's `setup()`, and at the moment nvim opens the directory
    -- this plugin does not exist yet. `init` is the last hook that is still early enough --
    -- lazy runs it from `lazy.setup`, and measured on 0.12.4 the buffer for the command-line
    -- argument is already the current buffer by then with `v:vim_did_enter` still 0, which
    -- is exactly the condition neo-tree's `setup()` checks before hijacking `argv(0)`
    -- itself. Requiring the module is what asks lazy to load the plugin; nothing here calls
    -- `setup` directly.
    init = function()
      -- neo-tree's `setup()` does run `autocmd! FileExplorer *`, and on 0.12 that is too
      -- early to matter: netrw ships as a package now, `packadd`ed from
      -- `$VIMRUNTIME/plugin/netrwPlugin.vim`, which nvim sources after init.lua and which
      -- therefore re-registers the autocmds neo-tree just deleted. Measured against the real
      -- config, that lost race is visible: netrw creates and draws a buffer for the directory
      -- and only then the tree replaces it. The one guard netrwPlugin.vim honours is this
      -- variable, and setting it from here stands netrw down only on a startup that has
      -- neo-tree to replace it -- the degraded no-plugin path never evaluates this spec, so
      -- there netrw remains the directory viewer of last resort. The cost is netrw's other
      -- jobs: `:Explore` and editing over `scp://` go with it. `gx` does not; Neovim has
      -- handled that itself since 0.10.
      vim.g.loaded_netrwPlugin = 1

      if vim.fn.argc(-1) == 1 and vim.fn.isdirectory(vim.fn.argv(0) --[[@as string]]) == 1 then
        require("neo-tree")
        return
      end

      -- With netrw stood down, a `:edit <dir>` typed later in the session has nothing left
      -- to draw it: no plugin is loaded and the directory comes up as an empty buffer. So
      -- one watcher stands in until neo-tree exists, and deletes itself once it has fired --
      -- from then on neo-tree's own BufEnter watcher (`plugin/neo-tree.lua`) owns the case.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("dotfiles_neo_tree_netrw", { clear = true }),
        desc = "Load neo-tree the first time a directory is opened",
        callback = function(args)
          if vim.fn.isdirectory(args.file) ~= 1 then
            return false
          end
          require("neo-tree")
          -- neo-tree only hijacks `argv(0)` from `setup()`, and the BufEnter it registers
          -- for every other case was created inside this very callback, too late for the
          -- event being handled. Its debounce makes a second hijack of the same window a
          -- no-op, so calling it here is safe even if that watcher does fire.
          require("neo-tree.setup.netrw").hijack()
          return true
        end,
      })
    end,
    opts = {
      close_if_last_window = true,
      enable_git_status = is_dev,
      enable_diagnostics = false,
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_ignored = false,
        },
        -- Upstream's default, restated because the whole `init` above exists to make it take
        -- effect and because netrw is no longer standing behind it: a release that changed
        -- this default to "disabled" would leave directories drawn by nobody at all.
        hijack_netrw_behavior = "open_default",
      },
      window = { position = "left", width = 34 },
    },
  },
}
