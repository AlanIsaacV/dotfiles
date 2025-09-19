alias l="eza --long --header --group --all --group-directories-first --icons --git"
alias lt="l --tree"

set IGNORED_PATTERNS "-I \"__pycache__|.git|node_modules|.idea\""

set -gx EZA_CONFIG_DIR ~/.config/eza
set -gx FZF_ALT_C_OPTS "--preview 'eza --tree -L2 --icons --group-directories-first --color=always $IGNORED_PATTERNS {}'"

bind alt-l l
