#!/usr/bin/env nu

def "main app deploy" [
    name: string,
    --namespace: string = "default",
    --provider: string = "local",
    --values-file: string = "",
    --chart-path: string = ".",
    --gitops: string = "argocd",
    --repo-url: string = "",
    --target-revision: string = "HEAD",
    --sync-policy: string = "automated"
] {
    print $"🚀 Deploying application '($name)' to ($provider)..."
    
    load-secrets
    
    let chart_dir = if ($chart_path == ".") {
        $"./charts/($name)"
    } else {
        $chart_path
    }
    
    if not ($chart_dir | path exists) {
        error make { msg: $"Chart directory not found: ($chart_dir)" }
    }
    
    if ($values_file != "") and not ($values_file | path exists) {
        error make { msg: $"Values file not found: ($values_file)" }
    }
    
    let values_arg = if ($values_file != "") {
        ["--values" $values_file]
    } else {
        []
    }
    
    if $gitops == "none" {
        helm install $name $chart_dir --namespace $namespace --create-namespace ...$values_arg
        print "✅ Application deployed successfully via Helm"
    } else {
        deploy_with_gitops $name $namespace $chart_dir $gitops $target_revision $sync_policy $values_file $repo_url
    }
    
    print $"📋 Check status: nu scripts/app-management.nu app status ($name) --namespace ($namespace)"
}

def "main app status" [
    name?: string,
    --namespace: string = "default",
    --watch
] {
    let watch_arg = if $watch { "--watch" } else { "" }
    
    if ($name | is-empty) {
        print $"📊 All resources in namespace '($namespace)':"
        kubectl get all --namespace $namespace $watch_arg
    } else {
        print $"📊 Status for application '($name)' in namespace '($namespace)':"
        kubectl get all -l app=$name --namespace $namespace $watch_arg
        
        print "\n🔍 Detailed pod information:"
        kubectl describe pods -l app=$name --namespace $namespace
    }
}

def "main app logs" [
    name: string,
    --namespace: string = "default",
    --follow,
    --tail: int = 100,
    --container: string = ""
] {
    print $"📝 Logs for application '($name)' in namespace '($namespace)':"
    
    let follow_flag = if $follow { "-f" } else { "" }
    let tail_flag = $"--tail=($tail)"
    let container_flag = if ($container != "") { $"-c ($container)" } else { "" }
    
    kubectl logs -l app=$name --namespace $namespace $follow_flag $tail_flag $container_flag
}

def "main app scale" [
    name: string,
    replicas: int,
    --namespace: string = "default"
] {
    print $"⚖️  Scaling application '($name)' to ($replicas) replicas..."
    
    kubectl scale deployment $name --replicas=$replicas --namespace $namespace
    
    print "⏳ Waiting for rollout to complete..."
    kubectl rollout status deployment/$name --namespace $namespace
    
    print "✅ Scaling completed"
}

def "main app restart" [
    name: string,
    --namespace: string = "default"
] {
    print $"🔄 Restarting application '($name)'..."
    
    kubectl rollout restart deployment/$name --namespace $namespace
    kubectl rollout status deployment/$name --namespace $namespace
    
    print "✅ Application restarted"
}

def "main app delete" [
    name: string,
    --namespace: string = "default",
    --force
] {
    if not $force {
        let confirm = (input $"Are you sure you want to delete application '($name)' from namespace '($namespace)'? (y/N): ")
        if $confirm != "y" and $confirm != "Y" {
            print "❌ Operation cancelled"
            return
        }
    }
    
    print $"🗑️  Deleting application '($name)'..."
    
    helm uninstall $name --namespace $namespace
    
    print "✅ Application deleted"
}

