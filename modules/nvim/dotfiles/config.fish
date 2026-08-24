set -gx EDITOR nvim
set -gx VISUAL nvim

# Same directory Neovim resolves as stdpath("data"), which is where mason installs its
# binaries; never the literal ~/.local/share, so it follows XDG_DATA_HOME.
set -l nvim_data $XDG_DATA_HOME
test -n "$nvim_data"; or set nvim_data $HOME/.local/share

# --global --path keeps this in $PATH for the current shell instead of the default
# universal $fish_user_paths, which would survive both a change of XDG_DATA_HOME and
# uninstalling this module, accumulating mason paths that no longer exist.
# fish_add_path silently skips a directory that is not there, so before mason's first
# install there is simply no entry, and a shell already open when it runs needs restarting.
fish_add_path --global --path $nvim_data/nvim/mason/bin
