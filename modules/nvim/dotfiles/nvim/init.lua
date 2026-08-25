require("core.options")

local profile = require("core.profile").current()
vim.g.dotfiles_nvim_profile = profile

require("core.keymaps").setup()

-- The tree and finder bindings are lazy `keys` entries, so they do not exist at all on
-- the paths below that never reach lazy.setup. Mapping them to a warning is what makes
-- the module's documented "plugin ausente" diagnostic observable on a bare install.
local function map_absent_plugin_warnings()
  local fallbacks = {
    { "<leader>e", "Open file tree" },
    { "<leader>E", "Close file tree" },
    { "<leader>ff", "Find files" },
    { "<leader>fg", "Find text" },
    { "<leader>fj", "Find jumps" },
  }
  for _, fallback in ipairs(fallbacks) do
    vim.keymap.set("n", fallback[1], function()
      vim.notify("This Neovim feature is not installed yet", vim.log.levels.WARN)
    end, { silent = true, desc = fallback[2] })
  end
end

-- Everything a clone downloads lands in `.git/objects/pack`: git stamps that directory
-- when it creates it and again when it renames a finished pack in, and in between the
-- `tmp_pack_*` file being written carries the transfer. The composite is the cheapest
-- signal that was measured to actually track a slow download. Sampled every 100 ms
-- against the real repository over a throttled 20 KB/s link, a 110 s clone left it stale
-- for at most 3.4 s, while `.git`'s own mtime sat unchanged for 93 s of it and
-- `.git/objects` for the entire clone: a directory's mtime only moves when entries are
-- created or removed directly inside it, so the obvious signals read "idle" during
-- exactly the slow download this has to recognise. nil means no clone here ever got as
-- far as creating an object store.
local function download_idle_seconds(staged)
  local pack = staged .. "/.git/objects/pack"
  local stat = vim.uv.fs_stat(pack)
  if not stat then
    return nil
  end
  local newest = stat.mtime.sec
  local scan = vim.uv.fs_scandir(pack)
  while scan do
    local name = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end
    local entry = vim.uv.fs_stat(pack .. "/" .. name)
    if entry and entry.mtime.sec > newest then
      newest = entry.mtime.sec
    end
  end
  return os.time() - newest
end

-- Nothing renames a staging directory whose Neovim exited before the clone callback
-- could run, and the git it spawned is orphaned rather than killed: it keeps downloading
-- and often finishes writing a perfectly good lazy.nvim that no callback is left alive to
-- move. So a startup takes over that job, adopting a finished download instead of
-- throwing it away and paying for it again. Directories named after a process that is
-- still alive are left alone: that is a second session cloning right now, into a path of
-- its own.
local function reclaim_abandoned_clones(dir, prefix, destination)
  local scan = vim.uv.fs_scandir(dir)
  if not scan then
    return
  end
  while true do
    local name = vim.uv.fs_scandir_next(scan)
    if not name then
      break
    end
    local pid = name:match("^" .. vim.pesc(prefix) .. "(%d+)$")
    -- Signal 0 checks for the process without touching it; luv answers 0 when it exists
    -- and nil when it does not.
    if pid and not vim.uv.kill(tonumber(pid), 0) then
      local staged = dir .. "/" .. name
      -- An interrupted clone leaves `.git` and nothing else, so the discriminator has to
      -- be a file from the checkout itself; `lua/lazy/init.lua` is the one
      -- `require("lazy")` will look for. That file alone is not quite enough: measured
      -- against the real repository, the checkout writes it 3 ms before the rest of
      -- `lua/lazy/`, and adopting inside that window would install a lazy.nvim that
      -- loads and then dies requiring a module that never arrived. git renames
      -- `.git/index` into place last of all, 8 ms later, so requiring both closes the
      -- window. Size, entry count and mtime answer a different question entirely.
      local complete = vim.uv.fs_stat(staged .. "/lua/lazy/init.lua")
        and vim.uv.fs_stat(staged .. "/.git/index")
      local adopted = false
      if complete and not vim.uv.fs_stat(destination) then
        adopted = vim.uv.fs_rename(staged, destination) ~= nil
      end
      if not adopted then
        -- A dead owner pid does not mean the download died with it: Neovim orphans the git
        -- it spawned rather than waiting for it, so a clone keeps writing into a staging
        -- directory whose Neovim is long gone. Deleting one that is still moving throws
        -- away work that was about to become an install and sends the next startup back to
        -- zero, which on a slow link can loop without ever finishing. So an incomplete
        -- staging directory is swept only once it has stopped downloading too; one that is
        -- still live is left for the startup that finds it complete. The ceiling is the
        -- clone's own timeout, an order of magnitude above the worst stall measured. The
        -- cost is that this startup clones alongside it -- lazypath is still absent -- and
        -- whichever download lands first is the one that gets adopted.
        local idle = download_idle_seconds(staged)
        if not idle or idle > 30 then
          vim.fn.delete(staged, "rf")
        end
      end
    end
  end