def "main app upgrade" [
    name: string,
    --namespace: string = "default",
    --values-file: string = "",
    --chart-path: string = ".",
    --version: string = ""
] {
    print $"⬆️  Upgrading application '($name)'..."
    
    let chart_dir = if ($chart_path == ".") {
        $"./charts/($name)"
    } else {
        $chart_path
    }
    
    let values_arg = if ($values_file != "") {
        ["--values" $values_file]
    } else {
        []
    }
    
    let version_arg = if ($version != "") {
        ["--version" $version]
    } else {
        []
    }
    
    helm upgrade $name $chart_dir --namespace $namespace ...$values_arg ...$version_arg
    
    kubectl rollout status deployment/$name --namespace $namespace
    
    print "✅ Application upgraded successfully"
}

def "main app rollback" [
    name: string,
    --namespace: string = "default",
    --revision: int = 0
] {
    print $"⏪ Rolling back application '($name)'..."
    
    let revision_arg = if ($revision != 0) {
        [$revision]
    } else {
        []
    }
    
    helm rollback $name ...$revision_arg --namespace $namespace
    
    kubectl rollout status deployment/$name --namespace $namespace
    
    print "✅ Application rolled back successfully"
}

def "main app history" [
    name: string,
    --namespace: string = "default"
] {
    print $"📜 Release history for application '($name)':"
    helm history $name --namespace $namespace
}

def "main app port-forward" [
    name: string,
    port: string,
    --namespace: string = "default",
    --local-port: string = ""
] {
    let local = if ($local_port != "") { $local_port } else { $port }
    
    print $"🌐 Port forwarding ($local):($port) for application '($name)'..."
    print "Press Ctrl+C to stop"
    
    kubectl port-forward -n $namespace svc/$name $"($local):($port)"
}

def "main app exec" [
    name: string,
    command: string,
    --namespace: string = "default",
    --container: string = "",
    --interactive
] {
    print $"💻 Executing command in application '($name)'..."
    
    let pod = (kubectl get pods -l app=$name --namespace $namespace -o jsonpath="{.items[0].metadata.name}")
    
    if ($pod | is-empty) {
        error make { msg: $"No pods found for application '($name)'" }
    }
    
    let container_flag = if ($container != "") { $"-c ($container)" } else { "" }
    let interactive_flags = if $interactive { "-it" } else { "" }
    
    kubectl exec $interactive_flags $pod --namespace $namespace $container_flag -- $command
}

def "main app describe" [
    name: string,
    --namespace: string = "default"
] {
    print $"📋 Description for application '($name)':"
    
    print "\n🏗️  Deployment:"
    kubectl describe deployment $name --namespace $namespace
    
    print "\n📦 Service:"
    kubectl describe service $name --namespace $namespace
    
    print "\n🔧 Pods:"
    kubectl describe pods -l app=$name --namespace $namespace
}

def "main app events" [
    name?: string,
    --namespace: string = "default",
    --watch
] {
    let watch_arg = if $watch { "--watch" } else { "" }
    
    if ($name | is-empty) {
        print $"📅 Events in namespace '($namespace)':"
        kubectl get events --namespace $namespace --sort-by=.metadata.creationTimestamp $watch_arg
    } else {
        print $"📅 Events for application '($name)':"
        kubectl get events --namespace $namespace --field-selector involvedObject.name=$name --sort-by=.metadata.creationTimestamp $watch_arg
    }
}

def "main app list" [
    --namespace: string = "default",
    --all-namespaces
] {
    let namespace_arg = if $all_namespaces { "--all-namespaces" } else { $"--namespace ($namespace)" }
    
    print "📋 Installed applications:"
    helm list $namespace_arg
    
    print "\n🚀 Deployments:"
    kubectl get deployments $namespace_arg
}

def "main app validate" [
    name: string,
    --namespace: string = "default",
    --chart-path: string = "."
] {
    print $"✅ Validating application '($name)'..."
    
    let chart_dir = if ($chart_path == ".") {
        $"./charts/($name)"
    } else {
        $chart_path
    }
    
    print "🔍 Linting Helm chart..."
    helm lint $chart_dir
    
    print "\n🧪 Dry run installation..."
    helm install $name $chart_dir --namespace $namespace --dry-run --debug
    
    print "\n✅ Validation completed"
}

