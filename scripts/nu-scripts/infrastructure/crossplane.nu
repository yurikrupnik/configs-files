# Crossplane management commands for Kubernetes

# Install Crossplane core components
def "crossplane install" [
    --namespace(-n): string = "crossplane-system"  # Namespace to install Crossplane
    --version(-v): string = "stable"               # Crossplane version (stable, latest, or specific version)
    --wait(-w): duration = 300sec                  # Wait timeout for installation
] {
    print $"🚀 Installing Crossplane in namespace: ($namespace)"
    
    # Create namespace if it doesn't exist
    try {
        kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
        print $"📦 Namespace '($namespace)' ready"
    } catch { |e|
        print $"⚠️  Namespace issue - may already exist: ($e.msg)"
    }
    
    # Add Crossplane Helm repository
    try {
        print "📋 Adding Crossplane Helm repository..."
        helm repo add crossplane-stable https://charts.crossplane.io/stable
        helm repo update
        print "✅ Helm repository added and updated"
    } catch { |e|
        print $"❌ Failed to add Helm repository: ($e.msg)"
        exit 1
    }
    
    # Install Crossplane
    try {
        print $"⏳ Installing Crossplane version: ($version)"
        
        mut helm_cmd = ["helm", "install", "crossplane", "crossplane-stable/crossplane"]
        $helm_cmd = ($helm_cmd | append ["--namespace", $namespace])
        $helm_cmd = ($helm_cmd | append ["--create-namespace"])
        $helm_cmd = ($helm_cmd | append ["--wait"])
        $helm_cmd = ($helm_cmd | append ["--timeout", "5m"])
        
        if $version != "stable" {
            $helm_cmd = ($helm_cmd | append ["--version", $version])
        }
        
        run-external ...$helm_cmd
        print "✅ Crossplane core installed successfully"
        
        # Wait for Crossplane pods to be ready
        print "⏳ Waiting for Crossplane pods to be ready..."
        kubectl wait --for=condition=ready pod -l app=crossplane --namespace $namespace --timeout=300s
        
        print "🎉 Crossplane installation completed!"
        
    } catch { |e|
        print $"❌ Failed to install Crossplane: ($e.msg)"
        exit 1
    }
}

# Install Crossplane dependencies and common providers
def "crossplane install-deps" [
    --providers(-p): list<string> = ["aws", "azure", "gcp"]  # Providers to install
    --namespace(-n): string = "crossplane-system"           # Namespace where Crossplane is installed
] {
    print "🔧 Installing Crossplane dependencies and providers"
    
    # Install Crossplane CLI if not present
    try {
        let has_crossplane_cli = (which crossplane | length) > 0
        if not $has_crossplane_cli {
            print "📥 Installing Crossplane CLI..."
            
            # Download and install crossplane CLI
            let os = (^uname -s | str downcase)
            let arch = if (^uname -m) == "x86_64" { "amd64" } else { "arm64" }
            let version = "v1.14.5"  # Latest stable version
            
            let download_url = $"https://releases.crossplane.io/stable/($version)/bin/($os)_($arch)/crank"
            
            curl -sL $download_url -o /tmp/crossplane
            chmod +x /tmp/crossplane
            sudo mv /tmp/crossplane /usr/local/bin/crossplane
            
            print "✅ Crossplane CLI installed"
        } else {
            print "✅ Crossplane CLI already available"
        }
    } catch { |e|
        print $"⚠️  Could not install Crossplane CLI: ($e.msg)"
    }
    
    # Install common providers
    for $provider in $providers {
        try {
            print $"📦 Installing ($provider) provider..."
            
            match $provider {
                "aws" => {
                    'apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-aws:v0.44.1' | ^kubectl apply -f -
                }
                "azure" => {
                    'apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-azure:v0.19.1' | ^kubectl apply -f -
                }
                "gcp" => {
                    'apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-gcp
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-gcp:v0.22.0' | ^kubectl apply -f -
                }
                "kubernetes" => {
                    'apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.11.4' | ^kubectl apply -f -
                }
                _ => {
                    print $"⚠️  Unknown provider: ($provider)"
                }
            }
            
            # Wait for provider to be installed
            print $"⏳ Waiting for ($provider) provider to be ready..."
            kubectl wait --for=condition=installed provider $"provider-($provider)" --timeout=300s
            
            print $"✅ ($provider) provider installed successfully"
            
        } catch { |e|
            print $"❌ Failed to install ($provider) provider: ($e.msg)"
        }
    }
    
    print "🎉 Dependencies installation completed!"
}

