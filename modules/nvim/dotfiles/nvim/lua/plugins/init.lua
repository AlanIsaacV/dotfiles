-- lazy honours `cond` on an import before it reads the directory, so the dev specs are
-- never even parsed under the remote profile.
return {
  { import = "plugins.shared" },
  { import = "plugins.dev", cond = vim.g.dotfiles_nvim_profile == "dev" },
}
