#!/usr/bin/env bash
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
LOG_FILE="$SCRIPT_PATH/logs/install_$(date +%F).log"

OH_MY_ZSH_SRC="$SCRIPT_PATH/zsh-config"
OH_MY_ZSH_DST="$HOME/.config/"

VIM_SRC="$SCRIPT_PATH/vim-config"
VIM_DST="$HOME/.vim"

GIT_SRC="$SCRIPT_PATH/git/gitonfig"
GIT_DST="$HOME/.gitonfig"

ZSHRC_SRC="$SCRIPT_PATH/zsh-config/zshrc"
ZSHRC_DST="$HOME/.zshrc"

declare -A DEPENDENCIES=(
    ["git"]="git"
    ["vim"]="vim"
    ["zsh"]="zsh"
    ["curl"]="curl"
    ["wget"]="wget"
    ["node"]="nodejs"
    ["npm"]="npm"
    ["python3"]="python3"
)

logit() {
    echo "$(date +'%F %X') [$1] - ${@:2}" >>${LOG_FILE}
}

logger() {
    local STATUS=$?
    local MESSAGE=$1

    if [ $STATUS -eq 0 ]; then
        logit "INFO" $MESSAGE
    else
        logit "ERROR" "Failed: $MESSAGE"
    fi
}

set_package_manager() {
    case $(uname) in
    Linux )
        logger "OS Linux"
        which dnf &> /dev/null && PACK_MANAGER=dnf; return
        which yum &> /dev/null && PACK_MANAGER=yum; return
        which apt-get &> /dev/null && PACK_MANAGER=apt-get; return
        ;;
    Darwin )
        logger "OS MacOs"
        which brew &> /dev/null || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        PACK_MANAGER=brew
        ;;
    * )
        logit "CRITICAL" "This script only works with Linux & Darwin (MacOs)"
        ;;
    esac
}

install_dependency() {
    local BIN=$1
    local PACKAGE=$2
    which $BIN &> /dev/null || sudo $PACK_MANAGER install $PACKAGE

    logger "Install $BIN"
}

install_dependency_git() {
    local REPOSITORY=$1
    local DIRECTORY=$2
    local INSTALL_FILE=$3

    git clone --depth 1 $REPOSITORY $DIRECTORY
    "$DIRECTORY/$INSTALL_FILE"
    logger "Installing $(basename ${REPOSITORY%.git})"
}

link_files() {
    local SOURCE=$1
    local DESTINY=$2
    ln -sf $SOURCE $DESTINY

    logger "Sym link from $SOURCE to $DESTINY"
}

validate_folder() {
    local FOLDER=$1
    mkdir -p $FOLDER

    logger "Create folder $FOLDER"
}

validate_folder ${LOG_FILE%/*}
set_package_manager

for DEPENDENCY in ${!DEPENDENCIES[@]}; do
    install_dependency ${DEPENDENCY} ${DEPENDENCIES[$DEPENDENCY]}
done

git submodule update --init --recursive
logger "Get submodules"

validate_folder ${OH_MY_ZSH_DST%/*}

link_files $OH_MY_ZSH_SRC $OH_MY_ZSH_DST
link_files $ZSHRC_SRC $ZSHRC_DST
link_files $VIM_SRC $VIM_DST
link_files $GIT_SRC $GIT_DST

install_dependency_git https://github.com/junegunn/fzf.git $HOME/.fzf install
install_dependency_git https://github.com/wting/autojump.git $HOME/.autojump install.py

python3 -m ensurepip --upgrade
python3 get-pip.py
logger "Get/Update pip"

python3 -m pip install --upgrade wheel
pip3 install --user httpie pygments
logger "Install utilities from Python"

npm --prefix "$SCRIPT_PATH/coc/extensions" install
logger "Install coc extensions"

chsh -s $(grep -m 1 zsh /etc/shells)
