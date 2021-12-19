#!/bin/sh
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

LOG_FOLDER="$SCRIPTPATH/logs"
LOG_FILE="$LOG_FOLDER/install $(date +%F).log"

OH_MY_ZSH_SRC=$SCRIPTPATH/zsh-config/oh-my-zsh

VIM_SRC=$SCRIPTPATH/vim-config
VIM_DST=$HOME/.vim

ZSHRC_SRC=$SCRIPTPATH/zsh-config/zshrc
ZSHRC_DST=$HOME/.zshrc

CONFIG_OLD=$HOME/.config.old/

logit() {
    echo "$(date +'%F %X') [$1] - ${@:2}" >> $LOG_FILE
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
    which $BIN &> /dev/null || $PACK_MANAGER install $BIN

    logger "Install $BIN"
}

link_files() {
    local SOURCE=$1
    local DESTINY=$2

    mkdir -p $DESTINY
    ln -s $SOURCE $DESTINY

    logger "Linking $SOURCE to $DESTINY"
}

mkdir -p $LOG_FOLDER
set_package_manager

DEPENDENCIES=(git vim zsh curl wget nodejs npm python3 python3-pip)

for DEPENDENCY in ${DEPENDENCIES[@]}; do
    install_dependency $DEPENDENCY
done

git submodule update --init --recursive
logger "Get submodules"

link_files $ZSHRC_SRC $ZSHRC_DST
link_files $VIM_SRC $VIM_DST

npm --prefix $SCRIPTPATH/coc/extensions install
logger "Install coc extensions"