# Check Crossplane status
def "crossplane status" [
    --namespace(-n): string = "crossplane-system"  # Namespace where Crossplane is installed
] {
    print $"📊 Crossplane status in namespace: ($namespace)"
    
    try {
        # Check if namespace exists
        kubectl get namespace $namespace
        
        # Get Crossplane pods
        print "\n🏗️  Crossplane Pods:"
        kubectl get pods -n $namespace -l app=crossplane
        
        # Get installed providers
        print "\n📦 Installed Providers:"
        kubectl get providers
        
        # Get provider revisions
        print "\n🔄 Provider Revisions:"
        kubectl get providerrevisions
        
        # Get Crossplane version
        print "\n📋 Crossplane Version:"
        kubectl get deployment crossplane -n $namespace -o jsonpath='{.spec.template.spec.containers[0].image}'
        
    } catch { |e|
        print $"❌ Failed to get Crossplane status: ($e.msg)"
        exit 1
    }
}

# Uninstall Crossplane
def "crossplane uninstall" [
    --namespace(-n): string = "crossplane-system"  # Namespace where Crossplane is installed
    --purge(-p)                                    # Also remove CRDs and all resources
] {
    print $"🗑️  Uninstalling Crossplane from namespace: ($namespace)"
    
    try {
        # Remove providers first
        print "🧹 Removing providers..."
        kubectl delete providers --all
        
        # Uninstall Crossplane via Helm
        helm uninstall crossplane --namespace $namespace
        
        if $purge {
            print "🧹 Purging CRDs and resources..."
            
            # Remove Crossplane CRDs
            kubectl get crd | grep crossplane.io | awk '{print $1}' | xargs kubectl delete crd
            
            # Remove namespace
            kubectl delete namespace $namespace
            
            print "✅ Crossplane completely purged"
        } else {
            print "✅ Crossplane uninstalled (CRDs preserved)"
        }
        
    } catch { |e|
        print $"❌ Failed to uninstall Crossplane: ($e.msg)"
        exit 1
    }
}

# List available Crossplane packages
def "crossplane packages" [
    --search(-s): string  # Search term for packages
] {
    print "📋 Available Crossplane packages:"
    
    try {
        if ($search != null) {
            print $"🔍 Searching for: ($search)"
            crossplane xpkg search $search
        } else {
            print "Use --search to find specific packages"
            print "Popular providers:"
            print "  • AWS: xpkg.upbound.io/crossplane-contrib/provider-aws"
            print "  • Azure: xpkg.upbound.io/crossplane-contrib/provider-azure"
            print "  • GCP: xpkg.upbound.io/crossplane-contrib/provider-gcp"
            print "  • Kubernetes: xpkg.upbound.io/crossplane-contrib/provider-kubernetes"
        }
    } catch { |e|
        print $"❌ Failed to list packages: ($e.msg)"
        print "💡 Make sure Crossplane CLI is installed"
    }
}

# Create Crossplane configuration example
def "crossplane create-config" [
    provider: string  # Provider name (aws, azure, gcp, kubernetes)
] {
    print $"📝 Creating configuration example for ($provider) provider"
    
    let config_dir = "crossplane-configs"
    mkdir $config_dir
    
    match $provider {
        "aws" => {
            let config_content = 'apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: aws-configuration
spec:
  package: xpkg.upbound.io/crossplane-contrib/configuration-aws-network:v0.7.0
---
apiVersion: aws.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-secret
      key: creds'
            
            $config_content | save $"($config_dir)/aws-config.yaml"
            print $"✅ AWS configuration saved to ($config_dir)/aws-config.yaml"
        }
        "azure" => {
            let config_content = 'apiVersion: azure.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: azure-secret
      key: creds'
            
            $config_content | save $"($config_dir)/azure-config.yaml"
            print $"✅ Azure configuration saved to ($config_dir)/azure-config.yaml"
        }
        "gcp" => {
            let config_content = 'apiVersion: gcp.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  projectID: your-project-id
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: gcp-secret
      key: creds'
            
            $config_content | save $"($config_dir)/gcp-config.yaml"
            print $"✅ GCP configuration saved to ($config_dir)/gcp-config.yaml"
        }
        _ => {
            print $"❌ Unknown provider: ($provider)"
            print "Available providers: aws, azure, gcp, kubernetes"
        }
    }
}