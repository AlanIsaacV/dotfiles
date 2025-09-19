#!/bin/bash

FISH_PATH="$(which fish)"
echo $FISH_PATH | sudo tee -a /etc/shells
chsh -s $FISH_PATH
