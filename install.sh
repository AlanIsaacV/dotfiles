#!/usr/bin/sh
CWD=$(pwd)

LOG_FILE="$CWD/install $(date +%F).log"

OH_MY_ZSH_SRC=$CWD/zsh-config/oh-my-zsh

VIM_SRC=$CWD/vim-config
VIM_DST=$HOME/.vim

ZSHRC_SRC=$CWD/zsh-config/zshrc
ZSHRC_DST=$HOME/.zshrc

CONFIG_OLD=$HOME/.config.old/

logit() {
    echo "[ $(date +'%F %X') ] - ${*}" >>$LOG_FILE
}

step_done() {
    logit "Done!!\n"
}

fetch_updates() {
    logit "Fetching updates"
    apt-get update
    step_done
}

install_dependencies() {
    local BIN=$1

    logit "Installing $BIN"
    brew install $BIN
    step_done
}

copy_files() {
    local SOURCE=$1
    local DESTINY=$2

    logit "Linking $SOURCE to $DESTINY"
    mkdir -p $DESTINY
    ln -s $SOURCE $DESTINY
    step_done
}

move_files() {
    local SOURCE=$1
    local DESTINY=$2

    logit "Moving $SOURCE to $DESTINY"
    mv -v $SOURCE $DESTINY
    step_done
}

echo "LOG FILE INSTALL DOTFILES AND CONFI -- $(date +'%F %X') --" >$LOG_FILE

fetch_updates

install_dependencies git
install_dependencies vim
install_dependencies zsh
install_dependencies curl
install_dependencies wget
install_dependencies nodejs
install_dependencies npm
install_dependencies python3
install_dependencies python3-pip

logit "Installing python jedi and pylint"
pip3 install jedi pylint
step_done

logit "Getting submodules"
git submodule update --init --recursive
step_done

copy_files $ZSHRC_SRC $ZSHRC_DST
copy_files $VIM_SRC $VIM_DST

npm --prefix $CWD/coc/extensions install

mkdir -p $CONFIG_OLD
move_files $HOME/.bashrc $CONFIG_OLD
move_files $HOME/.profile $CONFIG_OLD

logit "Exporting ENV Variables"
export SHELL=/usr/bin/zsh
chsh -s /bin/zsh
step_done

# logit "Changing permission of Oh My ZSH"
# chmod -v -R 700 $OH_MY_ZSH_SRC
# step_done

# logit "Changing group and owner"
# chown -v -R $(whoami):$(whoami) $OH_MY_ZSH_SRC
# zsh

