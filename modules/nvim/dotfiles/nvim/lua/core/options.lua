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
}

for name, value in pairs(options) do
  vim.opt[name] = value
end
