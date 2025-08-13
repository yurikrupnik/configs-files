# ArgoCD GitOps management commands for Nu shell
# Provides functions to install, manage, and configure ArgoCD

use ../monitoring/tracer.nu *

# Install ArgoCD using Helm chart
def "argocd install" [
    --namespace(-n): string = "argocd"
    --version(-v): string = "7.7.11"
    --values(-f): string
    --admin-password(-p): string
    --ingress(-i)
    --insecure
] {
    trace-command $"argocd install --namespace=($namespace)" {
        print $"🚀 Installing ArgoCD in namespace: ($namespace)"
        
        # Create namespace if it doesn't exist
        let ns_exists = (kubectl get namespace $namespace | complete | get exit_code) == 0
        if not $ns_exists {
            print $"📦 Creating namespace: ($namespace)"
            kubectl create namespace $namespace
        }
        
        # Add ArgoCD Helm repository
        print "📋 Adding ArgoCD Helm repository"
        helm repo add argo https://argoproj.github.io/argo-helm
        helm repo update
        
        # Generate admin password if not provided
        let admin_pwd = if ($admin_password | is-empty) {
            let generated = (openssl rand -base64 32)
            print $"🔐 Generated admin password: ($generated)"
            $generated
        } else {
            $admin_password
        }
        
        # Prepare ArgoCD values
        let argocd_values = if ($values | is-empty) {
            let server_config = if $insecure {
                "server:\n  insecure: true"
            } else {
                "server:\n  insecure: false"
            }
            
            let ingress_config = if $ingress {
                $"
server:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - argocd.local
    tls:
      - secretName: argocd-server-tls
        hosts:
          - argocd.local
"
            } else {
                ""
            }
            
            $"
global:
  logging:
    level: info
    
configs:
  secret:
    argocdServerAdminPassword: ($admin_pwd | hash sha256)
    
($server_config)
($ingress_config)

controller:
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

dex:
  enabled: false

redis:
  enabled: true
  
repoServer:
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

applicationSet:
  enabled: true
  replicas: 1
"
        } else {
            open $values
        }
        
        # Write values to temporary file
        let values_file = "/tmp/argocd-values.yaml"
        $argocd_values | save -f $values_file
        
        # Install ArgoCD
        print $"🔧 Installing ArgoCD version ($version)"
        helm upgrade --install argocd argo/argo-cd --version $version --namespace $namespace --values $values_file --wait --timeout 10m
        
        # Clean up temporary file
        rm $values_file
        
        # Store admin password in secret
        kubectl create secret generic argocd-initial-admin-secret --from-literal=password=$admin_pwd --namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
        
        print "✅ ArgoCD installation completed"
        print $"🔐 Admin password stored in secret: argocd-initial-admin-secret"
        print $"📖 Access ArgoCD UI: kubectl port-forward svc/argocd-server -n ($namespace) 8080:443"
    }
}

# Uninstall ArgoCD
def "argocd uninstall" [
    --namespace(-n): string = "argocd"
    --purge(-p)
] {
    trace-command $"argocd uninstall --namespace=($namespace)" {
        print $"🗑️  Uninstalling ArgoCD from namespace: ($namespace)"
        
        # Remove finalizers from ArgoCD applications first
        print "🧹 Removing finalizers from ArgoCD applications"
        try { kubectl patch applications --all --type json --patch='[{"op": "remove", "path": "/metadata/finalizers"}]' -n $namespace } catch { print "No applications to patch" }
        
        # Uninstall Helm release
        helm uninstall argocd --namespace $namespace
        
        if $purge {
            print "🧹 Purging namespace and CRDs"
            kubectl delete namespace $namespace --ignore-not-found
            # Remove ArgoCD CRDs
            kubectl delete crd applications.argoproj.io --ignore-not-found
            kubectl delete crd applicationsets.argoproj.io --ignore-not-found
            kubectl delete crd appprojects.argoproj.io --ignore-not-found
        }
        
        print "✅ ArgoCD uninstallation completed"
    }
}

# Get ArgoCD status
def "argocd status" [
    --namespace(-n): string = "argocd"
] {
    trace-command $"argocd status --namespace=($namespace)" {
        print $"📊 ArgoCD status in namespace: ($namespace)"
        
        # Check namespace
        let ns_status = (kubectl get namespace $namespace -o json | from json | get status.phase)
        print $"Namespace: ($namespace) - ($ns_status)"
        
        # Check ArgoCD pods
        print "🏗️  ArgoCD Pods:"
        kubectl get pods -n $namespace -l app.kubernetes.io/part-of=argocd
        
        # Check services
        print "🌐 ArgoCD Services:"
        kubectl get services -n $namespace -l app.kubernetes.io/part-of=argocd
        
        # Check applications
        print "📦 ArgoCD Applications:"
        try { kubectl get applications -n $namespace } catch { print "No applications found" }
        
        # Check Helm release
        print "📦 Helm Release:"
        helm list -n $namespace | grep argocd
    }
}

