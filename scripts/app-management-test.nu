#!/usr/bin/env nu

def "main app help" [] {
    print "🚀 Application Management Commands:"
    print ""
    print "🔧 Deployment & Lifecycle:"
    print "  deploy <name>          - Deploy application (supports --gitops=argocd|flux|none)"
    print "  upgrade <name>         - Upgrade existing application"
    print "  rollback <name>        - Rollback to previous version"
    print "  delete <name>          - Remove application"
    print "  scale <name> <replicas> - Scale application"
    print "  restart <name>         - Restart application"
    print ""
    print "🔄 GitOps Operations:"
    print "  sync <name>            - Sync application via GitOps"
    print "  diff <name>            - Show configuration diff"
    print "  gitops-status [name]   - Show GitOps status"
    print "  gitops-ui              - Open GitOps UI"
    print "  gitops-logs <name>     - Show GitOps controller logs"
    print "  create-repo <name>     - Add repository to GitOps"
    print ""
    print "📊 Monitoring & Debugging:"
    print "  status [name]          - Show application status"
    print "  logs <name>            - Show application logs"
    print "  describe <name>        - Detailed resource description"
    print "  events [name]          - Show application events"
    print "  exec <name> <command>  - Execute command in pod"
    print ""
    print "🌐 Networking:"
    print "  port-forward <name> <port> - Forward port to local machine"
    print ""
    print "🔧 Development:"
    print "  validate <name>        - Validate Helm chart"
    print "  template <name>        - Generate Kubernetes manifests"
    print "  history <name>         - Show release history"
    print ""
    print "💾 Backup & Restore:"
    print "  backup <name>          - Backup application configuration"
    print "  restore <file>         - Restore from backup"
    print ""
    print "📋 Utility:"
    print "  list                   - List all applications"
    print "  help                   - Show this help"
    print ""
    print "⚙️  Common Options:"
    print "  --namespace <name>     - Target namespace (default: default)"
    print "  --follow               - Follow logs/events continuously"
    print "  --watch                - Watch resource changes"
    print "  --gitops <tool>        - GitOps tool (argocd|flux|none, default: argocd)"
    print "  --repo-url <url>       - Git repository URL"
    print "  --sync-policy <policy> - Sync policy (automated|manual, default: automated)"
    print "  --force                - Skip confirmation prompts"
    print ""
    print "🚀 GitOps Quick Start:"
    print "  # Deploy with ArgoCD (recommended)"
    print "  nu scripts/app-management.nu app deploy myapp --gitops argocd"
    print "  "
    print "  # Deploy with Flux"
    print "  nu scripts/app-management.nu app deploy myapp --gitops flux"
    print "  "
    print "  # Traditional Helm deployment"
    print "  nu scripts/app-management.nu app deploy myapp --gitops none"
}

def "main app deploy" [
    name: string,
    --namespace: string = "default",
    --gitops: string = "argocd"
] {
    print $"🚀 Deploying application '($name)' to namespace '($namespace)' via ($gitops)"
    
    match $gitops {
        "argocd" => {
            print "📝 Creating ArgoCD Application manifest..."
            let app_manifest = $"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ($name)
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/example/charts
    path: charts/($name)
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: ($namespace)
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
"
            print $app_manifest
            print "✅ ArgoCD Application would be created"
            print "🌐 View in ArgoCD UI: kubectl port-forward -n argocd svc/argocd-server 8080:443"
        }
        "flux" => {
            print "📝 Creating Flux HelmRelease manifest..."
            let helm_release = $"
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ($name)
  namespace: ($namespace)
spec:
  chart:
    spec:
      chart: charts/($name)
      sourceRef:
        kind: GitRepository
        name: ($name)-source
"
            print $helm_release
            print "✅ Flux HelmRelease would be created"
        }
        "none" => {
            print "📦 Using direct Helm deployment..."
            print $"helm install ($name) ./charts/($name) --namespace ($namespace) --create-namespace"
            print "✅ Helm deployment would be executed"
        }
        _ => {
            error make { msg: $"Unsupported GitOps tool: ($gitops)" }
        }
    }
}

def "main app gitops-ui" [
    --gitops: string = "argocd",
    --port: int = 8080
] {
    match $gitops {
        "argocd" => {
            print $"🌐 Opening ArgoCD UI on port ($port)..."
            print "Default credentials: admin / (get password with: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
            print $"Command: kubectl port-forward -n argocd svc/argocd-server ($port):443"
        }
        "flux" => {
            print "🌐 Flux doesn't have a native UI. Consider installing Weave GitOps:"
            print "  helm repo add weaveworks https://helm.gitops.weave.works"
            print "  helm install weave-gitops weaveworks/weave-gitops --namespace flux-system"
            print $"  kubectl port-forward -n flux-system svc/weave-gitops ($port):9001"
        }
        _ => {
            error make { msg: $"Unsupported GitOps tool: ($gitops)" }
        }
    }
}

def "main app sync" [
    name: string,
    --gitops: string = "argocd"
] {
    print $"🔄 Syncing application '($name)' via ($gitops)..."
    
    match $gitops {
        "argocd" => {
            print $"Command: argocd app sync ($name)"
            print "✅ ArgoCD sync would be triggered"
        }
        "flux" => {
            print $"Command: flux reconcile helmrelease ($name)"
            print "✅ Flux reconciliation would be triggered"
        }
        _ => {
            error make { msg: $"Unsupported GitOps tool: ($gitops)" }
        }
    }
}