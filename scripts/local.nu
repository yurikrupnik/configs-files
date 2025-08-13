use std/assert
use nx.nu
use setup-shells.nu
#use ~/config-files/setup-shells.nu

def main [] {
  # let working_path = if ($path | is-empty) { $env.PWD } else { $path }
  # ls $working_path
  nx main-cluster-delete
  let current_context = (kubectl config current-context | complete)
  assert ($current_context.exit_code != 0) "Active Kubernetes cluster found"
  main de
}

def "main de" [] {
    print "running de!"
}

def maina [path?: string] {
    let working_path = if ($path | is-empty) { $env.PWD } else { $path }
    ls $working_path
    #nx main local config
    #kind create cluster
}
def shit [] {
    ls
}
