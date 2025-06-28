# Justfile Usage Guide

This justfile provides a comprehensive set of commands for managing your development environment using Nu scripts. All commands are organized into logical sections for easy navigation.

## Quick Start

```bash
# Show all available commands
just --list

# Initialize your development environment
just init

# Preview what would be installed without making changes
just init-preview

# Validate your current setup
just validate
```

## 🚀 Environment Setup

| Command | Description | Example |
|---------|-------------|---------|
| `init` | Full environment setup | `just init` |
| `init-preview` | Preview changes without executing | `just init-preview` |
| `init-minimal` | Minimal setup (skip dev tools & config) | `just init-minimal` |
| `validate` | Validate current environment | `just validate` |
| `validate-report` | Generate detailed validation report | `just validate-report` |
| `health-check` | Quick health check of critical tools | `just health-check` |

## 🔧 Cluster Management

| Command | Description | Example |
|---------|-------------|---------|
| `create-cluster` | Create development cluster | `just create-cluster myapp` |
| `create-cluster-minimal` | Create minimal cluster | `just create-cluster-minimal test` |
| `create-cluster-with-providers` | Create cluster with specific providers | `just create-cluster-with-providers prod "aws,gcp"` |
| `delete-cluster` | Delete cluster | `just delete-cluster myapp` |
| `delete-all-clusters` | Delete all clusters with cleanup | `just delete-all-clusters` |
| `list-clusters` | List all clusters | `just list-clusters` |
| `cluster-status` | Show cluster status | `just cluster-status myapp` |
| `load-image` | Load docker image into cluster | `just load-image nginx:latest myapp` |

## 🌐 Infrastructure Components

### Crossplane
| Command | Description | Example |
|---------|-------------|---------|
| `install-crossplane` | Install Crossplane | `just install-crossplane` |
| `install-crossplane-full` | Install with providers | `just install-crossplane-full "aws,gcp,kubernetes"` |
| `crossplane-status` | Show Crossplane status | `just crossplane-status` |
| `uninstall-crossplane` | Uninstall Crossplane | `just uninstall-crossplane` |
| `search-packages` | Search packages | `just search-packages provider` |

### ArgoCD
| Command | Description | Example |
|---------|-------------|---------|
| `install-argocd` | Install ArgoCD | `just install-argocd` |
| `install-argocd-dev` | Install in dev mode (insecure) | `just install-argocd-dev` |
| `argocd-status` | Show ArgoCD status | `just argocd-status` |
| `argocd-ui` | Open ArgoCD UI | `just argocd-ui 8080` |
| `argocd-password` | Get admin password | `just argocd-password` |
| `create-app` | Create ArgoCD application | `just create-app myapp https://github.com/user/repo.git` |
| `list-apps` | List applications | `just list-apps` |
| `uninstall-argocd` | Uninstall ArgoCD | `just uninstall-argocd` |

### Loki Logging
| Command | Description | Example |
|---------|-------------|---------|
| `install-loki` | Install Loki | `just install-loki monitoring` |
| `loki-status` | Show Loki status | `just loki-status` |
| `loki-ui` | Port-forward Loki UI | `just loki-ui 3100` |
| `loki-query` | Query logs | `just loki-query '{app="myapp"}' 50` |
| `install-promtail` | Install Promtail | `just install-promtail` |
| `uninstall-loki` | Uninstall Loki | `just uninstall-loki` |

## 📦 KCL Configuration Management

| Command | Description | Example |
|---------|-------------|---------|
| `install-kcl` | Install KCL | `just install-kcl` |
| `kcl-validate` | Validate configurations | `just kcl-validate ./configs` |
| `kcl-environments` | List environments | `just kcl-environments ./configs` |
| `kcl-create-cluster` | Create cluster from KCL | `just kcl-create-cluster production` |
| `kcl-preview-cluster` | Preview cluster creation | `just kcl-preview-cluster staging` |
| `kcl-infrastructure-summary` | Show infrastructure summary | `just kcl-infrastructure-summary` |
| `kcl-generate-argocd` | Generate ArgoCD apps | `just kcl-generate-argocd local apps.yaml` |

## 🛠️ Development Tools

