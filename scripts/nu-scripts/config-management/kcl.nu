# KCL Configuration Management Module
# This module integrates KCL (Configuration Language) with Nu shell scripts
# for type-safe infrastructure configuration management

# Install KCL if not already installed
def "kcl install" [] {
    trace-log "kcl install" "started"

    if (which kcl | is-empty) {
        print "🔧 Installing KCL..."
        if $env.OS == "Darwin" {
            brew install kcl
        } else {
            curl -fsSL https://kcl-lang.io/install.sh | bash
        }
        trace-log "kcl install" "completed"
        print "✅ KCL installed successfully"
    } else {
        print "✅ KCL is already installed"
        trace-log "kcl install" "skipped" --data "already installed"
    }
}

# Initialize KCL project (if not already done)
def "kcl init" [
    --path(-p): string = "kcl"  # Path to KCL project
] {
    trace-log "kcl init" "started" --data $"path: ($path)"

    if not ($path | path exists) {
        print $"🔧 Creating KCL project at ($path)..."
        mkdir $path
        cd $path
        kcl mod init
        kcl mod add k8s
        cd ..
        trace-log "kcl init" "completed" --data $"created: ($path)"
        print "✅ KCL project initialized"
    } else {
        print $"✅ KCL project already exists at ($path)"
        trace-log "kcl init" "skipped" --data "already exists"
    }
}

# Run KCL configuration and return structured data
def "kcl run" [
    config: string              # KCL config file to run
    --format(-f): string = "yaml"  # Output format (yaml, json)
    --output(-o): string        # Output file path (optional)
] {
    trace-log "kcl run" "started" --data $"config: ($config), format: ($format)"

    if not ($config | path exists) {
        print $"❌ KCL config file not found: ($config)"
        trace-log "kcl run" "failed" --data "file not found"
        return
    }

    let result = if ($format == "json") {
        kcl run $config --format json | from json
    } else {
        kcl run $config --format yaml
    }

    if ($output | is-not-empty) {
        $result | save $output
        print $"💾 Output saved to ($output)"
    }

    trace-log "kcl run" "completed" --data $"format: ($format)"
    $result
}

# Validate KCL configurations
def "kcl validate" [
    --path(-p): string = "kcl"  # Path to KCL project
] {
    trace-log "kcl validate" "started" --data $"path: ($path)"

    if not ($path | path exists) {
        print $"❌ KCL project not found at ($path)"
        trace-log "kcl validate" "failed" --data "project not found"
        return false
    }

    print "🔍 Validating KCL configurations..."

    try {
        # Run test file if it exists
        let test_file = $"($path)/test.k"
        if ($test_file | path exists) {
            let test_result = kcl run $test_file | from yaml
            print "✅ KCL validation tests passed"
            trace-log "kcl validate" "completed" --data "tests passed"
            return true
        } else {
            # Just validate syntax of all .k files
            ls $"($path)/**/*.k" | each { |file|
                kcl fmt $file.name --check
            }
            print "✅ KCL syntax validation passed"
            trace-log "kcl validate" "completed" --data "syntax validated"
            return true
        }
    } catch {
        print "❌ KCL validation failed"
        trace-log "kcl validate" "failed" --data "validation errors"
        return false
    }
}

# Get environment configuration from KCL
def "kcl get-env" [
    environment: string         # Environment name (local, staging, production)
    --path(-p): string = "kcl"  # Path to KCL project
] {
    trace-log "kcl get-env" "started" --data $"env: ($environment)"

    let env_file = $"($path)/environments/($environment).k"
    if not ($env_file | path exists) {
        print $"❌ Environment configuration not found: ($env_file)"
        trace-log "kcl get-env" "failed" --data "env not found"
        return
    }

    let config = kcl run $env_file --format json | from json
    trace-log "kcl get-env" "completed" --data $"env: ($environment)"
    $config
}

# List all available environments
def "kcl list-envs" [
    --path(-p): string = "kcl"  # Path to KCL project
] {
    trace-log "kcl list-envs" "started"

    let envs_dir = $"($path)/environments"
    if not ($envs_dir | path exists) {
        print $"❌ Environments directory not found: ($envs_dir)"
        trace-log "kcl list-envs" "failed" --data "envs dir not found"
        return []
    }

    let environments = try {
        glob $"($envs_dir)/*.k" | each { |file|
            $file | path basename | str replace ".k" ""
        }
    } catch {
        []
    }

    print "📋 Available environments:"
    $environments | each { |env_name| print $"  • ($env_name)" }

    trace-log "kcl list-envs" "completed" --data $"count: ($environments | length)"
    $environments
}

# Generate cluster configuration from KCL environment
def "kcl cluster-config" [
    environment: string         # Environment name
    --path(-p): string = "kcl"  # Path to KCL project
] {
    trace-log "kcl cluster-config" "started" --data $"env: ($environment)"

    let env_config = kcl get-env $environment --path $path
    if ($env_config | is-empty) {
        return
    }

    # Extract cluster configuration
    let cluster_key = $"($environment)Cluster"
    let cluster = $env_config | get $cluster_key

    let config = {
        name: $cluster.name,
        environment: $cluster.environment,
        applications: $cluster.applications,
        cost: $cluster.cost,
        monitoring: $cluster.monitoring
    }

    trace-log "kcl cluster-config" "completed"
    $config
}

