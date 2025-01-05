#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it and try again."
    exit 1
fi

# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# install homebrew
#sh <(curl -L https://nixos.org/nix/install)

if command -v brew >/dev/null 2>&1; then
  brew bundle --file brew/Brewfile
else
  echo "Error: Homebrew is not installed or not in PATH"
  exit 1
fi

#kubectl krew install kuttl
if command -v rustup >/dev/null 2>&1; then
  echo "Rustup is already installed"
else
  echo "Error: rustup is not installed or not in PATH"
  exit 1
fi

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

stow --dir=$HOME/.dotfiles --target=$HOME zsh

curl -fsSL https://get.jetify.com/devbox | bash


# go
go install github.com/mitranim/gow@latest
# brew
brew tap fermyon/tap
brew install fermyon/tap/spin
# rust
#cargo install nu --locked
#cargo install cargo-binstall
#cargo binstall cargo-generate
#cargo binstall wasm-pack
#cargo binstall cargo-leptos
#cargo binstall sqlx-cli
#cargo binstall cargo-expand
#cargo binstall create-tauri-app
#cargo binstall protobuf-codegen
#cargo binstall cargo-run-script
#cargo binstall trunk
#cargo binstall salvo-cli
#cargo binstall cargo-watch
#cargo binstall cargo-component
#cargo binstall --no-default-features --force cargo-make
