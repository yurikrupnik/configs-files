#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo "Error: curl is not installed. Please install it and try again."
    exit 1
fi

if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# install brew
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
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

cp $HOME/.zshenv $HOME/.zshenv.bak
rm $HOME/.zshenv
stow zsh
stow starship

curl -fsSL https://get.jetify.com/devbox | bash

# go
#go install github.com/mitranim/gow@latest

# rust
cargo install cargo-binstall
cargo binstall cargo-generate --no-confirm
cargo binstall wasm-pack --no-confirm
cargo binstall cargo-leptos --no-confirm
cargo binstall sqlx-cli --no-confirm
cargo binstall cargo-expand --no-confirm
cargo binstall create-tauri-app --no-confirm
cargo binstall protobuf-codegen --no-confirm
cargo binstall cargo-run-script --no-confirm
cargo binstall trunk --no-confirm
cargo binstall salvo-cli --no-confirm
cargo binstall cargo-watch --no-confirm
cargo binstall cargo-component --no-confirm
cargo binstall cargo-make --no-confirm
