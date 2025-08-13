use inc.nu *
use cluster.nu *

export-env {
    $env.NU_MODULES_DIR = ($nu.default-config-dir | path join "scripts")
}

# Resolve the target cluster name with sensible precedence:
# 1) --name flag
# 2) $env.KIND_CLUSTER_NAME
# 3) "dev" (default)
export def cluster-name [
  --name(-n): string = ""
] {
  if not ($name | is-empty) {
    $name
  } else if ($env.KIND_CLUSTER_NAME? | default "" | is-not-empty) {
    $env.KIND_CLUSTER_NAME
  } else {
    "dev"
  }
}

# Check if a kind cluster already exists
export def cluster-exists [name: string] {
  kind get clusters
  | lines
  | any { |it| $it == $name }
}

def create_local_cluster [ --name(-n): string = ""] {
    let name = (cluster-name --name $name)

      if (cluster-exists $name) {
        print $"⚠️  Cluster '{name}' already exists. Skipping create."
      } else {
        print $"Creating cluster with name: ($name)"
        kind create cluster --name $name
      }
}

# Create (idempotent): warn if exists
export def main [
  --name(-n): string = ""
] {
  let name = (cluster-name --name $name)
  create_local_cluster --name $name
  main install-flux
}

# Delete (idempotent): warn if missing
export def "main delete" [
  --name(-n): string
] {
  let name = (cluster-name --name $name)

  if (cluster-exists $name) {
    print $"Deleting cluster '{name}'"
    kind delete cluster --name $name
  } else {
    print $"⚠️  No cluster found with name '{name}'. Nothing to delete."
  }
}
# Delete (idempotent): warn if missing
export def "main list" [
  --name(-n): string
] {
    let s = kind export kubeconfig
    print $s
  # let name = (cluster-name --name $name)

  # if (cluster-exists $name) {
  #   print $"Deleting cluster '{name}'"
  #   kind delete cluster --name $name
  # } else {
  #   print $"⚠️  No cluster found with name '{name}'. Nothing to delete."
  # }
}

# Install FluxCD itself
export def "main install-flux" [] {
  print "🚀 Installing FluxCD..."
  
  # Check if flux CLI is installed
  let flux_check = (flux --version | complete)
  if $flux_check.exit_code != 0 {
    print "❌ Flux CLI not found. Installing via brew..."
    brew install fluxcd/tap/flux
  }
  
  # Install FluxCD in the cluster
  print "📦 Installing FluxCD components in cluster..."
  flux install
  
  # Wait for flux-system namespace and pods to be ready
  print "⏳ Waiting for FluxCD to be ready..."
  kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=flux -n flux-system --timeout=300s
  
  print "✅ FluxCD installation complete!"
}

# Check if FluxCD is installed and ready
def flux_ready [] {
  let flux_ns = (kubectl get namespace flux-system --ignore-not-found=true | complete)
  if $flux_ns.exit_code != 0 {
    return false
  }
  
  let flux_pods = (kubectl get pods -n flux-system --no-headers | complete)
  if $flux_pods.exit_code != 0 {
    return false
  }
  
  return true
}

# Install FluxCD dependencies using KCL
export def "main install-deps" [
  ...deps: string  # Dependencies to install: keda, prometheus, chaos, loki, external-secrets, crossplane
  --all(-a)        # Install all dependencies
] {
  let available_deps = ["keda", "prometheus", "chaos", "loki", "external-secrets", "crossplane"]
  
  let deps_to_install = if $all {
    $available_deps
  } else if ($deps | is-empty) {
    print "Available dependencies:"
    $available_deps | each { |dep| print $"  - ($dep)" }
    return
  } else {
    $deps
  }
  
  # Verify valid dependencies
  let invalid_deps = ($deps_to_install | where {|dep| $dep not-in $available_deps})
  if not ($invalid_deps | is-empty) {
    print $"Invalid dependencies: ($invalid_deps | str join ', ')"
    print $"Available: ($available_deps | str join ', ')"
    return
  }

  # Check if FluxCD is installed
  if not (flux_ready) {
    print "❌ FluxCD is not installed or not ready."
    print "Run 'main install-flux' first to install FluxCD."
    return
  }
  
  print "🔄 Installing FluxCD dependencies..."
  
  # Install repositories first
  install_helm_repositories
  
  # Install each dependency
  $deps_to_install | each { |dep|
    print $"📦 Installing ($dep)..."
    install_dependency $dep
  }
  
  print "✅ Dependencies installation initiated. Check with 'kubectl get hr -n flux-system'"
}

