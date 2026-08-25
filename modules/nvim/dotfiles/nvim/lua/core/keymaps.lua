local M = {}

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

function M.setup()
  map("n", "<leader>w", "<cmd>write<cr>", "Save buffer")
  map("n", "<leader>q", "<cmd>quit<cr>", "Quit window")
  map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")

  -- Additions to native <C-o> / <C-i>, not replacements: the pair below is the Zed habit,
  -- the native one still works. Normal mode only, like every other binding in this config:
  -- a global terminal-mode map intercepts its characters before the shell running in
  -- :terminal ever sees them, and there is nothing to jump to in a terminal buffer anyway.
  map("n", "<A-[>", "<C-o>", "Jump back")
  map("n", "<A-]>", "<C-i>", "Jump forward")
end

return M
