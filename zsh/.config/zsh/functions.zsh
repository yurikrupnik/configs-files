 lsd() {
   gcloud components update
 }

# knd() {
#     kubectl config set-context --current --namespace=$1
# }

# ad() {
#   kubectx
# }

# ku() {
#     kubectl config unset current-context
# }

# update() {
#     brew bundle --file ~/configs-files/brew/Brewfile
#     rustup update
#     gcloud components update
# }

# stam() {
#   cd ~/projects/
#   npx create-nx-workspace --pm pnpm --preset=@monodon/rust
#   bun exec nx generate @monodon/rust:library --name=s --directory=aris --no-interactive --dry-run
#   bun add -D @nxlv/python
#   uv init
# }

# nx-run() {
#   bun nx run-many -t $1 --parallel --max-parallel=10 --prod
# }

# nx-runa() {
#   bun nx affected -t $1 --parallel --max-parallel=10 --prod
# }

# kc() {
#   kind create cluster
#   sleep 20
#   istioctl install --set profile=demo -y
# }