end

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazyroot = vim.fs.dirname(lazypath)
local clone_prefix = "lazy.nvim.cloning."

-- Ahead of the presence check rather than inside it, so an adopted clone is what this
-- startup loads; run after it, the rename would land and then be ignored while a second
-- download of the same thing started. Running it on every startup also reaches the
-- staging directories a session can orphan once lazy.nvim is already installed.
reclaim_abandoned_clones(lazyroot, clone_prefix, lazypath)

if not vim.uv.fs_stat(lazypath) then
  if vim.fn.executable("git") ~= 1 then
    vim.notify("Neovim plugins are unavailable; using the built-in editor", vim.log.levels.WARN)
    map_absent_plugin_warnings()
    return
  end

  -- The clone stages into a per-process directory and is moved onto `lazypath` only
  -- once git reports success, so the presence check above can never see a half-clone.
  -- Nothing waits for this, which makes quitting a few seconds into a first boot an
  -- ordinary thing to do rather than a way to poison the install.
  local clonepath = lazyroot .. "/" .. clone_prefix .. vim.uv.os_getpid()

  -- This clone is also the reachability test, so it has to be bounded: an unreachable
  -- network makes it hang rather than refuse, and git 2.50 offers no connect timeout of
  -- its own. The output is deliberately not captured: a pipe that git's
  -- `git-remote-https` child holds open past the kill costs 2 x timeout and then yields
  -- nil instead of code 124.
  vim.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", clonepath,
  }, { timeout = 30000, stdout = false, stderr = false }, function(clone)
    -- 124 is what vim.system reports for an expired timeout, never something git returns.
    -- A nil result means the same thing, and indexing it would crash the callback.
    local timed_out = clone == nil or clone.code == 124
    -- on_exit arrives in a fast event context, where vim.fn.*, vim.notify and vim.cmd all
    -- raise E5560. Everything below is the failure path that a working network never
    -- exercises, so an unscheduled call here would pass on every machine except the ones
    -- this code exists for.
    vim.schedule(function()
      if timed_out or clone.code ~= 0 then
        vim.fn.delete(clonepath, "rf")
        if timed_out then
          vim.notify("Downloading Neovim plugins timed out; using the built-in editor. Restart Neovim on a working network to retry", vim.log.levels.WARN)
        else
          vim.notify("Neovim plugins could not be downloaded; using the built-in editor. Restart Neovim with a network to retry", vim.log.levels.WARN)
        end
        return
      end

      -- A session started alongside this one can have installed lazy.nvim while this clone
      -- ran, and fs_rename onto a populated destination fails with ENOTEMPTY. The plugins
      -- are there either way, so that is this path succeeding and not failing; the startup
      -- sweep guards its own rename against the same race.
      if vim.uv.fs_stat(lazypath) then
        vim.fn.delete(clonepath, "rf")
      elseif not vim.uv.fs_rename(clonepath, lazypath) then
        vim.fn.delete(clonepath, "rf")
        vim.notify("Neovim plugins could not be installed; using the built-in editor. Restart Neovim with a network to retry", vim.log.levels.WARN)
        return
      end

      vim.notify("Neovim plugins finished downloading; restart Neovim to load them", vim.log.levels.INFO)
    end)
  end)

  vim.notify("Downloading Neovim plugins in the background; this session stays on the built-in editor", vim.log.levels.INFO)
  map_absent_plugin_warnings()
  return
end

vim.opt.rtp:prepend(lazypath)
require("lazy").setup(require("plugins"), {
  checker = { enabled = false },
  change_detection = { notify = false },
})

-- Deliberately here and not up with core.options and core.keymaps: every path above this
-- line returns without plugins, and preview tabs only make sense where a tabline shows
-- which buffers exist. On the built-in editor the same autocmds would silently `:bdelete`
-- the file just read with nothing on screen to say so, which is a worse plain editor than
-- vim's own buffer list. The landing view and the `<A-c>` wrapper need barbar, neo-tree and
-- snacks for the same reason. After lazy.setup rather than before, so the profile's plugins
-- are resolved before the module reads them; the startup work it registers is an autocmd
-- that fires later either way.
require("core.tabs")

