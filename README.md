# 🛠️ Configuration Files & Nu Shell Cloud Platform Scripts

A comprehensive collection of dotfiles and Nu shell scripts for managing cloud-native infrastructure, including Kubernetes clusters, GitOps, logging, and infrastructure as code.

Inspired by [Beyond Dotfiles in 100 Seconds](https://github.com/eieioxyz/Beyond-Dotfiles-in-100-Seconds)

## 📁 Project Structure

```
configs-files/
├── scripts/                    # Nu shell scripts collection
│   ├── nu-scripts/            # Main Nu scripts directory
│   │   ├── main.nu           # Entry point - loads all modules
│   │   ├── cluster.nu        # Kind cluster management
│   │   ├── crossplane.nu     # Infrastructure as Code with Crossplane
│   │   ├── argocd.nu         # GitOps with ArgoCD
│   │   ├── loki.nu           # Logging with Loki/Promtail
│   │   ├── tracer.nu         # Command tracing utilities
│   │   ├── kcl.nu           # KCL configuration management
│   │   └── README.md         # Detailed Nu scripts documentation
│   ├── command-tracer/        # React dashboard for real-time tracing
│   ├── trace-server.js       # Express.js backend for trace streaming
│   ├── start-tracer.sh       # Startup script for tracing system
│   ├── cluster.nu            # Legacy cluster script
│   └── justfile              # Task runner configuration
├── .config/                   # Application configurations
├── brew/                      # Homebrew packages and dependencies
├── devbox/                    # Devbox development environment
├── kcl/                       # KCL configuration management
│   ├── base.k                # Core schemas and configurations  
│   ├── environments/         # Environment-specific configs
│   │   ├── local.k          # Local development environment
│   │   ├── staging.k        # Staging environment (AKS)
│   │   └── production.k     # Production environment (GKE)
│   ├── main.k               # Main entry point with all environments
│   ├── test.k               # Validation and testing
│   └── README.md            # KCL documentation
├── starship/                  # Cross-shell prompt configuration
├── zed/                       # Zed editor settings
├── zsh/                       # Zsh shell configuration
├── init.sh                    # Main initialization script
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

- [Nu Shell](https://nushell.sh) - Modern shell with structured data
- [kubectl](https://kubernetes.io/docs/tasks/tools/) - Kubernetes CLI
- [kind](https://kind.sigs.k8s.io/) - Kubernetes in Docker
- [helm](https://helm.sh/) - Kubernetes package manager
- [Docker](https://docker.com) - Container runtime
- [Node.js](https://nodejs.org) - For tracing dashboard (optional)
- [KCL](https://kcl-lang.io/) - Configuration language for type-safe infrastructure (optional)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yurikrupnik/configs-files.git
   cd configs-files
   ```

2. **Initialize configuration:**
   ```bash
   chmod +x init.sh
   ./init.sh
   ```

3. **Load Nu scripts:**
   ```bash
   # Start Nu shell and load scripts
   nu
   source scripts/nu-scripts/main.nu
   
   # Or run commands directly
   nu -c "source scripts/nu-scripts/main.nu; help commands"
   ```

## 🔧 Nu Shell Scripts Usage

### Cluster Management

Create and manage local Kubernetes clusters with integrated tooling:

```bash
# Create basic cluster
cluster create my-cluster

# Create cluster with ArgoCD and Loki
cluster create dev --argocd --loki

# Create cluster with Crossplane for infrastructure management
cluster create infra --crossplane --providers [aws azure gcp]

# Create full-stack cluster with all components
cluster create production --full-stack

# List all clusters
cluster list

# Get cluster status and information
cluster status my-cluster

# Delete cluster with cleanup
cluster delete my-cluster --cleanup-crossplane
```

### GitOps with ArgoCD

Manage GitOps workflows and application deployments:

```bash
# Install ArgoCD
argocd install --insecure

# Check ArgoCD status
argocd status

# Access ArgoCD UI (opens port-forward)
argocd ui --port 8080

# Get admin password
argocd password

# Create application from Git repository
argocd app create my-app https://github.com/user/repo.git manifests/

# List all applications
argocd apps

# Sync application
argocd sync my-app

# Delete application
argocd app delete my-app --cascade
```

### Logging with Loki

Set up centralized logging infrastructure:

```bash
# Install Loki logging stack
loki install --namespace monitoring

# Install Promtail log collector
loki install-promtail

# Check Loki status
loki status

# Access Loki for queries (port-forward)
loki port-forward --port 3100

# Query logs
loki query '{app="nginx"}' --limit 100 --since 1h

# View Loki logs
loki logs --follow
```

### Infrastructure as Code with Crossplane

Manage cloud infrastructure declaratively:

```bash
# Install Crossplane
crossplane install

# Install cloud providers
crossplane install-deps --providers [aws azure gcp kubernetes]

# Check Crossplane status
crossplane status

# List available packages
crossplane packages

# Create provider configuration
crossplane create-config aws

# Uninstall with cleanup
crossplane uninstall --purge
```

### Command Tracing

Monitor and trace all command executions:

```bash
# Initialize tracing
trace-init

# View current traces
trace-get

# Clear trace log
trace-clear

# Monitor traces in real-time
trace-monitor

# Start React dashboard for live tracing
./scripts/start-tracer.sh
```

### KCL Configuration Management

Manage infrastructure configurations with type-safe KCL:

```bash
# Validate all configurations
kcl validate

# List available environments
kcl list-envs

# View infrastructure summary
kcl infrastructure-summary

# Create cluster from KCL configuration
kcl create-cluster local --dry-run
kcl create-cluster production

# Generate ArgoCD applications
kcl generate-argocd-apps staging --output ./manifests

# Generate cost monitoring configs
kcl generate-cost-config production --output cost-config.yaml

# Run individual environment configurations
kcl run kcl/environments/local.k --format yaml
kcl run kcl/main.k --format json
```

## 📊 Real-Time Command Dashboard

Launch a web dashboard to monitor command executions in real-time:

```bash
# Start the tracing server and React dashboard
cd scripts
./start-tracer.sh
```

Access the dashboard at `http://localhost:3000` to see:
- Live command execution traces
- Performance metrics and durations
- Success/failure rates
- Interactive command history

## 🧪 Testing

### Manual Testing

Test individual components:

```bash
# Test cluster creation and component installation
cluster create test-cluster --full-stack

# Verify all components are running
cluster status test-cluster
crossplane status
argocd status
loki status

# Test KCL configuration management
kcl validate
kcl infrastructure-summary

# Create and deploy an application
argocd app create test-app https://github.com/argoproj/argocd-example-apps.git guestbook

# Clean up
cluster delete test-cluster
```

### Automated E2E Testing

Run the comprehensive end-to-end test suite:

```bash
# Run E2E tests
./scripts/test-e2e.sh

# Run specific test categories
./scripts/test-e2e.sh --category cluster
./scripts/test-e2e.sh --category argocd
./scripts/test-e2e.sh --category integration
```

## 🔄 CI/CD Integration

This project includes GitHub Actions workflows for automated testing:

- **E2E Tests**: Validates Nu scripts functionality
- **Integration Tests**: Tests component interactions
- **Documentation**: Ensures examples work correctly

See `.github/workflows/` for workflow configurations.

## 📖 Detailed Documentation

### Configuration Management

- **Stow Integration**: Symlink management for dotfiles
- **Cross-Platform**: Works on macOS, Linux
- **Modular Design**: Enable/disable components as needed

### Nu Shell Scripts

- **Type Safety**: Leverages Nu's structured data approach
- **Error Handling**: Comprehensive error management
- **Performance Monitoring**: Built-in command tracing
- **Extensible**: Easy to add new cloud services

### KCL Configuration

- **Schema Validation**: Type-safe infrastructure configuration
- **Multi-Environment**: Local, staging, and production environments
- **Cost Management**: Built-in budget tracking and alerting
- **Application Management**: Standardized application configurations
- **Kubernetes Integration**: Generate manifests and ArgoCD applications

### Supported Platforms

- **Local Development**: Kind clusters for testing
- **Cloud Providers**: AWS, Azure, GCP via Crossplane
- **Container Registries**: Docker Hub, ECR, ACR, GCR
- **GitOps**: GitHub, GitLab, Bitbucket repositories

## 🛡️ Security Considerations

- **Secrets Management**: Uses Kubernetes secrets and external-secrets-operator
- **RBAC**: Proper role-based access control
- **Network Policies**: Configurable network isolation
- **Image Security**: Supports image scanning and policies

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Commit your changes (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

### Development Guidelines

- Follow Nu shell best practices
- Add tests for new functionality
- Update documentation for new features
- Ensure all E2E tests pass

## 📋 Common Use Cases

### Development Workflow

```bash
# 1. Create development cluster
cluster create dev --argocd --loki

# 2. Deploy your application
argocd app create my-service https://github.com/user/my-service.git k8s/

# 3. Monitor logs
loki query '{app="my-service"}' --follow

# 4. Iterate and redeploy
argocd sync my-service
```

### Production Setup

```bash
# 1. Create production-ready cluster
cluster create prod --full-stack

# 2. Configure cloud infrastructure
crossplane create-config aws
crossplane create-config azure

# 3. Set up GitOps
argocd app create infrastructure https://github.com/company/infra.git environments/prod/

# 4. Monitor everything
loki install-promtail
argocd apps
```

### Learning Platform

```bash
# 1. Start with basics
cluster create learning

# 2. Add components incrementally
argocd install
loki install

# 3. Experiment with applications
argocd app create examples https://github.com/argoproj/argocd-example-apps.git

# 4. Use KCL for configuration management
kcl validate                    # Learn configuration validation
kcl infrastructure-summary     # Understand infrastructure layout
kcl create-cluster local --dry-run  # Preview cluster creation

# 5. Monitor and learn
./scripts/start-tracer.sh  # Watch commands in real-time
```

## 🔗 Related Projects

- [ArgoCD](https://argo-cd.readthedocs.io/) - Declarative GitOps CD
- [Crossplane](https://crossplane.io/) - Infrastructure as Code
- [Loki](https://grafana.com/oss/loki/) - Log aggregation system
- [Kind](https://kind.sigs.k8s.io/) - Kubernetes in Docker
- [Nu Shell](https://nushell.sh/) - Modern shell for the GitHub era
- [KCL](https://kcl-lang.io/) - Configuration language for cloud-native infrastructure

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Nu Shell community for the amazing shell
- CNCF projects for cloud-native tools
- Kubernetes community for the ecosystem
- All contributors and maintainers