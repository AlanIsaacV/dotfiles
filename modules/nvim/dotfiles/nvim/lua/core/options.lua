vim.g.mapleader = " "
vim.g.maplocalleader = " "

local options = {
  number = true,
  relativenumber = true,
  mouse = "a",
  ignorecase = true,
  smartcase = true,
  splitright = true,
  splitbelow = true,
  signcolumn = "yes",
  updatetime = 250,
  clipboard = "unnamedplus",
  undofile = true,
  termguicolors = true,
  winborder = "rounded",
  -- Dropping Neovim's "clean" default is what lets back-navigation reach a file whose tab
  -- was closed. Measured on 0.12.4: with "clean", a :bdelete strips that file's jumplist
  -- entries and <C-o> can never get back to it; without it the entries survive and <C-o>
  -- returns to the exact line, relisting the buffer so the tabline shows it again. A
  -- :bwipeout destroys the entries whatever this is set to, which is why nothing in this
  -- config closes a buffer that way. "stack" makes a jump taken from mid-history discard
  -- what was ahead of it, the way a browser's back button does, and "view" restores the
  -- scroll position the jump was taken from. Both flags exist on 0.11, the floor the shared
  -- path holds to (lua/dotfiles/health.lua); only "view" reaching a tagstack pop is newer.
  jumpoptions = "stack,view",
}

for name, value in pairs(options) do
  vim.opt[name] = value
end