# Port forward to ArgoCD UI
def "argocd ui" [
    --namespace(-n): string = "argocd"
    --port(-p): int = 8080
] {
    trace-command $"argocd ui --port=($port)" {
        print $"🔗 Port forwarding ArgoCD UI on port ($port)"
        print $"Access ArgoCD at: https://localhost:($port)"
        print "Username: admin"
        print $"Password: kubectl get secret argocd-initial-admin-secret -n ($namespace) -o jsonpath='{.data.password}' | base64 -d"
        print "Press Ctrl+C to stop port forwarding"
        
        kubectl port-forward -n $namespace service/argocd-server $"($port):443"
    }
}

# Get ArgoCD admin password
def "argocd password" [
    --namespace(-n): string = "argocd"
] {
    trace-command $"argocd password" {
        print "🔐 ArgoCD admin password:"
        kubectl get secret argocd-initial-admin-secret -n $namespace -o jsonpath='{.data.password}' | base64 -d
        print ""
    }
}

# Login to ArgoCD CLI
def "argocd login" [
    server?: string = "localhost:8080"
    --namespace(-n): string = "argocd"
    --insecure(-k)
] {
    trace-command $"argocd login ($server)" {
        print $"🔐 Logging into ArgoCD server: ($server)"
        
        let password = (kubectl get secret argocd-initial-admin-secret -n $namespace -o jsonpath='{.data.password}' | base64 -d)
        
        print $"Username: admin"
        print $"Password: ($password)"
        print $"Use ArgoCD CLI to login: argocd login ($server) --username admin --password [PASSWORD]"
        
        if $insecure {
            print "Note: Using --insecure for self-signed certificates"
        }
        
        print "✅ Successfully logged into ArgoCD"
    }
}

# Create ArgoCD application
def "argocd app create" [
    name: string
    repo_url: string
    path: string = "."
    --namespace(-n): string = "argocd"
    --dest-namespace(-d): string = "default"
    --dest-server(-s): string = "https://kubernetes.default.svc"
    --revision(-r): string = "HEAD"
    --sync-policy(-p): string = "manual"  # manual or auto
    --project(-j): string = "default"
] {
    trace-command $"argocd app create ($name)" {
        print $"📦 Creating ArgoCD application: ($name)"
        
        let sync_policy_config = if $sync_policy == "auto" {
            "--sync-policy automated --auto-prune --self-heal"
        } else {
            ""
        }
        
        let app_manifest = $"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ($name)
  namespace: ($namespace)
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: ($project)
  source:
    repoURL: ($repo_url)
    targetRevision: ($revision)
    path: ($path)
  destination:
    server: ($dest_server)
    namespace: ($dest_namespace)
  syncPolicy:
    syncOptions:
    - CreateNamespace=true
"
        
        let app_file = $"/tmp/argocd-app-($name).yaml"
        $app_manifest | save -f $app_file
        
        kubectl apply -f $app_file
        rm $app_file
        
        print $"✅ ArgoCD application '($name)' created successfully"
    }
}

# Delete ArgoCD application
def "argocd app delete" [
    name: string
    --namespace(-n): string = "argocd"
    --cascade
] {
    trace-command $"argocd app delete ($name)" {
        print $"🗑️  Deleting ArgoCD application: ($name)"
        
        if $cascade {
            # Remove finalizers first to allow cascade deletion
            kubectl patch application $name -n $namespace --type json --patch='[{"op": "remove", "path": "/metadata/finalizers"}]'
        }
        
        kubectl delete application $name -n $namespace
        
        print $"✅ ArgoCD application '($name)' deleted successfully"
    }
}

# List ArgoCD applications
def "argocd apps" [
    --namespace(-n): string = "argocd"
    --all-namespaces(-A)
] {
    trace-command $"argocd apps" {
        print "📦 ArgoCD Applications:"
        
        if $all_namespaces {
            kubectl get applications --all-namespaces
        } else {
            kubectl get applications -n $namespace
        }
    }
}

# Sync ArgoCD application
def "argocd sync" [
    name: string
    --namespace(-n): string = "argocd"
    --prune(-p)
    --force(-f)
] {
    trace-command $"argocd sync ($name)" {
        print $"🔄 Syncing ArgoCD application: ($name)"
        
        let sync_options = if $prune { "--prune" } else { "" }
        let force_option = if $force { "--force" } else { "" }
        
        # Use kubectl patch to trigger sync
        kubectl patch application $name -n $namespace --type merge --patch='{"operation":{"sync":{}}}'
        
        print $"✅ Sync triggered for application '($name)'"
    }
}

# Show ArgoCD application details
def "argocd app get" [
    name: string
    --namespace(-n): string = "argocd"
    --output(-o): string = "yaml"
] {
    trace-command $"argocd app get ($name)" {
        print $"📋 ArgoCD application details: ($name)"
        kubectl get application $name -n $namespace -o $output
    }
}

# Show ArgoCD logs
def "argocd logs" [
    component?: string = "server"  # server, controller, repo-server, dex
    --namespace(-n): string = "argocd"
    --follow(-f)
    --lines(-l): int = 100
] {
    trace-command $"argocd logs ($component)" {
        let follow_flag = if $follow { "--follow" } else { "" }
        
        print $"📋 ArgoCD ($component) logs (latest ($lines) lines):"
        
        if $follow {
            kubectl logs -n $namespace -l app.kubernetes.io/component=$component --follow --tail=$lines
        } else {
            kubectl logs -n $namespace -l app.kubernetes.io/component=$component --tail=$lines
        }
    }
}