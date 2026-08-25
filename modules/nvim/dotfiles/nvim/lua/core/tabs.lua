-- Preview tabs and the landing view.
--
-- Two behaviours that share one helper. A file opened only to be read takes over the last
-- such tab instead of adding one, and closing the last tab lands on a view that barbar
-- draws no tab for -- which is the same view the window beside the sidebar gets on
-- `nvim <dir>`, and the reason that startup shows an empty tabline.
--
-- This file is shared, so it runs under the remote profile too, where snacks does not
-- exist: every `Snacks` reference below is behind a profile check and a pcall.

local M = {}

-- Buffers whose `buftype` is not empty are already out (terminal, quickfix, help, nofile,
-- prompt), which covers the scratch buffers most plugins draw their UI in. These are the
-- filetypes named anyway, because a buffer's `buftype` is an implementation detail of the
-- plugin that set it and this list is what the behaviour is meant to be, not what today's
-- versions happen to do.
local NEVER_PREVIEW = {
  -- The sidebar and its floats. Losing the tree because the next file was opened for
  -- reading would take the window this whole feature is navigated from.
  ["neo-tree"] = true,
  ["neo-tree-popup"] = true,

  -- neogit spreads one session over a dozen buffers -- the status view, every popup, every
  -- log and diff pane -- and any of them can be the current buffer when a file is opened
  -- from it. All of them are views of the repository, never a file being read.
  ["NeogitStatus"] = true,
  ["NeogitPopup"] = true,
  ["NeogitConsole"] = true,
  ["NeogitLogView"] = true,
  ["NeogitRefsView"] = true,
  ["NeogitDiffView"] = true,
  ["NeogitStashView"] = true,
  ["NeogitReflogView"] = true,
  ["NeogitCommitView"] = true,
  ["NeogitCommitSelectView"] = true,
  ["NeogitGitCommandHistory"] = true,
  -- The two real files neogit opens in a real window: a commit message and a rebase todo
  -- are being written, not read, and closing one out from under an unfinished commit is
  -- the worst thing this file could do.
  ["gitcommit"] = true,
  ["gitrebase"] = true,

  -- diffview's panels. Its revision buffers are a different problem and are not solved
  -- here: `vcs/file.lua` loads the working-tree side with a plain `:edit` and then relists
  -- it, so it arrives with the file's own filetype and nothing to match on. What keeps it
  -- out is that the `:edit` happens inside `utils.temp_win()`, a floating window, and a
  -- buffer that first appears in a float is marked as already-open below.
  ["DiffviewFiles"] = true,
  ["DiffviewFileHistory"] = true,

  -- fzf-lua's own terminal buffer. Its builtin previewer builds every preview with
  -- `nvim_create_buf(false, true)`, unlisted, so those never reach this code at all.
  ["fzf"] = true,
}

--- The tab in flight: the buffer the next file opened for reading will replace, or nil when
--- there is none. Ordinary opens keep exactly one of these.
local preview = nil

--- Buffers the jump history reopened and that nobody has kept: they show in the tabline, and
--- the next ordinary open reclaims all of them together. A walk is one gesture, so it leaves
--- one tab's worth of mess however long it is -- a single tab in flight cannot express that,
--- because each step would have to close the previous arrival and closing buffers mid-walk is
--- the churn that made the whole exemption necessary.
local provisional = {}

--- Buffers that have been added to the buffer list and not yet shown in a window. A buffer
--- is a preview candidate exactly once, on its first appearance; after that it counts as
--- already open, which is what keeps a file the user came back to from being evictable.
local unseen = {}

--- The one unlisted empty buffer handed out as the landing view under the remote profile.
--- Reused rather than created per close: the alternative is `bufhidden = "wipe"`, and this
--- config does not destroy buffers (see the `:bdelete` note in `reclaim`).
local empty = nil

local function empty_buffer()
  if empty and vim.api.nvim_buf_is_valid(empty) and not vim.bo[empty].modified then
    return empty
  end
  -- Unlisted so barbar draws no tab for it; not a scratch buffer, so it is the ordinary
  -- modifiable buffer a bare `nvim` leaves you on rather than a read-only nofile one.
  empty = vim.api.nvim_create_buf(false, false)
  return empty
end

local function is_float(win)
  return vim.api.nvim_win_get_config(win).relative ~= ""
end

