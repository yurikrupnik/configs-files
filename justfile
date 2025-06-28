#!/usr/bin/env just --justfile

# Import scripts module
mod scripts

# Default recipe - show available commands
default:
    @echo "🚀 Available commands:"
    @echo ""
    @echo "📋 Main Commands:"
    @echo "  just init                    - Initialize development environment"
    @echo "  just validate               - Validate current environment"
    @echo "  just health-check           - Quick health check"
    @echo ""
    @echo "🔧 Cluster Management:"
    @echo "  just create-cluster [name]  - Create development cluster"
    @echo "  just delete-cluster [name]  - Delete cluster"
    @echo "  just list-clusters          - List all clusters"
    @echo ""
    @echo "📦 Package Management:"
    @echo "  just update-packages        - Update system packages"
    @echo "  just install-tools          - Install development tools"
    @echo ""
    @echo "🧪 Testing:"
    @echo "  just test-integration       - Run integration tests"
    @echo "  just test-kcl               - Test KCL configurations"
    @echo ""
    @echo "📖 Help:"
    @echo "  just scripts::default       - Show all scripts commands"
    @echo "  just --list                 - List all available recipes"
    @echo ""

# Legacy hello command
hello:
    @echo "👋 Hello! Use 'just' or 'just default' to see available commands"

# Generate detailed validation report
validate-report:
    @echo "📄 Generating validation report..."
    nu -c "source scripts/nu-scripts/init/validation.nu; generate-validation-report validation-report.md"

# =============================================================================
# CONVENIENT ALIASES FOR COMMON COMMANDS
# =============================================================================

# Initialize development environment (full setup)
init:
    just scripts::init

# Initialize with dry-run (preview changes)
init-preview:
    just scripts::init-preview

# Initialize skipping certain components
init-minimal:
    just scripts::init-minimal

# Validate current environment setup
validate:
    just scripts::validate

# Quick health check of critical tools
health-check:
    just scripts::health-check

# Create local development cluster with full stack
create-cluster name="dev":
    just scripts::create-cluster {{name}}

# Create minimal cluster (no additional components)
create-cluster-minimal name="minimal":
    just scripts::create-cluster-minimal {{name}}

# Delete cluster
delete-cluster name="dev":
    just scripts::delete-cluster {{name}}

# List all clusters
list-clusters:
    just scripts::list-clusters

# Show cluster status
cluster-status name="dev":
    just scripts::cluster-status {{name}}

# Update Homebrew and packages
update-packages:
    just scripts::update-packages

# Install additional development tools
install-tools:
    just scripts::install-rust-tools

# Verify development tools
verify-tools:
    just scripts::verify-tools

# Run complete integration test
test-integration:
    just scripts::test-integration

# Run KCL integration test
test-kcl:
    just scripts::test-kcl

# Install ArgoCD
install-argocd namespace="argocd":
    just scripts::install-argocd {{namespace}}

# Install Crossplane
install-crossplane namespace="crossplane-system":
    just scripts::install-crossplane {{namespace}}

# Install Loki
install-loki namespace="monitoring":
    just scripts::install-loki {{namespace}}

# Clean up temporary files
clean:
    just scripts::clean

# =============================================================================
# LEGACY COMPATIBILITY
# =============================================================================

# Legacy: create local cluster (maintained for compatibility)
create-local:
    @echo "⚠️  Using legacy command. Consider using 'just create-cluster' instead."
    just create-cluster dev

# Legacy: delete local cluster (maintained for compatibility)
delete-local:
    @echo "⚠️  Using legacy command. Consider using 'just delete-cluster' instead."
    just delete-cluster dev

# =============================================================================
# HELP AND INFORMATION
# =============================================================================

# Show all available commands from scripts module
scripts-help:
    just scripts::default

# Show help for specific categories
help-cluster:
    @echo "🔧 Cluster Management Commands:"
    @echo "  just create-cluster [name]           - Create development cluster"
    @echo "  just create-cluster-minimal [name]   - Create minimal cluster"
    @echo "  just delete-cluster [name]           - Delete cluster"
    @echo "  just delete-all-clusters             - Delete all clusters"
    @echo "  just list-clusters                   - List all clusters"
    @echo "  just cluster-status [name]           - Show cluster status"
    @echo "  just load-image [image] [name]       - Load docker image into cluster"
    @echo ""
    @echo "For more cluster commands: just scripts::list-clusters"

help-argocd:
    @echo "🔄 ArgoCD GitOps Commands:"
    @echo "  just install-argocd [namespace]      - Install ArgoCD"
    @echo "  just scripts::install-argocd-dev     - Install ArgoCD in dev mode"
    @echo "  just scripts::argocd-status          - Show ArgoCD status"
    @echo "  just scripts::argocd-ui [port]       - Open ArgoCD UI"
    @echo "  just scripts::argocd-password        - Get admin password"
    @echo "  just scripts::create-app [name] [repo] [path] - Create application"
    @echo ""
    @echo "For more ArgoCD commands: just scripts::list-apps"

help-monitoring:
    @echo "📊 Monitoring Commands:"
    @echo "  just install-loki [namespace]        - Install Loki"
    @echo "  just scripts::loki-status            - Show Loki status"
    @echo "  just scripts::loki-ui [port]         - Port-forward Loki UI"
    @echo "  just scripts::trace-init             - Start tracing"
    @echo "  just scripts::trace-monitor          - Monitor system"
    @echo ""
    @echo "For more monitoring commands: just scripts::trace-logs"

# Show version information
version:
    @echo "🚀 Configs-Files Development Environment"
    @echo "Just version: $(just --version)"
    @echo "Nu version: $(nu --version | head -1)"
    @echo "Kubectl version: $(kubectl version --client --short 2>/dev/null || echo 'Not installed')"
    @echo "Docker version: $(docker --version 2>/dev/null || echo 'Not installed')"
