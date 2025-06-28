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
    brew bundle --file ~/configs-files/brew/Brewfile
    rustup update
}

create-nx() {
  cd ~/repos/protos
  npx create-nx-workspace --pm pnpm --preset=@monodon/rust
  pnpm exec nx generate @monodon/rust:library --name=s --directory=aris --no-interactive --dry-run
  bun nx generate @monodon/rust:binary --name=api --directory=zerg
  bun add -D @nxlv/python
  uv init --bare --python=3.13
  bun nx generate @nxlv/python:uv-project --name=shared --projectType=library --directory=python --buildBundleLocalDependencies=false --buildLockedVersions=false --codeCoverage=false --codeCoverageHtmlReport=false --codeCoverageXmlReport=false --projectNameAndRootFormat=derived --unitTestHtmlReport=false --unitTestJUnitReport=false --no-interactive --dry-run
  bun nx generate @nxlv/python:uv-project --name=job --directory=zerg --projectNameAndRootFormat=derived --no-interactive
}

nx-run() {
  bun nx run-many -t $1 --parallel --max-parallel=16
}

nx-runa() {
  bun nx affected -t $1 --parallel --max-parallel=16
}

internal() {
  istioctl install --set profile=demo -y
}

kc() {
  kind create cluster --config cluster.yaml
  sleep 20
  istioctl install --set profile=demo -y
#  ds=${gcloud auth print-identity-token}
#  dsa=${gcloud auth print-access-token}
#  echo $dsa
#  echo $ds
}

kd() {
  kind delete cluster
}
