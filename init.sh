# install brew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# install homebrew
#sh <(curl -L https://nixos.org/nix/install)

brew bundle

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

stow --dir=$HOME/.dotfiles --target=$HOME zsh

curl -fsSL https://get.jetify.com/devbox | bash


# go
go install github.com/mitranim/gow@latest
# brew
brew tap fermyon/tap
brew install fermyon/tap/spin
# rust
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
