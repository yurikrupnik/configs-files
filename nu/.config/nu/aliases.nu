#!/usr/bin/env nu

# System aliases
alias lg = lazygit
# alias k = kubectl
alias kx = kubectx
#alias lsl = eza --no-permissions --no-user --no-time --long
#alias ls = eza --no-permissions --no-user --no-time
alias cat = bat --paging never --style plain

# Simple aliases
#alias d = docker
alias g = gcloud
alias pu = pulumi
alias p = pnpm
alias c = cargo
alias cli = claude
alias cdoc = cargo doc
alias b = bacon

# Custom commands for complex operations
def fzfp [] {
    fzf --preview="bat --style numbers --color=always {}"
}

def drmi [] {
    docker rmi (docker images -aq) -f
}

def dclean [] {
    docker system prune -f; docker volume prune -f
}

def cdoco [] {
    cargo doc --open
}