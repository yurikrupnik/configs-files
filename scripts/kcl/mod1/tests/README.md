# KCL PostgreSQL Function Testing Framework

This directory contains an organized testing framework for your KCL PostgreSQL function with support for both local and cluster-based testing.

## 📁 Directory Structure

```
tests/
├── README.md                      # This documentation
├── run-tests.sh                   # Unified shell script runner
├── run-tests.nu                   # Enhanced Nu shell runner
├── deploy-cluster-tests.sh        # Cluster deployment script
├── local/                         # Local testing scripts
│   └── kcl-function-tests.nu     # Comprehensive local tests
├── cluster/                       # Cluster-based tests
│   └── chainsaw-tests.yaml       # Chainsaw resource validation tests
└── shared/                        # Shared test configurations
    └── test-scenarios.yaml        # Test data and scenarios
```

## 🚀 Quick Start

### Local Testing (Recommended)

```bash
# Run all local tests
./tests/run-tests.sh

# Run with Nu shell for enhanced output
nu ./tests/run-tests.nu

# Run specific test modes
./tests/run-tests.sh --mode basic
./tests/run-tests.sh --mode scenarios --verbose
./tests/run-tests.sh --mode performance
```

### Cluster Testing

```bash
# Deploy testing tools and run tests
./tests/deploy-cluster-tests.sh --deploy --run

# Run only Chainsaw tests
./tests/deploy-cluster-tests.sh --tool chainsaw --deploy --run

# Cleanup test resources
./tests/deploy-cluster-tests.sh --cleanup
```

## 📊 Testing Levels

### 1. **Local Function Testing** (Primary)
Tests the KCL function logic directly without requiring a Kubernetes cluster.

**What it tests:**
- ✅ KCL function syntax and logic
- ✅ Size configuration mapping (small→1 instance, medium→3, large→6)
- ✅ Resource generation (PostgreSQL Cluster + Secret Object)
- ✅ Naming conventions and annotations
- ✅ Multi-namespace scenarios
- ✅ Performance benchmarks

**Tools used:**
- Nu shell for enhanced testing
- Bash fallback for compatibility
- Direct KCL CLI invocation

### 2. **Cluster Resource Testing** (Advanced)
Tests the actual Kubernetes resources in a real cluster environment.

**What it tests:**
- ✅ Resource creation success in Kubernetes
- ✅ Crossplane composition functionality
- ✅ PostgreSQL operator integration
- ✅ Resource lifecycle management
- ✅ Cross-namespace resource validation

**Tools used:**
- Chainsaw for declarative K8s testing
- Testkube for comprehensive test orchestration

## 🛠️ Test Runners

### Shell Script Runner (`run-tests.sh`)

**Features:**
- Cross-platform compatibility
- Prerequisite checking
- Multiple test modes
- Bash fallback when Nu is unavailable
- Performance testing
- Colorized output

**Usage:**
```bash
# Basic usage
./tests/run-tests.sh [OPTIONS]

# Options:
#   -m, --mode MODE          Test mode: all, basic, integration, scenarios, performance
#   -n, --namespace NS       Target namespace (default: default)
#   -t, --type TYPE          Test type: local, cluster, both (default: local)
#   -v, --verbose           Verbose output
#   -h, --help              Show help

# Examples:
./tests/run-tests.sh                       # Run all local tests
./tests/run-tests.sh --mode basic          # Basic integration tests only
./tests/run-tests.sh --type cluster        # Cluster tests only
./tests/run-tests.sh --mode scenarios -v   # Scenarios with verbose output
```

### Nu Shell Runner (`run-tests.nu`)

**Enhanced Features:**
- Rich formatted output with colors
- Better error reporting
- Advanced test reporting with pass rates
- Performance analytics (min/max/avg times)
- Structured test execution

**Usage:**
```bash
# Basic usage
nu ./tests/run-tests.nu [OPTIONS]

# Enhanced options (same as shell script plus):
#   --help                  Enhanced help with examples

# Examples:
nu ./tests/run-tests.nu --mode all --verbose
nu ./tests/run-tests.nu --mode performance
```

### Cluster Deployment Script (`deploy-cluster-tests.sh`)

**Features:**
- Automatic tool installation (Testkube, Chainsaw)
- Multiple testing frameworks
- Resource cleanup
- Prerequisites checking

**Usage:**
```bash
./tests/deploy-cluster-tests.sh [OPTIONS]

# Options:
#   -t, --tool TOOL          Testing tool: testkube, chainsaw, both (default: both)
#   -d, --deploy            Deploy testing tools if not present
#   -r, --run               Run tests after deployment
#   -c, --cleanup           Cleanup test resources after running
#   -v, --verbose           Verbose output

# Examples:
./tests/deploy-cluster-tests.sh --deploy --run          # Full setup and testing
./tests/deploy-cluster-tests.sh --tool chainsaw --run   # Chainsaw only
./tests/deploy-cluster-tests.sh --cleanup               # Cleanup resources
```

## 🎯 Test Scenarios

The framework includes comprehensive test scenarios defined in `shared/test-scenarios.yaml`:

### Basic Scenarios
- **dev-postgres-small**: Tests small configuration (1 instance, 1Gi)
- **staging-postgres-medium**: Tests medium configuration (3 instances, 3Gi)  
- **prod-postgres-large**: Tests large configuration (6 instances, 6Gi)

### Edge Cases
- **test-with-special-chars**: Tests naming edge cases
- **very-long-name-test**: Tests Kubernetes naming limits

### Multi-Namespace Testing
- Tests across `default`, `production`, `staging`, `development` namespaces

