require("core.options")

local profile = require("core.profile").current()
vim.g.dotfiles_nvim_profile = profile

require("core.keymaps").setup(profile)

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  if profile == "remote" and vim.env.NVIM_BOOTSTRAP ~= "1" then
    vim.notify("Shared Neovim plugins are not installed; run modules/nvim/bootstrap.sh when online", vim.log.levels.WARN)
    return
  end

  if vim.fn.executable("git") ~= 1 then
    vim.notify("Neovim plugins are unavailable; using the built-in editor", vim.log.levels.WARN)
    return
  end

  local output = vim.fn.system({
    "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.notify("Neovim plugins are unavailable; using the built-in editor: " .. output, vim.log.levels.WARN)
    return
  end
end

vim.opt.rtp:prepend(lazypath)
require("lazy").setup(require("plugins").spec(profile), {
  checker = { enabled = false },
  change_detection = { notify = false },
})
