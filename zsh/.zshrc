export PATH="/opt/homebrew/opt/postgresql@13/bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias pp='pnpm'
alias c='code'
alias gg='go get .'
alias lg='lazygit'
alias tn='tmux new-session -s'
alias tl='tmux list-sessions'
alias ta='tmux attach-session'
export PATH="/usr/local/mysql/bin:$PATH"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

. "$HOME/.local/bin/env"

autoload -U add-zsh-hook
tmux-git-autofetch() {($HOME/.config/tmux/plugins/tmux-git-autofetch/git-autofetch.tmux --current &)}
add-zsh-hook chpwd tmux-git-autofetch
    

# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# Haskell
export PATH=~/haskell-course/.ghcup/bin:$PATH

# Expo
export EXPO_PACKAGE_MANAGER=pnpm

# Android studio 
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Use viu to display image
function view-image() {
  viu "$1"
}

# Added by Antigravity
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
