#!/usr/bin/env sh
set -eu

usage() {
  printf '%s\n' 'usage: bootstrap.sh [--install-lsp]' >&2
}

case "${1:-}" in
  ""|--install-lsp) ;;
  *) usage; exit 2 ;;
esac

if ! command -v nvim >/dev/null 2>&1; then
  printf '%s\n' 'nvim is not installed. Install Neovim 0.11+ first.' >&2
  exit 1
fi

nvim_version="$(nvim --version | sed -n '1s/^NVIM v//p')"
case "$nvim_version" in
  0.11.*|0.12.*|0.13.*|0.14.*|0.15.*|0.16.*|[1-9].*) ;;
  *)
    printf '%s\n' "Neovim 0.11+ is required (found ${nvim_version:-unknown})." >&2
    exit 1
    ;;
esac

for command_name in git fzf rg fd; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf '%s\n' "warning: optional command not found: $command_name" >&2
  fi
done

if [ "${1:-}" = "--install-lsp" ]; then
  if [ "${NVIM_PROFILE:-}" = "remote" ] || [ "$(uname -s)" != "Darwin" ] || [ -n "${SSH_TTY:-}${SSH_CONNECTION:-}" ]; then
    printf '%s\n' 'LSP installation is available only in the local macOS profile.' >&2
    exit 1
  fi
  NVIM_BOOTSTRAP=1 nvim --headless \
    '+lua if vim.g.dotfiles_nvim_profile ~= "local" then vim.api.nvim_err_writeln("Neovim local profile is not loaded; link the module first"); vim.cmd("cquit 1") end' \
    '+lua if vim.fn.exists(":MasonInstall") ~= 2 then vim.api.nvim_err_writeln("Mason is unavailable; check git and network access"); vim.cmd("cquit 1") end' \
    '+MasonInstall basedpyright gopls rust_analyzer' +qa
else
  NVIM_BOOTSTRAP=1 nvim --headless \
    '+lua if vim.g.dotfiles_nvim_profile == nil then vim.api.nvim_err_writeln("Neovim config is not loaded; link the module first"); vim.cmd("cquit 1") end' \
    '+lua if vim.fn.exists(":Lazy") ~= 2 then vim.api.nvim_err_writeln("lazy.nvim is unavailable; check git and network access"); vim.cmd("cquit 1") end' \
    '+Lazy! sync' +qa
fi
