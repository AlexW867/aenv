#!/usr/bin/env bash

# ZSH
## oh-my-zsh
echo "install oh-my-zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "install oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "oh-my-zsh installed, skip..."
fi

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    echo "install zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions installed, skip..."
fi

# zsh-autocomplete
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete" ]; then
    echo "install zsh-autocomplete..."
    git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autocomplete
else
    echo "zsh-autocomplete installed, skip..."
fi

# TMUX
## TPM
echo "install TPM (tmux plugin manager)..."
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    echo "TPM ....ok"
else
    echo "TPM installed, skip..."
fi

###############################
# clone .dotfiles from github #
###############################
rm -fr ~/.dotfiles
git clone https://github.com/alexw867/dotfiles ~/.dotfiles
rcup -v
chsh -s $(which zsh)

# 完成後提示

echo "還有幾個要手動處理..."
echo "* 進 nvim 會自動安裝 lazy.nvim"
echo "* 進 tmux 按 前綴 +I(大寫) 安裝 tmux 外掛"

