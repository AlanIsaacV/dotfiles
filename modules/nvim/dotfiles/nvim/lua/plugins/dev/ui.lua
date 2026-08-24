return {
  {
    "folke/snacks.nvim",
    -- Every module enabled below has to be in place before the thing it acts on happens:
    -- the notifier has to own `vim.notify` before init.lua's startup warnings fire, and
    -- `quickfile` and `bigfile` only do anything if they run before the file named on the
    -- command line is read. Any event trigger would leave three of the five inert.
    lazy = false,
    priority = 1000,
    -- snacks turns a module on by the mere presence of its key here, so this table is also
    -- the module list: adding a key -- even an empty one -- enables that module.
    opts = {
      -- The defaults already put it in the top-right corner (`top_down = true`,
      -- `margin.right = 1`), so there is nothing positional worth restating.
      notifier = {},
      input = {},
      bigfile = {},
      words = {},
      quickfile = {},
    },
    -- Comment out this whole `keys` table to drop the jump maps; the highlighting of the
    -- other occurrences comes from `words` in `opts` above and stays either way.
    keys = {
      { "]r", function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference" },
      { "[r", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference" },
    },
  },
  {
    "rachartier/tiny-cmdline.nvim",
    -- It repositions the window Neovim's own cmdline UI creates, so it has to be present
    -- before the first `:`; there is no trigger for that which is not already too late.
    lazy = false,
    -- Neovim's `ui2` is what actually draws the cmdline as a window -- tiny-cmdline only
    -- moves it -- so ui2 has to be enabled before tiny-cmdline's setup runs. `init` runs
    -- ahead of the plugin's load and `config` would not. This lives in the spec rather
    -- than in core/options.lua because plugins/init.lua gates this whole directory on the
    -- dev profile: enabling ui2 from the shared options file would turn it on under the
    -- remote profile too.
    init = function()
      -- `vim._core` is private and Neovim promises nothing about it, so a release that
      -- moves or renames it must not take the rest of this spec down with it.
      pcall(function()
        require("vim._core.ui2").enable()
      end)
    end,
    -- Empty on purpose: a centred float for `:`, `/` and `?` left at the bottom of the
    -- screen, and a border inherited from `winborder`, are all upstream defaults.
    -- `opts` rather than `vim.g.tiny_cmdline` because the plugin's own UIEnter autocmd
    -- only comes into existence once lazy has sourced the plugin, which makes lazy's setup
    -- call the one of the two that is guaranteed to run.
    opts = {},
  },
}