--- Whether the cursor is walking the jump history at this instant.
---
--- Neovim fires no event for a jump, but the jumplist has a shape that says so. Measured on
--- 0.12.4 inside the BufWinEnter of a jump: `<C-o>` and `<C-i>` both arrive with the index
--- sitting inside the list (idx < #list) in either direction, while every ordinary open --
--- `:edit`, a picker, a go-to-definition -- arrives with idx == #list, having pushed the
--- position it came from onto the end. `<A-[>` and `<A-]>` are `<C-o>` and `<C-i>` under
--- another name, so this recognises them without knowing they exist, and the native pair
--- keeps working the same way. `jumpoptions` carrying `stack` is what keeps this from
--- misreading the other case: opening a file from the middle of the history truncates the
--- entries ahead, so idx == #list again by the time the new buffer is displayed.
local function walking_jump_history()
  local list, idx = unpack(vim.fn.getjumplist())
  return idx < #list
end

--- Whether barbar is holding `buf` pinned. Pin state is read here, at the moment the buffer
--- would be closed, rather than tracked from a wrapped `:BufferPin`: barbar fires no event
--- when a pin is toggled, and asking it is both shorter and correct for pins set any other
--- way. pcall because barbar is a plugin and this file also runs when there are none.
local function is_pinned(buf)
  local ok, state = pcall(require, "barbar.state")
  if not ok then
    return false
  end
  local pinned
  ok, pinned = pcall(state.is_pinned, buf)
  return ok and pinned == true
end

--- Close `buf`, unless it earned its place while it was disposable. The caller has already
--- let go of it either way: a buffer that survives this has become permanent.
local function reclaim(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted then
    return
  end
  -- Pinning arrives as no event at all, so this is the only place it can be asked about.
  -- `modified` is asked again rather than trusted to the promotion autocmd below because,
  -- measured on 0.12.4, `nvim_buf_set_lines` fires neither TextChanged nor TextChangedI: a
  -- buffer changed by a code action or a formatter is dirty with nothing having been
  -- announced, and closing it would throw the change away.
  if vim.bo[buf].modified or is_pinned(buf) then
    return
  end
  -- Still on screen somewhere -- a split kept it, so it is not disposable any more.
  if #vim.fn.win_findbuf(buf) > 0 then
    return
  end
  -- `:bdelete`, never `:bwipeout`. Measured on 0.12.4 with `jumpoptions = "stack,view"`: a
  -- `:bdelete` leaves the file's jumplist entries intact, so `<A-[>` walks back into a
  -- closed preview and reopens it at the line it was left on, while a `:bwipeout` destroys
  -- those entries -- even with `clean` out of `jumpoptions` -- and the back navigation
  -- stops working on exactly the files this mechanism closes.
  pcall(vim.cmd.bdelete, { count = buf })
end

--- Give up everything that was only being looked at: the tab in flight and every tab a walk
--- reopened. Measured, in the order it matters: three arrivals reopened by `<A-[>` and then
--- one `:edit` leaves the three gone and the new file in flight, while the buffer the walk
--- started from -- released the moment the first arrival was recorded -- stays. A buffer that
--- has been edited, pinned or left in a second window is refused by `reclaim` and simply
--- becomes permanent; forgetting it here is what makes that stick.
local function reclaim_all()
  local in_flight, walked = preview, provisional
  preview, provisional = nil, {}
  reclaim(in_flight)
  for buf in pairs(walked) do
    reclaim(buf)
  end
end

--- An ordinary open: `:edit`, a pick, `<CR>` in the tree, a go-to-definition.
local function adopt(buf)
  if preview == buf then
    return
  end
  -- Out of the set before the sweep, so nothing can reclaim the file being opened. Belt:
  -- a provisional buffer stays listed, so it never gets the BufAdd that leads here.
  provisional[buf] = nil
  reclaim_all()
  preview = buf
end

--- A file the jump history reopened. It joins the provisional set rather than becoming the
--- one tab in flight, and the tab in flight is released rather than closed: the buffer being
--- walked away from is the one the walk came from, and tearing it down per keypress is the
--- churn this exemption exists to prevent. Only a file the walk actually *reopened* gets
--- here -- walking forward onto a buffer that was never closed fires no BufAdd at all, so it
--- stays permanent, because demoting the file being worked on for having been walked over
--- would be worse than the pile-up this removes.
local function mark_provisional(buf)
  -- Released unconditionally, and this is the line the approved behaviour turns on: the tab
  -- in flight when a walk starts is the file being walked away from, so it has to stop being
  -- disposable here or the ordinary open that ends the walk takes it down with the arrivals.
  -- Measured before this was unconditional: `:edit z` after a three-step walk left only z.
  preview = nil
  provisional[buf] = true
end

---@param buf integer
---@param win integer the window the buffer has just been displayed in
local function is_preview_candidate(buf, win)
  -- A preview is a file. Unnamed buffers are `:enew` scratch, the landing view, and the
  -- placeholder neo-tree's netrw hijack leaves behind -- none of them a thing to replace.
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then
    return false
  end
  -- A directory arrives here as an ordinary named buffer with no buftype yet, on its way to
  -- being hijacked into the tree. Measured: without this, `:edit .` with a file open adopts
  -- the directory as the preview and closes that file -- and then the hijack puts the file
  -- back in the window it just lost its tab in.
  if vim.fn.isdirectory(name) == 1 then
    return false
  end
  if vim.bo[buf].buftype ~= "" or NEVER_PREVIEW[vim.bo[buf].filetype] then
    return false
  end
  -- Floating windows are where plugins load files they are about to read out of and throw
  -- away; nothing a user is reading arrives that way.
  return not is_float(win)
end

--- Put the landing view in `win`: the snacks dashboard under the dev profile, an unlisted
--- empty buffer under remote. Neither is listed, which is the whole point -- barbar draws
--- no tab for either, so closing the last tab and starting on a directory both end with an
--- empty tabline instead of the `[buffer N]` that barbar's own `:enew` fallback produces.
---@param win integer? defaults to the current window
function M.show_landing_view(win)
  win = win or vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  if vim.g.dotfiles_nvim_profile == "dev" then
    -- snacks is imported only under the dev profile, and `Snacks.dashboard` resolves the
    -- module on first use, so this is both the existence check and the call. A snacks that
    -- failed to load must not take the close key down with it, hence the fallback below.
    local ok = pcall(function()
      Snacks.dashboard.open({ win = win })
    end)
    if ok then
      return
    end
  end
  vim.api.nvim_win_set_buf(win, empty_buffer())
end

--- What `<A-c>` runs instead of `:BufferClose`.
function M.close_current()
  local buf = vim.api.nvim_get_current_buf()
  local listed = #vim.fn.getbufinfo({ buflisted = 1 })

  if not vim.bo[buf].buflisted then
    -- The dashboard, the sidebar, a quickfix window: there is no tab under the cursor to
    -- close. barbar would answer this by deleting the buffer anyway and `:enew`-ing a
    -- replacement, which is how a tabline that was empty acquires a `[buffer N]`.
    return
  end

  if is_pinned(buf) then
    -- Ahead of both branches below, including the delegation: barbar's own `:BufferClose`
    -- closes a pinned buffer without comment, and a protection that holds only when the tab
    -- happens to be the last one is one nobody can rely on. Reported the same way the
    -- refusal below is, because a key that does nothing and says nothing is the failure this
    -- file already had once.
    vim.api.nvim_echo({ { "Buffer " .. buf .. " is pinned; :BufferPin to unpin", "ErrorMsg" } }, true, {})
    return
  end

  if listed == 1 and not vim.bo[buf].modified then
    -- The last tab. barbar's close path runs `:enew` when it finds no buffer to fall back
    -- to, so that the window survives, and then labels that unnamed listed buffer
    -- `[buffer N]`; no barbar option removes it. Filling the windows first means there is
    -- something to fall back to and that path is never reached.
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      M.show_landing_view(win)
    end
    if preview == buf then
      preview = nil
    end
    provisional[buf] = nil
    pcall(vim.cmd.bdelete, { count = buf })
    return
  end

  -- Everything else stays barbar's: which tab takes focus next is `state.get_focus_on_close`
  -- and follows the tabline's own order, which a second implementation here would get wrong.
  --
  -- What barbar does not do is make a refusal visible. `:BufferClose` on an unwritten buffer
  -- does not raise: bbye reports E89 through the `vim.notify` it captured when it loaded --
  -- under the dev profile that is snacks' notifier, so the message is a toast and measurably
  -- absent from `:messages` -- sets `v:errmsg`, and returns. Pressing the key on a buffer
  -- that simply needs writing is an everyday thing to do, and it must not look like a dead
  -- key, so the reason is echoed into the message history here. Read on the very next line
  -- because `v:errmsg` does not keep: barbar's own scheduled work overwrites it within
  -- milliseconds.
  vim.v.errmsg = ""
  local before = #vim.fn.getbufinfo({ buflisted = 1 })
  local ok, thrown = pcall(vim.cmd, "BufferClose")
  local reason = ok and vim.v.errmsg or tostring(thrown)
  if reason ~= "" and #vim.fn.getbufinfo({ buflisted = 1 }) == before then
    vim.api.nvim_echo({ { reason, "ErrorMsg" } }, true, {})
  end
end

--- Whether `buf` is a buffer nvim or a plugin created only to have something in a window:
--- unnamed, empty, unmodified and an ordinary buffer. It is the shape of the startup buffer,
--- of what neo-tree's hijack leaves behind, and of what `:bd` on the dashboard produces, and
--- the point of recognising it is that barbar draws a tab for every one of them.
local function is_bare_placeholder(buf)
  return vim.api.nvim_buf_is_valid(buf)
    and vim.api.nvim_buf_get_name(buf) == ""
    and vim.bo[buf].buftype == ""
    and not vim.bo[buf].modified
    and vim.api.nvim_buf_line_count(buf) <= 1
    and (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") == ""
end

--- Replace the buffer left beside the sidebar when neo-tree takes a directory over.
---
--- The netrw hijack does not open the directory in place: it puts a buffer of its own in the
--- window the directory was going to be drawn in and opens the tree in a split beside it.
--- When there is no alternate buffer to put there -- every `nvim <dir>`, and `:edit <dir>`
--- from an empty one -- it creates that buffer with `nvim_create_buf(true, false)`, listed,
--- so the tabline has a nameless tab in it from the first second.
local function replace_placeholder()
  local listed = vim.fn.getbufinfo({ buflisted = 1 })
  -- Exactly one listed buffer, and it is empty and unnamed: that is the placeholder and
  -- nothing else. Any file the user has open would be a second entry, which is what keeps
  -- this off a session where the hijack reused an alternate buffer and left nothing behind.
  if #listed ~= 1 then
    return
  end
  local buf = listed[1].bufnr
  if not is_bare_placeholder(buf) then
    return
  end

  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    M.show_landing_view(win)
  end
  if #vim.fn.win_findbuf(buf) == 0 then
    pcall(vim.cmd.bdelete, { count = buf })
  end
end

local group = vim.api.nvim_create_augroup("dotfiles_tabs", { clear = true })

vim.api.nvim_create_autocmd("BufAdd", {
  group = group,
  desc = "Mark a buffer as a candidate for the preview tab",
  callback = function(args)
    -- BufAdd is the only event that says "this buffer was not in the list a moment ago",
    -- which is the definition of "not already open" this needs. It is far too early to
    -- decide anything else: the file has not been read, so `buftype` and `filetype` are
    -- still empty even for a quickfix or help buffer.
    --
    -- It also settles `nvim <file>` for free. nvim creates the buffers for the argument
    -- list before it sources init.lua, so no BufAdd is ever seen for them and the file
    -- named on the command line is never a preview -- it keeps its tab, the way opening a
    -- file from a shell does in an IDE, while the files opened from inside the session are
    -- the ones that take turns.
    --
    -- One case arrives the other way round, and it is the one that piled tabs up: `:edit
    -- <path>` typed with the cursor in the tree. neo-tree refuses to let a file take its
    -- window, so it sends the buffer back out (`b#`, then a scheduled `bdelete` and a
    -- reopen in a split), and measured against the real config that reopen displays the
    -- buffer *before* re-listing it -- BufWinEnter, then this event. Waiting for a
    -- BufWinEnter that has already been and gone left the buffer marked "not yet seen"
    -- forever: listed, unreclaimable, one permanent tab per edit. So a BufAdd for a buffer
    -- that is already loaded and already on screen is the second half of that sequence and
    -- is decided here instead. `buf_is_loaded` is the discriminator, not the window:
    -- measured, `:edit`, `:help` and `:copen` all reach their first BufAdd with the buffer
    -- unloaded (and `:help` already in its window), while this one arrives loaded, read and
    -- with its filetype set.
    if vim.api.nvim_buf_is_loaded(args.buf) then
      for _, win in ipairs(vim.fn.win_findbuf(args.buf)) do
        if not is_float(win) then
          if is_preview_candidate(args.buf, win) then
            adopt(args.buf)
          end
          return
        end
      end
    end
    unseen[args.buf] = true
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  desc = "Take over the preview tab with a newly opened file",
  callback = function(args)
    if not unseen[args.buf] then
      return
    end
    -- Consumed whether or not it qualifies: a buffer that first appeared in a float or as
    -- somebody's UI has had its one chance, and counts as already open from here on.
    unseen[args.buf] = nil
    -- Walking the history is not opening a file. Going back reopens the tab that was closed
    -- and keeps the one being left, which is the whole point of the back button; adopting
    -- here would close the outgoing buffer on every keypress, so a walk would tear a buffer
    -- down and re-read it -- LSP attach, treesitter parse -- per step, and the tabline would
    -- never show more than one tab while navigating. The file arrived at is not a preview
    -- either: it has been visited before, which is what `unseen` above has just recorded.
    if walking_jump_history() then
      -- Reopened by a walk: provisional, so a revisited file shows in the tabline and is
      -- reclaimed by the next ordinary open along with every other file the same walk
      -- reopened, instead of settling there. Nothing is closed to make room for it -- see
      -- `mark_provisional`.
      if is_preview_candidate(args.buf, vim.api.nvim_get_current_win()) then
        mark_provisional(args.buf)
      end
      return
    end
    if is_preview_candidate(args.buf, vim.api.nvim_get_current_win()) then
      adopt(args.buf)
    end
  end,
})

vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
  group = group,
  desc = "Promote a tab that is only being looked at once it has been edited",
  callback = function(args)
    -- Both, because a walk arrival is as editable as anything else: measured, a file reopened
    -- by `<A-[>` and then typed into survives the next ordinary open like any edited tab.
    if preview == args.buf then
      preview = nil
    end
    provisional[args.buf] = nil
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  desc = "Keep a dismissed landing view from leaving a tab behind",
  callback = function(args)
    -- snacks maps `q` to `:bd` on its dashboard buffer, and `q` is the keypress a view with
    -- nothing editable in it invites. Measured on a fresh `nvim .` under dev: the tabline
    -- goes from empty to one nameless tab, because deleting the buffer a window is showing
    -- makes nvim create a listed one to fill it -- the same `[buffer N]` from the other
    -- direction. Answered here, after the fact, rather than by rebinding `q` on that
    -- buffer: snacks sets the dashboard's filetype with `eventignore = "all"`, so no
    -- FileType autocmd fires for it and there is nothing to hang a buffer-local map on that
    -- does not depend on snacks' own event names. This way covers `:bd` typed by hand too.
    if vim.bo[args.buf].filetype ~= "snacks_dashboard" then
      return
    end
    vim.schedule(function()
      local listed = vim.fn.getbufinfo({ buflisted = 1 })
      if #listed ~= 1 or not is_bare_placeholder(listed[1].bufnr) then
        return
      end
      for _, win in ipairs(vim.fn.win_findbuf(listed[1].bufnr)) do
        vim.api.nvim_win_set_buf(win, empty_buffer())
      end
      if #vim.fn.win_findbuf(listed[1].bufnr) == 0 then
        pcall(vim.cmd.bdelete, { count = listed[1].bufnr })
      end
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "qf",
  desc = "Keep the quickfix window out of the buffer list",
  callback = function(args)
    -- Measured on 0.12.4: `:copen` creates its buffer listed, which puts it in barbar's
    -- buffer list, and having no name it is drawn as `[buffer 2]` -- the same phantom tab
    -- the close path above exists to avoid, arriving from the other direction. Nothing that
    -- uses the quickfix list reads `buflisted`; `:copen`, `:cnext` and `:cc` are unaffected.
    vim.bo[args.buf].buflisted = false
  end,
})

vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  desc = "Forget a buffer that is gone",
  callback = function(args)
    unseen[args.buf] = nil
    provisional[args.buf] = nil
    if preview == args.buf then
      preview = nil
    end
  end,
})