# Generate ArgoCD application manifests from KCL
def "kcl generate-argocd-apps" [
    environment: string         # Environment name
    --repo-url(-r): string = "https://github.com/yurikrupnik/configs-files"  # Git repository URL
    --target-revision(-t): string = "main"  # Git branch/tag
    --path(-p): string = "kcl"  # Path to KCL project
    --output(-o): string        # Output directory for manifests
] {
    trace-log "kcl generate-argocd-apps" "started" --data $"env: ($environment)"

    let cluster_config = kcl cluster-config $environment --path $path
    if ($cluster_config | is-empty) {
        return
    }

    let applications = $cluster_config.applications | where enabled == true

    print $"🔄 Generating ArgoCD applications for ($environment) environment..."

    let manifests = $applications | each { |app|
        {
            apiVersion: "argoproj.io/v1alpha1",
            kind: "Application",
            metadata: {
                name: $app.name,
                namespace: "argocd",
                labels: {
                    environment: $environment,
                    "managed-by": "kcl"
                }
            },
            spec: {
                project: "default",
                source: {
                    repoURL: $repo_url,
                    targetRevision: $target_revision,
                    path: $"manifests/($app.name)",
                    helm: {
                        values: ($app.values? // {})
                    }
                },
                destination: {
                    server: "https://kubernetes.default.svc",
                    namespace: $app.namespace
                },
                syncPolicy: {
                    automated: {
                        prune: true,
                        selfHeal: true
                    },
                    syncOptions: [
                        "CreateNamespace=true"
                    ]
                }
            }
        }
    }

    if ($output | is-not-empty) {
        mkdir $output
        $manifests | each { |manifest|
            let filename = $"($output)/($manifest.metadata.name)-app.yaml"
            $manifest | to yaml | save $filename
            print $"💾 Saved ArgoCD application: ($filename)"
        }
    }

    trace-log "kcl generate-argocd-apps" "completed" --data $"apps: ($manifests | length)"
    $manifests
}

# Generate cost monitoring configuration from KCL
def "kcl generate-cost-config" [
    environment: string         # Environment name
    --path(-p): string = "kcl"  # Path to KCL project
    --output(-o): string        # Output file path
] {
    trace-log "kcl generate-cost-config" "started" --data $"env: ($environment)"

    let cluster_config = kcl cluster-config $environment --path $path
    if ($cluster_config | is-empty) {
        return
    }

    let cost_config = {
        apiVersion: "v1",
        kind: "ConfigMap",
        metadata: {
            name: "cost-monitoring-config",
            namespace: "monitoring",
            labels: {
                environment: $environment,
                component: "cost-monitoring"
            }
        },
        data: {
            budget: ($cluster_config.cost.budget | into string),
            "alert-threshold": ($cluster_config.cost.alertThreshold | into string),
            currency: $cluster_config.cost.currency,
            environment: $environment,
            "node-count": ($cluster_config.environment.nodeCount | into string),
            "node-size": $cluster_config.environment.nodeSize
        }
    }

    if ($output | is-not-empty) {
        $cost_config | to yaml | save $output
        print $"💾 Cost configuration saved: ($output)"
    }

    trace-log "kcl generate-cost-config" "completed"
    $cost_config
}

# Create cluster based on KCL environment configuration
def "kcl create-cluster" [
    environment: string         # Environment name
    --path(-p): string = "kcl"  # Path to KCL project
    --dry-run(-d)              # Show what would be created without creating
] {
    trace-log "kcl create-cluster" "started" --data $"env: ($environment), dry-run: ($dry_run)"

    let cluster_config = kcl cluster-config $environment --path $path
    if ($cluster_config | is-empty) {
        return
    }

    let cluster_name = $cluster_config.name
    let env_type = $cluster_config.environment.type
    let applications = $cluster_config.applications | where enabled == true

    print $"🚀 Creating cluster '($cluster_name)' for ($environment) environment"
    print $"   Type: ($env_type)"
    print $"   Nodes: ($cluster_config.environment.nodeCount)"
    print $"   Applications: ($applications | length)"
    print $"   Budget: $($cluster_config.cost.budget) ($cluster_config.cost.currency)"

    if $dry_run {
        print "🔍 Dry run - no actual resources created"
        trace-log "kcl create-cluster" "completed" --data "dry-run"
        return
    }

    # Create the cluster using existing cluster command
    let cluster_args = [$cluster_name]

    # Add application flags based on KCL config
    let app_names = $applications | where enabled == true | get name

    # Use full-stack if all major components are enabled
    let major_apps = ["crossplane", "argocd", "loki", "prometheus"]
    let has_all_major = $major_apps | all {|app| $app in $app_names}

    let app_flags = if $has_all_major {
        ["--full-stack"]
    } else {
        [
            (if "crossplane" in $app_names { "--crossplane" } else { "" })
            (if "argocd" in $app_names { "--argocd" } else { "" })
            (if "loki" in $app_names { "--loki" } else { "" })
        ] | where $it != ""
    }

    print $"🔧 Running: cluster create ($cluster_args | str join ' ') ($app_flags | str join ' ')"

    # Call the existing cluster create function
    let create_cmd = (["cluster", "create"] | append $cluster_args | append $app_flags | str join " ")
    nu -c $create_cmd

    trace-log "kcl create-cluster" "completed" --data $"cluster: ($cluster_name)"
}

# Generate infrastructure summary from all KCL environments
def "kcl infrastructure-summary" [
    --path(-p): string = "kcl"  # Path to KCL project
] {
    trace-log "kcl infrastructure-summary" "started"

    let main_file = $"($path)/main.k"
    if not ($main_file | path exists) {
        print $"❌ Main KCL file not found: ($main_file)"
        trace-log "kcl infrastructure-summary" "failed"
        return
    }

    let summary = kcl run $main_file --format json | from json

    print "📊 Infrastructure Summary"
    print "========================="
    print $"Total Environments: ($summary.summary.total_environments)"
    print $"Total Applications: ($summary.summary.total_applications)"
    print $"Total Budget: $($summary.summary.total_budget) USD"
    print ""

    print "🌍 Environment Details:"
    $summary.summary.cluster_info | transpose key value | each { |row|
        let environment = $row.key
        let info = $row.value
        print $"  ($environment):"
        print $"    Type: ($info.type)"
        print $"    Nodes: ($info.nodes)"
        print $"    Apps: ($info.enabled_apps)"
        print $"    Budget: $($info.budget)"
        print ""
    }

    trace-log "kcl infrastructure-summary" "completed"
    $summary
}

# Format KCL files
def "kcl format" [
    --path(-p): string = "kcl"  # Path to KCL project
    --check(-c)                # Check formatting without modifying files
] {
    trace-log "kcl format" "started" --data $"check: ($check)"

    let kcl_files = try {
        glob $"($path)/**/*.k"
    } catch {
        []
    }

    if $check {
        print "🔍 Checking KCL file formatting..."
        let check_results = $kcl_files | each {|file|
            let result = (kcl fmt $file --check | complete)
            { file: $file, formatted: ($result.exit_code == 0) }
        }

        let unformatted = $check_results | where formatted == false | get file

        if ($unformatted | is-empty) {
            print "✅ All KCL files are properly formatted"
            trace-log "kcl format" "completed" --data "all formatted"
            return true
        } else {
            print $"❌ Files need formatting: ($unformatted | str join ', ')"
            trace-log "kcl format" "failed" --data $"unformatted: ($unformatted | length)"
            return false
        }
    } else {
        print "🎨 Formatting KCL files..."
        for file in $kcl_files {
            kcl fmt $file
            print $"  ✅ Formatted: ($file)"
        }
        trace-log "kcl format" "completed" --data $"formatted: ($kcl_files | length)"
        print "✅ All KCL files formatted"
    }
}

# Help function for KCL commands
def "kcl help" [] {
    print "🔧 KCL Configuration Management Commands:"
    print "========================================"
    print ""
    print "📋 SETUP & VALIDATION:"
    print "  kcl install                                    # Install KCL"
    print "  kcl init [--path]                             # Initialize KCL project"
    print "  kcl validate [--path]                         # Validate configurations"
    print "  kcl format [--path] [--check]                 # Format KCL files"
    print ""
    print "🌍 ENVIRONMENT MANAGEMENT:"
    print "  kcl list-envs [--path]                        # List available environments"
    print "  kcl get-env <environment> [--path]            # Get environment config"
    print "  kcl cluster-config <environment> [--path]     # Get cluster configuration"
    print "  kcl infrastructure-summary [--path]           # Show infrastructure summary"
    print ""
    print "🚀 CLUSTER OPERATIONS:"
    print "  kcl create-cluster <environment> [--path] [--dry-run]  # Create cluster from KCL"
    print ""
    print "🔄 MANIFEST GENERATION:"
    print "  kcl generate-argocd-apps <env> [options]      # Generate ArgoCD applications"
    print "  kcl generate-cost-config <env> [options]      # Generate cost monitoring config"
    print ""
    print "🛠️ UTILITIES:"
    print "  kcl run <config> [--format] [--output]        # Run KCL configuration"
    print "  kcl help                                       # Show this help"
    print ""
    print "💡 EXAMPLES:"
    print "  kcl validate                                   # Validate all configs"
    print "  kcl create-cluster local --dry-run           # Preview local cluster creation"
    print "  kcl create-cluster production                 # Create production cluster"
    print "  kcl generate-argocd-apps staging --output ./manifests"
    print "  kcl infrastructure-summary                    # Show infrastructure overview"
}

print "📦 KCL Configuration Management module loaded"
