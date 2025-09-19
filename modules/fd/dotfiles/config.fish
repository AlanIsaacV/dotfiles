set IGNORED_PATTERNS "-E .git -E __pycache__ -E node_modules -E .idea"

set -gx FZF_DEFAULT_COMMAND "fd --follow --hidden --strip-cwd-prefix $IGNORED_PATTERNS"
set -gx FZF_CRTL_T_COMMAND $FZF_DEFAULT_COMMAND

set -gx FZF_ALT_C_COMMAND "fd --type d --follow --hidden --strip-cwd-prefix $IGNORED_PATTERNS"
