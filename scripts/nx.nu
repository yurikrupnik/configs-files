use kc-cluster.nu
# use setup-shell.nu
use app-management.nu

export def main [] {
    #kind create cluster

    # bun nx run-many -t {arg} --parallel --max-parallel=16 --prod
    # bun nx run-many -t {arg} --parallel --max-parallel=16 --prod
    # bun nx run-many -t {arg} --parallel --max-parallel=16 --prod
    #tilt up
    let cpus = (sys cpu | length)
    print $cpus
    print $cpus
    # bun nx run-many -t {arg} --parallel --max-parallel=$cpus --prod
    #kc-cluster
    # cluster-create
  #  tilt up
    #bun nx run-many -t build --parallel $"--max-parallel=($cpus)"
}

export def "main local config" [] {
    ls
}

export def "main-cluster-delete" [] {
    kind delete cluster
}

def "cluster-create" [] {
    #kind create cluster
}
