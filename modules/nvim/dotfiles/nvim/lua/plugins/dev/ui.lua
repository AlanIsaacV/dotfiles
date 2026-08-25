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
      -- Also the landing view core.tabs falls back on: it is the one buffer barbar draws no
      -- tab for (`buftype = "nofile"`, `buflisted = false`, `filetype = "snacks_dashboard"`),
      -- which is what keeps the tabline empty on `nvim .` and after closing the last tab.
      dashboard = {
        preset = {
          -- The three things there is anything to do from an empty editor, bound to the
          -- letters their leader mappings already use. Every one of them requires its
          -- module rather than running a command, because none of these plugins is loaded
          -- when this view is on screen: `:Neotree` does not exist until neo-tree loads
          -- (measured -- `nvim <file>` then `<A-c>` onto the dashboard leaves
          -- `exists(':Neotree') == 0` and the command raises E492), and going through
          -- `Snacks.dashboard.pick` would send it looking for a picker when this config has
          -- exactly one and it is not snacks'.
          keys = {
            { icon = " ", key = "f", desc = "Find files", action = function() require("fzf-lua").files() end },
            { icon = " ", key = "g", desc = "Find text", action = function() require("fzf-lua").live_grep() end },
            { icon = " ", key = "e", desc = "File tree", action = function() require("neo-tree.command").execute({}) end },
          },
        },
        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          -- `cwd = true` filters `v:oldfiles` down to this project, so the list is what was
          -- open here last time rather than the last thing edited anywhere on the machine.
          { icon = " ", title = "Recent files", section = "recent_files", cwd = true, limit = 8, indent = 2, padding = 1 },
        },
        -- Upstream's default sections also carry `startup`, the plugin count and load time.
        -- Left out on purpose, along with a git status section: neither is a thing to act on
        -- from here, and this view exists to get to a file.
      },
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
      -- Before the `require` below, not merely before `enable()`: ui2 captures
      -- `vim.o.cmdheight` into a module field the moment it is first required, and from
      -- then on refreshes it only from an `OptionSet` autocmd. tiny-cmdline drops
      -- `cmdheight` to 0 on its own with `noautocmd`, which is precisely what suppresses
      -- that event, so ui2 would keep believing the configured height is 1 -- and a
      -- cached 1 is what leaves its cmdline float unhidden on a screen with no cmdline
      -- row left. That float is `relative = "laststatus"` at `row = 1`, so it lands on
      -- lualine's row and `showmode` gets written into it: the statusline disappears
      -- behind `-- INSERT --` from the first `:` onwards. Starting at 0 means the cached
      -- value is right from the outset and tiny-cmdline's own lowering is a no-op.
      vim.o.cmdheight = 0
      -- `vim._core` is private and Neovim promises nothing about it, so a release that
      -- moves or renames it must not take the rest of this spec down with it.
      pcall(function()
        -- The second thing `cmdheight = 0` costs, after `showmode`: every ordinary message is
        -- drawn in ui2's `cmd` window, which is opened `relative = "laststatus"` at `row = 1` --
        -- lualine's row. So `:w` blanked the statusline for a few seconds behind
        -- `"file" 163L, 7898B written`. ui2 already owns a second window for exactly this case,
        -- `msg`: anchored bottom-right, gone on its own after 4 s, nothing else moved.
        --
        -- `progress` is the key that reaches a write, and it is not obvious: a write used to
        -- carry its own `bufwrite` kind and no longer does (`:help news`, "msg_show.bufwrite ...
        -- are now msg_show.progress events"). Measured on 0.12.5 through a `vim.ui_attach`
        -- listener, `:write` emits `kind = "progress"` with an empty `trigger`, and ui2 resolves
        -- a destination as targets[trigger] or targets[kind] or target -- so the kind is the only
        -- handle there is. The cost is that the language server's own progress reports share that
        -- kind and follow the write into the same corner; `trigger` is empty for both, so there
        -- is no way to route one without the other.
        require("vim._core.ui2").enable({ msg = { targets = { progress = "msg" } } })
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
