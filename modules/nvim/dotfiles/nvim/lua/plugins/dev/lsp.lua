local lang = require("lang")

-- A timer rather than the `CursorHold` event, and 1500 ms rather than anything shorter.
-- CursorHold fires at `updatetime`, which is 250 ms here (core/options.lua) -- fast enough that
-- this float would be on screen almost continuously while reading. Raising `updatetime` would
-- have been the one-line version and would have dragged snacks' reference highlighting and
-- gitsigns along with it, since both hang off that same option; a private delay decouples this
-- one number from all of them.
local IDLE_DELAY_MS = 1500

-- Neovim's own hover puts `---` between one client's contents and the next
-- (runtime/lua/vim/lsp/buf.lua:181), so it is also what separates the diagnostic block from the
-- hover block below it. Nothing here invents a marker.
local FLOAT_SEPARATOR = "---"

-- The whole of the debounce. Every scheduled float remembers the counter it was scheduled at; a
-- later cursor move bumps the counter and the older callback finds itself stale and returns.
-- Deliberately not a libuv timer: there would be a handle to own, stop and close per buffer, and
-- an integer cannot leak one. Module-level rather than per-buffer because only one of these
-- floats may exist at a time anywhere.
local idle_generation = 0

local function trim_blank(lines)
  while #lines > 0 and vim.trim(lines[1]) == "" do
    table.remove(lines, 1)
  end
  while #lines > 0 and vim.trim(lines[#lines]) == "" do
    table.remove(lines)
  end
  return lines
end

