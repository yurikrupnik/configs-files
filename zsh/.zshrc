# see https://www.youtube.com/watch?v=KBh8lM3jeeE&t=36s for more details
[[ -f $HOME/.config/zsh/aliases.zsh ]] && source $HOME/.config/zsh/aliases.zsh
[[ -f $HOME/.config/zsh/functions.zsh ]] && source $HOME/.config/zsh/functions.zsh
# [[ -f $HOME/.config/zsh/exports.zsh ]] && source $HOME/.config/zsh/exports.zsh
# [[ -f $HOME/.config/zsh/paths.zsh ]] && source $HOME/.config/zsh/paths.zsh
# Nix!
# export NIX_CONF_DIR=$HOME/.config/nix

# Devbox
DEVBOX_NO_PROMPT=true
eval "$(devbox global shellenv --init-hook)"
# Brew
# export PATH=/opt/homebrew/bin:$PATH
eval "$(/opt/homebrew/bin/brew shellenv)"
# Starship
eval "$(starship init zsh)"
# export STARSHIP_CONFIG=~/.config/starship/starship.toml
# Zoxide
eval "$(zoxide init --cmd cd zsh)"

# # Rust
# . "$HOME/.cargo/env"

export LANG=en_US.UTF-8
export PATH="$HOME/go/bin:$PATH"
export PATH="/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Added by Toolbox App
export PATH="$PATH:/Users/yurikrupnik/Library/Application Support/JetBrains/Toolbox/scripts"
export EDITOR=zed
export KUBE_EDITOR=zed
# export TERMINAL=WarpTerminal

HISTSIDE=5000
SAVEHIST=$HISTSIDE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_dups
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

# alias code=zed
# alias k=kubectl
# alias kx=kubectx
# alias lsl='eza --no-permissions --no-user --no-time --long'
# alias ls='eza --no-permissions --no-user --no-time'
# alias cat='bat --paging never --style plain'
# alias fzfp='fzf --preview="bat --style numbers --color=always {}"'
# alias d=docker
# alias drmi='docker rmi $(docker images -aq) -f'
# alias dclean='docker system prune -f && docker volume prune -f'
# alias g=gcloud
# alias pu=pulumi
# alias p=pnpm
# alias c=cargo
# alias cdoc=cargo doc
# alias cdoco=cargo doc --open


autoload -Uz compinit && compinit
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
