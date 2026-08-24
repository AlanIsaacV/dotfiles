local M = {}

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

function M.setup()
  map("n", "<leader>w", "<cmd>write<cr>", "Save buffer")
  map("n", "<leader>q", "<cmd>quit<cr>", "Quit window")
  map("n", "<Esc>", "<cmd>nohlsearch<cr>", "Clear search highlight")
end

return M