if vim.fn.argc(-1) == 0 then
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    desc = "Put the landing view on a bare start",
    callback = function()
      -- `nvim` with no arguments leaves the ordinary unnamed startup buffer, and it is
      -- listed: measured under the remote profile on a real terminal, barbar draws it as
      -- `[buffer 1]` for the rest of the session, and it goes on sitting beside the preview
      -- tab once files are opened. Under dev the question never arises on a terminal --
      -- snacks takes buffer 1 over for the dashboard and unlists it -- and that is exactly
      -- why this needs no profile check: the guards in `replace_placeholder` only recognise
      -- an empty, unnamed, listed buffer that is the only one there is, which is what a bare
      -- start leaves and what a dashboard, a named file or an opened directory are not.
      vim.schedule(replace_placeholder)
    end,
  })
end

vim.api.nvim_create_autocmd("BufDelete", {
  group = group,
  desc = "Put the landing view beside the sidebar when a directory is opened",
  callback = function(args)
    -- A directory buffer being deleted is the hijack finishing: it is the last thing
    -- neo-tree does, from the callback it navigates the tree with, so by then the sidebar
    -- and the placeholder both exist. The two earlier moments are both wrong -- the sidebar
    -- window appears while the directory buffer is still listed, and the placeholder
    -- appears before the tree does. Scheduled because a buffer is still on the list inside
    -- its own BufDelete. Not restricted to startup: `:edit <dir>` from an empty buffer
    -- leaves the same placeholder, and every other case is turned away by the guards in
    -- `replace_placeholder`.
    if vim.fn.isdirectory(args.file) == 1 then
      vim.schedule(replace_placeholder)
    end
  end,
})

return M