def "main app template" [
    name: string,
    --namespace: string = "default",
    --chart-path: string = ".",
    --values-file: string = "",
    --output-file: string = ""
] {
    print $"📝 Generating templates for application '($name)'..."
    
    let chart_dir = if ($chart_path == ".") {
        $"./charts/($name)"
    } else {
        $chart_path
    }
    
    let values_arg = if ($values_file != "") {
        ["--values" $values_file]
    } else {
        []
    }
    
    let output = (helm template $name $chart_dir --namespace $namespace ...$values_arg)
    
    if ($output_file != "") {
        $output | save $output_file
        print $"✅ Templates saved to: ($output_file)"
    } else {
        print $output
    }
}

def "main app backup" [
    name: string,
    output_path: string = "./backups",
    --namespace: string = "default",
    --include-data
] {
    print $"💾 Backing up application '($name)'..."
    
    mkdir $output_path
    
    let backup_file = $"($output_path)/($name)-backup-(date now | format date '%Y%m%d-%H%M%S').yaml"
    
    print "📦 Exporting Helm release..."
    helm get all $name --namespace $namespace > $backup_file
    
    if $include_data {
        print "💾 Backing up persistent data..."
        let pvs = (kubectl get pvc -l app=$name --namespace $namespace -o jsonpath="{.items[*].spec.volumeName}")
        
        for pv in ($pvs | split row " ") {
            if not ($pv | is-empty) {
                print $"📁 Backing up volume: ($pv)"
                # Note: Actual backup would depend on storage provider
                kubectl describe pv $pv >> $backup_file
            }
        }
    }
    
    print $"✅ Backup completed: ($backup_file)"
}

def "main app restore" [
    backup_file: string,
    --namespace: string = "default",
    --name: string = ""
] {
    print $"📥 Restoring application from backup: ($backup_file)"
    
    if not ($backup_file | path exists) {
        error make { msg: $"Backup file not found: ($backup_file)" }
    }
    
    kubectl apply -f $backup_file --namespace $namespace
    
    print "✅ Application restored successfully"
}

