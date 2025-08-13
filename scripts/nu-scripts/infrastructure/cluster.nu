
# Enhanced kind cluster management commands

# Source modules
source crossplane.nu
source ../monitoring/tracer.nu
source ../monitoring/loki.nu
source ../gitops/argocd.nu

# Initialize tracing
trace-init

# Create a new kind cluster with optional configuration
def "cluster create" [
    name?: string = "kind"  # Name of the cluster (default: kind)
    --config(-c): string    # Path to cluster config file
    --image(-i): string     # Node image to use
    --crossplane(-x)        # Install Crossplane after cluster creation
    --providers(-p): list<string> = ["aws", "azure", "gcp"]  # Crossplane providers to install
    --loki(-l)              # Install Loki logging stack
    --argocd(-a)            # Install ArgoCD GitOps
    --full-stack(-f)        # Install all components (crossplane, loki, argocd)
] {
    print $"Creating kind cluster: ($name)"
    
    mut cmd = ["kind", "create", "cluster", "--name", $name]
    print $"Config: ($config)"
    if ($config != null) {
        $cmd = ($cmd | append ["--config", $config])
    }
    
    if ($image != null) {
        $cmd = ($cmd | append ["--image", $image])
    }
    
    #$cmd = ($cmd | append ["--wait", ($wait | into string)])
    
    trace-command $"cluster create ($name)" {
        try {
            if ($config != null) and ($image != null) {
                ^kind create cluster --name $name --config $config --image $image
            } else if ($config != null) {
                ^kind create cluster --name $name --config $config
            } else if ($image != null) {
                ^kind create cluster --name $name --image $image
            } else {
                ^kind create cluster --name $name
            }
            print $"✅ Cluster '($name)' created successfully"
            
            # Set kubectl context
            ^kubectl config use-context $"kind-($name)"
            print $"🔄 Switched to context: kind-($name)"
            
            # Show cluster info
           # ^kubectl cluster-info --context $"kind-($name)"
            
            # Determine what to install
            let install_crossplane = $crossplane or $full_stack
            let install_loki = $loki or $full_stack  
            let install_argocd = $argocd or $full_stack
            
            # Install Crossplane if requested
            if $install_crossplane {
                print "\n🚀 Installing Crossplane..."
                try {
                    trace-command "crossplane install" { crossplane install }
                    print "⏳ Installing Crossplane dependencies..."
                    trace-command "crossplane install-deps" { crossplane install-deps --providers $providers }
                    print "✅ Crossplane setup completed"
                } catch { |e|
                    print $"⚠️  Crossplane installation failed: ($e.msg)"
                    print "💡 You can install it manually later with: crossplane install"
                }
            }
            
            # Install Loki if requested
            if $install_loki {
                print "\n📊 Installing Loki logging stack..."
                try {
                    trace-command "loki install" { loki install }
                    print "⏳ Installing Promtail log collector..."
                    trace-command "loki install-promtail" { loki install-promtail }
                    print "✅ Loki setup completed"
                } catch { |e|
                    print $"⚠️  Loki installation failed: ($e.msg)"
                    print "💡 You can install it manually later with: loki install"
                }
            }
            
            # Install ArgoCD if requested
            if $install_argocd {
                print "\n🔄 Installing ArgoCD GitOps..."
                try {
                    trace-command "argocd install" { argocd install --insecure }
                    print "✅ ArgoCD setup completed"
                    print "🔐 Access ArgoCD UI with: argocd ui"
                    print "🔑 Get admin password with: argocd password"
                } catch { |e|
                    print $"⚠️  ArgoCD installation failed: ($e.msg)"
                    print "💡 You can install it manually later with: argocd install"
                }
            }
            
            ^kubectl cluster-info dump
        } catch { |e|
            print $"❌ Failed to create cluster: ($e.msg)"
            exit 1
        }
    }
}

# Delete a kind cluster
def "cluster delete" [
    name?: string = "kind"  # Name of the cluster to delete (default: kind)
    --all(-a)              # Delete all kind clusters
    --cleanup-crossplane(-x) # Clean up Crossplane before deleting cluster
] {
    # Clean up Crossplane if requested
    if $cleanup_crossplane {
        print "🧹 Cleaning up Crossplane..."
        trace-command "crossplane cleanup" {
            try {
                # Switch to the cluster context first
                if not $all {
                    ^kubectl config use-context $"kind-($name)"
                }
                crossplane uninstall --purge
                print "✅ Crossplane cleaned up"
            } catch { |e|
                print $"⚠️  Crossplane cleanup failed: ($e.msg)"
                print "💡 Continuing with cluster deletion..."
            }
        }
    }
    
    if $all {
        print "🗑️  Deleting all kind clusters..."
        trace-command "delete all clusters" {
            try {
                ^kind delete clusters --all
                print "✅ All clusters deleted successfully"
            } catch { |e|
                print $"❌ Failed to delete clusters: ($e.msg)"
                exit 1
            }
        }
    } else {
        print $"🗑️  Deleting kind cluster: ($name)"
        trace-command $"delete cluster ($name)" {
            try {
                ^kind delete cluster --name $name
                print $"✅ Cluster '($name)' deleted successfully"
            } catch { |e|
                print $"❌ Failed to delete cluster: ($e.msg)"
                exit 1
            }
        }
    }
}

# List all kind clusters
def "cluster list" [] {
    print "📋 Kind clusters:"
    try {
        kind get clusters | lines | each { |cluster|
            print $"  • ($cluster)"
        }
    } catch { |e|
        print $"❌ Failed to list clusters: ($e.msg)"
        exit 1
    }
}

# Get cluster status and info
def "cluster status" [
    name?: string = "kind"  # Name of the cluster (default: kind)
] {
    print $"📊 Status for cluster: ($name)"
    try {
        # Check if cluster exists
        let clusters = (kind get clusters | lines)
        if ($name not-in $clusters) {
            print $"❌ Cluster '($name)' not found"
            exit 1
        }
        
        # Get cluster info
        kubectl cluster-info --context $"kind-($name)"
        
        # Get nodes
        print "\n🖥️  Nodes:"
        kubectl get nodes --context $"kind-($name)" -o wide
        
        # Get pods in kube-system
        print "\n🏗️  System pods:"
        kubectl get pods -n kube-system --context $"kind-($name)"
        
    } catch { |e|
        print $"❌ Failed to get cluster status: ($e.msg)"
        exit 1
    }
}

# Load a docker image into the kind cluster
def "cluster load-image" [
    image: string           # Docker image to load
    name?: string = "kind"  # Name of the cluster (default: kind)
] {
    print $"📦 Loading image '($image)' into cluster '($name)'"
    try {
        kind load docker-image $image --name $name
        print $"✅ Image loaded successfully"
    } catch { |e|
        print $"❌ Failed to load image: ($e.msg)"
        exit 1
    }
}