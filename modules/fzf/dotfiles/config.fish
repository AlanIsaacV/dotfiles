fzf --fish | source

set -gx FZF_DEFAULT_OPTS "
  --walker-skip .git,node_modules,target,.venv,__pycache__
  --height 90%
  --info=inline
  --ansi
  --preview-window 'right:70%'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"