def deploy_with_gitops [
    name: string,
    namespace: string,
    chart_dir: string,
    gitops: string,
    target_revision: string,
    sync_policy: string,
    values_file: string = "",
    repo_url: string = ""
] {
    print $"🔄 Deploying application '($name)' via ($gitops)..."
    
    let repo_url_final = if ($repo_url == "") {
        let current_repo = (git remote get-url origin | complete)
        if $current_repo.exit_code != 0 {
            error make { msg: "No git repository found and --repo-url not specified" }
        }
        $current_repo.stdout
    } else {
        $repo_url
    }
    
    match $gitops {
        "argocd" => { deploy_argocd_app $name $namespace $chart_dir $repo_url_final $target_revision $sync_policy $values_file }
        "flux" => { deploy_flux_app $name $namespace $chart_dir $repo_url_final $target_revision $values_file }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def deploy_argocd_app [
    name: string,
    namespace: string,
    chart_dir: string,
    repo_url: string,
    target_revision: string,
    sync_policy: string,
    values_file: string = ""
] {
    let values_files = if ($values_file != "") {
        $"    - ($values_file)"
    } else {
        ""
    }
    
    let auto_sync = if $sync_policy == "automated" {
        $"  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
    - CreateNamespace=true
    - PrunePropagationPolicy=foreground
    - PruneLast=true"
    } else {
        ""
    }
    
    let app_manifest = $"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ($name)
  namespace: argocd
  labels:
    app.kubernetes.io/name: ($name)
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: ($repo_url)
    targetRevision: ($target_revision)
    path: ($chart_dir)
    helm:
      releaseName: ($name)
($values_files)
  destination:
    server: https://kubernetes.default.svc
    namespace: ($namespace)
($auto_sync)
  revisionHistoryLimit: 10
"
    
    # Apply the ArgoCD Application
    $app_manifest | kubectl apply -f -
    
    print "✅ ArgoCD Application created successfully"
    print $"🌐 View in ArgoCD UI: kubectl port-forward -n argocd svc/argocd-server 8080:443"
    print $"📋 Check sync status: argocd app get ($name)"
}

def deploy_flux_app [
    name: string,
    namespace: string,
    chart_dir: string,
    repo_url: string,
    target_revision: string,
    values_file: string = ""
] {
    let values_ref = if ($values_file != "") {
        $"  valuesFiles:
  - ($values_file)"
    } else {
        ""
    }
    
    # Create GitRepository
    let git_repo = $"
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: ($name)-source
  namespace: ($namespace)
spec:
  interval: 1m
  url: ($repo_url)
  ref:
    branch: ($target_revision)
"
    
    # Create HelmRelease
    let helm_release = $"
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ($name)
  namespace: ($namespace)
spec:
  interval: 5m
  chart:
    spec:
      chart: ($chart_dir)
      sourceRef:
        kind: GitRepository
        name: ($name)-source
      interval: 1m
($values_ref)
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
"
    
    # Apply Flux manifests
    $git_repo | kubectl apply -f -
    $helm_release | kubectl apply -f -
    
    print "✅ Flux HelmRelease created successfully"
    print $"📋 Check status: flux get helmreleases ($name) -n ($namespace)"
}

def "main app sync" [
    name: string,
    --namespace: string = "default",
    --gitops: string = "argocd",
    --prune,
    --dry-run
] {
    print $"🔄 Syncing application '($name)' via ($gitops)..."
    
    match $gitops {
        "argocd" => { sync_argocd_app $name $prune $dry_run }
        "flux" => { sync_flux_app $name $namespace }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def sync_argocd_app [name: string, prune: bool, dry_run: bool] {
    let prune_flag = if $prune { "--prune" } else { "" }
    let dry_run_flag = if $dry_run { "--dry-run" } else { "" }
    
    argocd app sync $name $prune_flag $dry_run_flag
    
    if not $dry_run {
        argocd app wait $name --health
        print "✅ Application synced and healthy"
    }
}

def sync_flux_app [name: string, namespace: string] {
    flux reconcile helmrelease $name --namespace $namespace
    
    print "⏳ Waiting for reconciliation..."
    sleep 5sec
    
    flux get helmreleases $name --namespace $namespace
    print "✅ Flux reconciliation triggered"
}

def "main app diff" [
    name: string,
    --gitops: string = "argocd"
] {
    print $"🔍 Showing diff for application '($name)' via ($gitops)..."
    
    match $gitops {
        "argocd" => { argocd app diff $name }
        "flux" => { print "⚠️  Flux doesn't support native diff - use 'helm diff' with rendered templates" }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def "main app gitops-status" [
    name?: string,
    --gitops: string = "argocd",
    --namespace: string = "default"
] {
    print $"📊 GitOps status via ($gitops):"
    
    match $gitops {
        "argocd" => {
            if ($name | is-empty) {
                argocd app list
            } else {
                argocd app get $name
            }
        }
        "flux" => {
            if ($name | is-empty) {
                flux get all --namespace $namespace
            } else {
                flux get helmreleases $name --namespace $namespace
            }
        }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def "main app gitops-ui" [
    --gitops: string = "argocd",
    --port: int = 8080
] {
    match $gitops {
        "argocd" => {
            print $"🌐 Opening ArgoCD UI on port ($port)..."
            print "Default credentials: admin / (get password with: argocd admin initial-password -n argocd)"
            kubectl port-forward -n argocd svc/argocd-server $"($port):443"
        }
        "flux" => {
            print "🌐 Flux doesn't have a native UI. Consider installing Weave GitOps:"
            print "  helm repo add weaveworks https://helm.gitops.weave.works"
            print "  helm install weave-gitops weaveworks/weave-gitops --namespace flux-system"
            print $"  kubectl port-forward -n flux-system svc/weave-gitops ($port):9001"
        }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def "main app gitops-logs" [
    name: string,
    --gitops: string = "argocd",
    --namespace: string = "default",
    --follow
] {
    let follow_flag = if $follow { "-f" } else { "" }
    
    match $gitops {
        "argocd" => {
            print $"📝 ArgoCD Application Controller logs for '($name)':"
            kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller $follow_flag | grep $name
        }
        "flux" => {
            print $"📝 Flux HelmRelease logs for '($name)':"
            kubectl logs -n flux-system -l app=helm-controller $follow_flag | grep $name
        }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def "main app create-repo" [
    name: string,
    --gitops: string = "argocd",
    --repo-url: string,
    --username: string = "",
    --password: string = "",
    --ssh-private-key: string = ""
] {
    print $"📦 Adding repository for GitOps ($gitops)..."
    
    match $gitops {
        "argocd" => {
            let auth_args = if ($username != "") and ($password != "") {
                $"--username ($username) --password ($password)"
            } else if ($ssh_private_key != "") {
                $"--ssh-private-key-path ($ssh_private_key)"
            } else {
                ""
            }
            
            argocd repo add $repo_url $auth_args
            print "✅ Repository added to ArgoCD"
        }
        "flux" => {
            let auth_secret = if ($username != "") and ($password != "") {
                kubectl create secret generic $"($name)-auth" --from-literal=username=$username --from-literal=password=$password --namespace flux-system --dry-run=client -o yaml | kubectl apply -f -
                $"  secretRef:
    name: ($name)-auth"
            } else {
                ""
            }
            
            let git_repo = $"
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: ($name)
  namespace: flux-system
spec:
  interval: 1m
  url: ($repo_url)
($auth_secret)
"
            
            $git_repo | kubectl apply -f -
            print "✅ Repository added to Flux"
        }
        _ => { error make { msg: $"Unsupported GitOps tool: ($gitops)" } }
    }
}

def "main app kcl-build-app" [
    name: string,
    --kcl-file: string = "main.k",
    --namespace: string = "default",
    --output-dir: string = "./output",
    --apply,
    --dry-run
] {
    print $"🔧 Building and deploying KCL application '($name)'..."
    
    if not ($kcl_file | path exists) {
        error make { msg: $"KCL file not found: ($kcl_file)" }
    }
    
    mkdir $output_dir
    
    let output_file = $"($output_dir)/($name).yaml"
    
    print $"📝 Generating Kubernetes manifests from KCL file: ($kcl_file)"
    kcl run $kcl_file -o $output_file
    
    if not ($output_file | path exists) {
        error make { msg: $"Failed to generate output file: ($output_file)" }
    }
    
    print $"✅ KCL manifests generated: ($output_file)"
    
    if $apply {
        if $dry_run {
            print "🧪 Dry run: Applying KCL manifests to Kubernetes cluster..."
            kubectl apply -f $output_file --namespace $namespace --dry-run=client
        } else {
            print "🚀 Applying KCL manifests to Kubernetes cluster..."
            kubectl apply -f $output_file --namespace $namespace
            
            print $"📋 Check status: kubectl get all -l app=($name) --namespace ($namespace)"
        }
    } else {
        print $"📄 Manifests generated. To apply: kubectl apply -f ($output_file) --namespace ($namespace)"
    }
    
    print "✅ KCL build and deployment process completed"
}

def "main app help" [] {
    print "🚀 Application Management Commands:"
    print ""
    print "🔧 Deployment & Lifecycle:"
    print "  deploy <name>          - Deploy application (supports --gitops=argocd|flux|none)"
    print "  kcl-build-app <name>   - Build KCL configuration and deploy to cluster"
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