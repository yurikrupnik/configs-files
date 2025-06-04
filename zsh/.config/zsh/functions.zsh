knd() {
    kubectl config set-context --current --namespace=$1
}

ad() {
  kubectx
}

ku() {
    kubectl config unset current-context
}

update() {
#    brew update
#    devbox version update
#    devbox global update
#
    brew bundle --file ~/configs-files/brew/Brewfile
    rustup update
    nix-collect-garbage
}

stam() {
  cd ~/projects/
  npx create-nx-workspace --pm pnpm --preset=@monodon/rust
  pnpm exec nx generate @monodon/rust:library --name=s --directory=aris --no-interactive --dry-run
  pnpm add -D @nxlv/python
  uv init
}

nx-run() {
  pnpm nx run-many -t $1 --parallel --max-parallel=10 --prod
}

nx-runa() {
  pnpm nx affected -t $1 --parallel --max-parallel=10 --prod
}

kc() {
  kind create cluster
  sleep 20
  istioctl install --set profile=demo -y
}