# Install all Helm repositories
def install_helm_repositories [] {
  print "📁 Installing Helm repositories..."
  let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S allRepositories | kubectl apply -f -)
  print $output
}

# Install specific dependency
def install_dependency [dep: string] {
  match $dep {
    "keda" => {
      let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S kedaRelease | kubectl apply -f -)
      print $output
    }
    "prometheus" => {
      # Create monitoring namespace
      kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
      let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S prometheusRelease | kubectl apply -f -)
      print $output
    }
    "chaos" => {
      # Create chaos namespace
      kubectl create namespace chaos-system --dry-run=client -o yaml | kubectl apply -f -
      let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S chaosRelease | kubectl apply -f -)
      print $output
    }
    "loki" => {
      let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S lokiRelease | kubectl apply -f -)
      print $output
    }
    "external-secrets" => {
      # Create external-secrets namespace
      kubectl create namespace external-secrets-system --dry-run=client -o yaml | kubectl apply -f -
      let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S externalSecretsRelease | kubectl apply -f -)
      print $output
    }
    "crossplane" => {
      # Create crossplane namespace
      kubectl create namespace crossplane-system --dry-run=client -o yaml | kubectl apply -f -
      let output = (kcl run ~/configs-files/scripts/kcl/flux-helm.k -S crossplaneRelease | kubectl apply -f -)
      print $output
    }
  }
}

# Check status of FluxCD dependencies
export def "main deps-status" [] {
  print "📊 FluxCD Dependencies Status:"
  print "\n🏪 Helm Repositories:"
  kubectl get helmrepository -n flux-system -o wide
  
  print "\n🚀 Helm Releases:"
  kubectl get helmrelease -n flux-system -o wide
  
  print "\n📈 Resource Status:"
  let namespaces = ["keda-system", "monitoring", "chaos-system", "external-secrets-system", "crossplane-system"]
  $namespaces | each { |ns|
    let exists = (kubectl get namespace $ns --ignore-not-found=true | complete)
    if $exists.exit_code == 0 {
      print $"\n📦 ($ns):"
      kubectl get pods -n $ns
    }
  }
}

# Remove FluxCD dependencies
export def "main remove-deps" [
  ...deps: string  # Dependencies to remove
  --all(-a)        # Remove all dependencies
] {
  let available_deps = ["keda", "prometheus", "chaos", "loki", "external-secrets", "crossplane"]
  
  let deps_to_remove = if $all {
    $available_deps
  } else if ($deps | is-empty) {
    print "Specify dependencies to remove or use --all"
    print $"Available: ($available_deps | str join ', ')"
    return
  } else {
    $deps
  }

  print "🗑️  Removing FluxCD dependencies..."
  
  $deps_to_remove | each { |dep|
    print $"❌ Removing ($dep)..."
    kubectl delete helmrelease $dep -n flux-system --ignore-not-found=true
  }
}

# Remove DAM dependencies
def "main remove-apps" [
  ...deps: string  # Dependencies to remove
  --all(-a)        # Remove all dependencies
] {
  let available_deps = ["keda", "prometheus", "chaos", "loki", "external-secrets", "crossplane"]

  let deps_to_remove = if $all {
    $available_deps
  } else if ($deps | is-empty) {
    print "Specify dependencies to remove or use --all"
    print $"Available: ($available_deps | str join ', ')"
    return
  } else {
    $deps
  }

  print "🗑️  Removing FluxCD dependencies..."

  $deps_to_remove | each { |dep|
    print $"❌ Removing ($dep)..."
    kubectl delete helmrelease $dep -n flux-system --ignore-not-found=true
  }
}