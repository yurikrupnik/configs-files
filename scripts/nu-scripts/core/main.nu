# Main entry point for Nu scripts
# This script loads all the other Nu modules and provides easy access to all functions

# Source all the Nu modules
source ../monitoring/tracer.nu
source ../infrastructure/crossplane.nu
source ../monitoring/loki.nu
source ../gitops/argocd.nu
source ../infrastructure/cluster.nu
source ../config-management/kcl.nu

# Print available commands
def "help commands" [] {
    print "🔧 Available Nu Shell Commands:"
    print "================================"
    print ""
    print "📊 CLUSTER MANAGEMENT:"
    print "  cluster create [name] [--crossplane] [--loki] [--argocd] [--full-stack]"
    print "  cluster delete [name] [--all] [--cleanup-crossplane]"
    print "  cluster list"
    print "  cluster status [name]"
    print "  cluster load-image [image] [name]"
    print ""
    print "🔧 KCL CONFIGURATION MANAGEMENT:"
    print "  kcl install                                    # Install KCL"
    print "  kcl validate [--path]                         # Validate configurations"
    print "  kcl list-envs [--path]                        # List available environments"
    print "  kcl create-cluster [environment] [--dry-run]  # Create cluster from KCL config"
    print "  kcl infrastructure-summary [--path]           # Show infrastructure overview"
    print "  kcl generate-argocd-apps [env] [--output]     # Generate ArgoCD applications"
    print "  kcl help                                       # Show detailed KCL help"
    print ""
    print "🚀 CROSSPLANE MANAGEMENT:"
    print "  crossplane install [--namespace] [--version]"
    print "  crossplane install-deps [--providers [list]]"
    print "  crossplane status [--namespace]"
    print "  crossplane uninstall [--namespace] [--purge]"
    print "  crossplane packages [--search]"
    print "  crossplane create-config [provider]"
    print ""
    print "📊 LOKI LOGGING:"
    print "  loki install [--namespace] [--version] [--values]"
    print "  loki uninstall [--namespace] [--purge]"
    print "  loki status [--namespace]"
    print "  loki port-forward [--port]"
    print "  loki query [query] [--limit] [--since]"
    print "  loki install-promtail [--loki-url]"
    print ""
    print "🔄 ARGOCD GITOPS:"
    print "  argocd install [--namespace] [--admin-password] [--insecure]"
    print "  argocd uninstall [--namespace] [--purge]"
    print "  argocd status [--namespace]"
    print "  argocd ui [--port]"
    print "  argocd password [--namespace]"
    print "  argocd app create [name] [repo_url] [path]"
    print "  argocd apps [--all-namespaces]"
    print ""
    print "🔍 TRACING:"
    print "  trace-init"
    print "  trace-log [command] [status] [--data] [--duration]"
    print "  trace-get"
    print "  trace-clear"
    print "  trace-monitor"
    print ""
    print "💡 EXAMPLES:"
    print "  cluster create dev --full-stack"
    print "  cluster create prod --crossplane --loki --providers [kubernetes aws]"
    print "  loki install --namespace monitoring"
    print "  argocd install --insecure"
    print "  argocd app create my-app https://github.com/user/repo.git manifests/"
    print "  kcl create-cluster local --dry-run           # Preview cluster creation"
    print "  kcl infrastructure-summary                   # Show infrastructure overview"
    print ""
    print "📖 For more help: help commands or kcl help"
}

# Initialize tracing on load
trace-init

print "🎉 Nu Scripts Loaded Successfully!"
print "📖 Run 'help commands' to see all available commands"