| Command | Description | Example |
|---------|-------------|---------|
| `update-packages` | Update Homebrew packages | `just update-packages` |
| `list-packages` | List installed packages | `just list-packages` |
| `check-outdated` | Check outdated packages | `just check-outdated` |
| `update-rust` | Update Rust toolchain | `just update-rust` |
| `install-rust-tools` | Install Rust dev tools | `just install-rust-tools` |
| `verify-tools` | Verify dev tools | `just verify-tools` |
| `benchmark-tools` | Benchmark tool performance | `just benchmark-tools` |

## ⚙️ Configuration Management

| Command | Description | Example |
|---------|-------------|---------|
| `setup-config` | Setup configurations | `just setup-config` |
| `verify-config` | Verify configurations | `just verify-config` |
| `reset-config` | Reset configurations (careful!) | `just reset-config` |

## 🧪 Testing & Integration

| Command | Description | Example |
|---------|-------------|---------|
| `test-integration` | Run complete integration test | `just test-integration` |
| `test-kcl` | Run KCL integration test | `just test-kcl` |
| `demo-kcl` | Demo KCL functionality | `just demo-kcl` |

## 🦀 CLI Development

| Command | Description | Example |
|---------|-------------|---------|
| `build-cli` | Build Rust CLI | `just build-cli` |
| `build-cli-release` | Build CLI (release mode) | `just build-cli-release` |
| `run-cli` | Run Rust CLI | `just run-cli --help` |
| `test-cli` | Test Rust CLI | `just test-cli` |

## 🔍 Monitoring & Tracing

| Command | Description | Example |
|---------|-------------|---------|
| `trace-init` | Initialize tracing | `just trace-init` |
| `trace-logs` | View trace logs | `just trace-logs` |
| `trace-monitor` | Start trace monitor | `just trace-monitor` |
| `trace-clear` | Clear trace logs | `just trace-clear` |

## 🔧 Utility Commands

| Command | Description | Example |
|---------|-------------|---------|
| `nu-help` | Show Nu commands help | `just nu-help` |
| `clean` | Clean temporary files | `just clean` |

## 📋 Common Workflows

### Setting up a new development environment:
```bash
# Preview what will be installed
just init-preview

# Full setup
just init

# Validate setup
just validate
```

### Creating a full development cluster:
```bash
# Create cluster with all components
just create-cluster mydev

# Check status
just cluster-status mydev

# Install ArgoCD in dev mode
just install-argocd-dev

# Open ArgoCD UI
just argocd-ui
```

### Working with KCL configurations:
```bash
# Validate your KCL configs
just kcl-validate ./infrastructure

# Preview cluster creation
just kcl-preview-cluster staging

# Create the cluster
just kcl-create-cluster staging

# Generate ArgoCD applications
just kcl-generate-argocd staging argocd-apps.yaml
```

### Monitoring and debugging:
```bash
# Health check
just health-check

# Check tool performance
just benchmark-tools

# Start monitoring
just trace-init
just trace-monitor
```

## 🔄 Migration from Legacy Commands

The justfile maintains backward compatibility:

| Legacy Command | New Equivalent | Recommendation |
|----------------|----------------|----------------|
| `create-local` | `create-cluster dev` | Use new command for more flexibility |
| `delete-local` | `delete-cluster dev` | Use new command for consistency |

## 💡 Tips

1. **Use tab completion**: Most shells support tab completion for `just` commands
2. **Combine with watch**: Use `watch just cluster-status myapp` for continuous monitoring
3. **Check logs**: Many commands provide detailed logging - use `--verbose` flags when available
4. **Dry-run first**: Always use preview/dry-run commands before making changes
5. **Customize defaults**: Edit the justfile to change default parameters (ports, namespaces, etc.)

## 🚨 Important Notes

- All commands are designed to be idempotent where possible
- Some commands (like `reset-config`) are destructive - use with caution
- The justfile assumes you're running from the `/scripts` directory
- Make sure Nu shell is installed and in your PATH
- Ensure all dependencies (kubectl, helm, etc.) are available

## 🆘 Troubleshooting

If commands fail:

1. Run `just validate` to check your environment
2. Run `just health-check` for quick diagnostics
3. Check that you're in the correct directory
4. Ensure Nu shell scripts are properly sourced
5. Verify tool installations with `just verify-tools`