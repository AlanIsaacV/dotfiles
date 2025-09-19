#!/bin/bash

echo 'uv generate-shell-completion fish | source' > ~/.config/fish/completions/uv.fish
echo 'uvx --generate-shell-completion fish | source' > ~/.config/fish/completions/uvx.fish