-- Rendered as markdown rather than with the highlight groups `vim.diagnostic.open_float` uses,
-- because the hover underneath is markdown and the float can only be stylized one way. Bold is
-- what survives that path.
local function diagnostic_lines(bufnr, lnum)
  local lines = {}
  for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { lnum = lnum })) do
    local severity = vim.diagnostic.severity[diagnostic.severity]
    local source = diagnostic.source and (" _(" .. diagnostic.source .. ")_") or ""
    lines[#lines + 1] = ("**%s**%s"):format(severity, source)
    vim.list_extend(lines, vim.split(diagnostic.message, "\n", { trimempty = true }))
    -- A blank line so markdown starts a new paragraph at the next diagnostic instead of
    -- reflowing two unrelated messages into one.
    lines[#lines + 1] = ""
  end
  return trim_blank(lines)
end

local function request_hover(bufnr, callback)
  if #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/hover" }) == 0 then
    return callback({})
  end

  -- Captured now: the callback runs in whatever window is current when the server answers, and
  -- the position has to be the one the request was made about.
  local win = vim.api.nvim_get_current_win()
  vim.lsp.buf_request_all(bufnr, "textDocument/hover", function(client)
    -- `make_position_params` warns once if the encoding is left out, so each client's own is
    -- passed even though every server here happens to agree on utf-16.
    return vim.lsp.util.make_position_params(win, client.offset_encoding)
  end, function(results)
    local lines = {}
    for _, response in pairs(results) do
      if response.result and response.result.contents then
        vim.list_extend(lines, vim.lsp.util.convert_input_to_markdown_lines(response.result.contents))
      end
    end
    callback(trim_blank(lines))
  end)
end

-- One float holding both, not two floats stacked. Two is what would read best and it is not
-- available: `vim.lsp.buf.hover()` and `vim.diagnostic.open_float()` both go through
-- `vim.lsp.util.open_floating_preview`, which closes the buffer's existing `lsp_floating_preview`
-- before opening its own (runtime/lua/vim/lsp/util.lua:1716-1719), so calling both in a row leaves
-- only the second. Building the second window by hand would mean owning its placement against the
-- screen edges and tearing both down together, for the same information this shows in one frame.
local function show_idle_float(bufnr, generation)
  local diagnostics = diagnostic_lines(bufnr, vim.api.nvim_win_get_cursor(0)[1] - 1)

  request_hover(bufnr, function(hover)
    -- The request is asynchronous, so the cursor may have moved on while the server thought
    -- about it. A float describing where the cursor used to be is worse than no float.
    if generation ~= idle_generation or vim.api.nvim_get_current_buf() ~= bufnr then
      return
    end

    local contents = vim.deepcopy(diagnostics)
    if #diagnostics > 0 and #hover > 0 then
      contents[#contents + 1] = FLOAT_SEPARATOR
    end
    vim.list_extend(contents, hover)
    -- Neither of the two had anything to say: no diagnostic on this line and nothing hoverable
    -- under the cursor. An empty bordered box is not an answer.
    if #contents == 0 then
      return
    end

    -- No `border`: `winborder` is global (core/options.lua) and already gives every LSP float the
    -- same rounded frame, so this one looks like the one `K` opens rather than like a special
    -- case. Not focusable, because a window that appears without being asked for and can take the
    -- cursor is a window that eats the next keystroke; `K` opens the focusable one.
    vim.lsp.util.open_floating_preview(contents, "markdown", { focus = false, focusable = false })
  end)
end

local function on_attach(_, bufnr)
  local options = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, vim.tbl_extend("force", options, { desc = "Go to definition" }))
  vim.keymap.set("n", "<leader>lr", vim.lsp.buf.references, vim.tbl_extend("force", options, { desc = "Find references" }))
  vim.keymap.set("n", "<leader>la", vim.lsp.buf.code_action, vim.tbl_extend("force", options, { desc = "Code action" }))
  -- Bound explicitly even though Neovim already binds `K` to hover at attach when nothing else
  -- has claimed it (runtime/lua/vim/lsp.lua:869-873) -- which is why hover appeared to be missing
  -- from this config while in fact working. Same behaviour; the difference is that the file says
  -- so, and that which-key has something to show.
  vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", options, { desc = "Hover documentation" }))

  -- Buffer-local, and registered from here rather than globally: `on_attach` runs only where a
  -- language server exists, which is also what keeps this out of neo-tree, the dashboard and
  -- terminal buffers without naming a single one of them.
  vim.api.nvim_create_autocmd("CursorMoved", {
    buffer = bufnr,
    desc = "Hover and diagnostics once the cursor has been still",
    callback = function()
      idle_generation = idle_generation + 1
      local generation = idle_generation
      vim.defer_fn(function()
        if generation ~= idle_generation or vim.api.nvim_get_current_buf() ~= bufnr then
          return
        end
        -- Normal mode only. Insert mode has blink's signature window, and a second float
        -- competing with it while typing is the noise this whole change exists to remove.
        if vim.api.nvim_get_mode().mode ~= "n" then
          return
        end
        show_idle_float(bufnr, generation)
      end, IDLE_DELAY_MS)
    end,
  })
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
      completion = {
        documentation = {
          -- Off by default in blink (config/completion/documentation.lua), which is why the menu
          -- used to show names and nothing else. The 500 ms default delay is left alone: it is
          -- one number and no amount of reading the source says whether it is right.
          auto_show = true,
        },
      },
      -- Upstream calls this experimental and opt-in (README), and it is still the version of this
      -- feature worth having: blink's signature window shares a position emitter with its own
      -- completion menu, so the two never land on top of each other -- which a separate signature
      -- plugin, having no idea blink exists, cannot promise. What it gives up is inline
      -- virtual-text parameter hints, which blink has no equivalent of.
      signature = {
        enabled = true,
        trigger = {
          -- Blink's defaults fire on the trigger characters the server declares -- `(` and `,` --
          -- and nothing else, so the window is gone the moment you start typing the argument
          -- itself, which is precisely when the parameter list is worth reading. These two keep
          -- it up through the name.
          show_on_keyword = true,
          show_on_insert = true,
        },
        window = {
          -- The signature alone answers "which parameter am I on"; this is what answers "and
          -- what is it".
          show_documentation = true,
        },
      },
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
        -- Nothing is drawn into the buffer any more. `virtual_lines = { current_line = true }`,
        -- which is what this used to be, renders the full message as real lines under the
        -- cursor's line -- so every line below it slid down and back up on each cursor move, and
        -- reading around a diagnostic became the hard part. `virtual_text` stays off for the
        -- reason it always was: it truncates what basedpyright and rust_analyzer produce. The
        -- message now lives in the idle float above, composed with the hover, so it exists in
        -- exactly one place; the sign in the gutter is what says the line has one at all.
        virtual_text = false,
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