## 📈 Test Modes

### `--mode all` (Default)
Runs comprehensive testing including:
- Basic integration tests
- Scenario-based validation
- Multi-namespace testing
- Resource structure validation

### `--mode basic`
Quick validation of core functionality:
- Size configuration tests (small/medium/large)
- Resource creation verification

### `--mode integration`  
Same as basic, focused on integration testing

### `--mode scenarios`
Runs all defined test scenarios from configuration:
- Basic scenarios
- Edge case scenarios
- Custom validation rules

### `--mode performance`
Performance benchmarking:
- Multiple execution iterations (default: 10)
- Timing measurements
- Average/min/max execution times
- Performance regression detection

## 🏗️ Local Testing Deep Dive

### Prerequisites
- **KCL CLI**: Must be installed and in PATH
- **Nu Shell** (optional): For enhanced testing experience

### Test Execution Flow
1. **Load Test Scenarios**: From `shared/test-scenarios.yaml`
2. **Execute KCL Function**: With various parameter combinations
3. **Validate Output**: Check for expected resources and configurations
4. **Generate Reports**: Comprehensive pass/fail summary

### Example Test Output
```
🧪 KCL PostgreSQL Function Local Tests
======================================

## Local KCL Function Tests
===========================

ℹ️  Running basic integration tests...
ℹ️  🔬 Testing scenario: test-small
✅ test-small validated
ℹ️  🔬 Testing scenario: test-medium  
✅ test-medium validated
ℹ️  🔬 Testing scenario: test-large
✅ test-large validated

## Test Results Summary
======================
   Total tests: 8
   ✅ Passed: 8
   ❌ Failed: 0
   📊 Pass rate: 100%

✅ All tests completed successfully! 🎉
```

## 🌐 Cluster Testing Deep Dive

### Chainsaw Tests

**Resource Validation Tests:**
- Verifies actual Kubernetes resource creation
- Tests Crossplane composition functionality
- Validates PostgreSQL operator integration
- Multi-namespace resource testing

**Test Structure:**
```yaml
# Basic configuration test
- name: test-small-configuration
  try:
  - apply:
      resource:
        apiVersion: example.com/v1alpha1
        kind: XPostgreSQLInstance
        spec:
          size: small
  - assert:
      resource:
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        spec:
          instances: 1
```

### Testkube Tests

**Enterprise Testing Features:**
- Test scheduling and automation
- Historical test results
- Test suite orchestration
- Dashboard and monitoring
- Notifications and reporting

## 🔧 Customization

### Adding New Test Scenarios

Edit `shared/test-scenarios.yaml`:

```yaml
scenarios:
  custom:
    - name: "my-custom-test"
      size: "medium"
      expected:
        instances: 3
        storage: "3Gi"
```

### Adding Custom Validation

Extend the test functions in `local/kcl-function-tests.nu`:

```nu
def test_custom_validation [scenario: record] {
    # Your custom test logic here
    return true
}
```

### Cluster Test Customization

Add new Chainsaw tests to `cluster/chainsaw-tests.yaml`:

```yaml
apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Test
metadata:
  name: my-custom-test
spec:
  steps:
  # Your test steps
```

## 🚨 Troubleshooting

### Common Issues

**"KCL not found"**
```bash
# Install KCL
curl -fsSL https://kcl-lang.io/script/install-cli.sh | /bin/sh
```

**"Nu shell not found"**
```bash
# Install Nu shell
curl -fsSL https://get.nu | sh
# Or use the shell script fallback
```

**"Cannot connect to Kubernetes cluster"**
```bash
# Check cluster connection
kubectl cluster-info

# Switch context if needed
kubectl config use-context <your-context>
```

**Chainsaw tests failing**
```bash
# Install Chainsaw
curl -fsSL https://raw.githubusercontent.com/kyverno/chainsaw/main/install.sh | bash

# Check test file path
ls -la tests/cluster/chainsaw-tests.yaml
```

### Debug Mode

Enable verbose output for detailed debugging:

```bash
# Shell script
./tests/run-tests.sh --verbose

# Nu shell
nu ./tests/run-tests.nu --verbose

# Cluster tests
./tests/deploy-cluster-tests.sh --verbose --run
```

## 📚 Integration with CI/CD

### GitHub Actions Example

```yaml
name: KCL Function Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Install KCL
      run: curl -fsSL https://kcl-lang.io/script/install-cli.sh | /bin/sh
      
    - name: Run Local Tests
      run: ./tests/run-tests.sh --mode all --verbose
      
    - name: Run Performance Tests
      run: ./tests/run-tests.sh --mode performance
```

### GitLab CI Example

```yaml
test_kcl:
  stage: test
  image: alpine:latest
  before_script:
    - apk add --no-cache curl bash
    - curl -fsSL https://kcl-lang.io/script/install-cli.sh | /bin/sh
  script:
    - ./tests/run-tests.sh --mode all
```

## 🎉 Best Practices

1. **Start with Local Testing**: Always validate function logic locally first
2. **Use Version Control**: Keep test scenarios in version control
3. **Regular Performance Testing**: Monitor function performance over time
4. **Cleanup Resources**: Always cleanup test resources in cluster environments
5. **Document Custom Tests**: Add documentation for any custom test scenarios
6. **Use Both Tools**: Combine local and cluster testing for complete coverage

## 📞 Support

For issues or questions:

1. Check the troubleshooting section above
2. Review test output for specific error messages
3. Use `--verbose` mode for detailed debugging information
4. Check that all prerequisites are installed and accessible

---

**Happy Testing! 🧪✨**
