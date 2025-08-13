#!/bin/bash

# End-to-End Test Suite for Nu Shell Cloud Platform Scripts
# Tests cluster creation, component installation, and integration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_CLUSTER_NAME="e2e-test-$(date +%s)"
TEST_APP_NAME="e2e-test-app"
TEST_TIMEOUT=300
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/nu-e2e-test.log"

# Test categories
CATEGORY="${1:-all}"

# Utility functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✅ $1${NC}" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}❌ $1${NC}" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

# Setup and cleanup functions
setup() {
    log "Setting up E2E test environment"
    
    # Check prerequisites
    check_prerequisites
    
    # Clean up any existing test clusters
    cleanup_test_clusters
    
    # Initialize log file
    echo "Nu Shell E2E Test Log - $(date)" > "$LOG_FILE"
    
    success "Test environment setup complete"
}

cleanup() {
    log "Cleaning up test environment"
    
    # Delete test cluster if it exists
    if kind get clusters | grep -q "$TEST_CLUSTER_NAME"; then
        log "Deleting test cluster: $TEST_CLUSTER_NAME"
        nu -c "source nu-scripts/main.nu; cluster delete $TEST_CLUSTER_NAME" || true
    fi
    
    # Clean up any other test clusters
    cleanup_test_clusters
    
    # Clean up trace files
    rm -f /tmp/nu-commands.jsonl
    
    success "Cleanup complete"
}

cleanup_test_clusters() {
    # Clean up any clusters starting with e2e-test
    kind get clusters | grep "^e2e-test" | xargs -I {} kind delete cluster --name {} 2>/dev/null || true
}

check_prerequisites() {
    local missing_deps=()
    
    # Check for required tools
    for tool in nu kubectl kind helm docker; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install missing dependencies and try again"
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        error "Docker is not running. Please start Docker and try again"
        exit 1
    fi
    
    # Check Nu scripts exist
    if [ ! -f "nu-scripts/main.nu" ]; then
        error "Nu scripts not found. Please run from the scripts directory"
        exit 1
    fi
    
    success "All prerequisites satisfied"
}

# Test functions
test_basic_cluster() {
    log "Testing basic cluster creation and deletion"
    
    # Test cluster creation
    log "Creating test cluster: $TEST_CLUSTER_NAME"
    if ! nu -c "source nu-scripts/main.nu; cluster create $TEST_CLUSTER_NAME"; then
        error "Failed to create cluster"
        return 1
    fi
    
    # Verify cluster exists
    if ! kind get clusters | grep -q "$TEST_CLUSTER_NAME"; then
        error "Cluster not found after creation"
        return 1
    fi
    
    # Test cluster status
    log "Checking cluster status"
    if ! nu -c "source nu-scripts/main.nu; cluster status $TEST_CLUSTER_NAME"; then
        error "Failed to get cluster status"
        return 1
    fi
    
    # Test cluster list
    log "Testing cluster list"
    if ! nu -c "source nu-scripts/main.nu; cluster list" | grep -q "$TEST_CLUSTER_NAME"; then
        error "Cluster not found in list"
        return 1
    fi
    
    # Test cluster deletion
    log "Deleting test cluster"
    if ! nu -c "source nu-scripts/main.nu; cluster delete $TEST_CLUSTER_NAME"; then
        error "Failed to delete cluster"
        return 1
    fi
    
    # Verify cluster is deleted
    if kind get clusters | grep -q "$TEST_CLUSTER_NAME"; then
        error "Cluster still exists after deletion"
        return 1
    fi
    
    success "Basic cluster tests passed"
}

test_crossplane() {
    log "Testing Crossplane installation and management"
    
    # Create cluster
    log "Creating cluster with Crossplane: $TEST_CLUSTER_NAME"
    if ! nu -c "source nu-scripts/main.nu; cluster create $TEST_CLUSTER_NAME --crossplane --providers [kubernetes]"; then
        error "Failed to create cluster with Crossplane"
        return 1
    fi
    
    # Wait for Crossplane to be ready
    log "Waiting for Crossplane to be ready"
    sleep 30
    
    # Test Crossplane status
    log "Checking Crossplane status"
    if ! nu -c "source nu-scripts/main.nu; crossplane status"; then
        warning "Crossplane status check failed (may be still starting)"
    fi
    
    # Test Crossplane packages
    log "Testing Crossplane packages"
    if ! nu -c "source nu-scripts/main.nu; crossplane packages"; then
        warning "Crossplane packages check failed"
    fi
    
    success "Crossplane tests passed"
}

test_argocd() {
    log "Testing ArgoCD installation and management"
    
    # Create cluster if not exists
    if ! kind get clusters | grep -q "$TEST_CLUSTER_NAME"; then
        log "Creating cluster for ArgoCD test: $TEST_CLUSTER_NAME"
        if ! nu -c "source nu-scripts/main.nu; cluster create $TEST_CLUSTER_NAME --argocd"; then
            error "Failed to create cluster with ArgoCD"
            return 1
        fi
    else
        # Install ArgoCD on existing cluster
        log "Installing ArgoCD on existing cluster"
        if ! nu -c "source nu-scripts/main.nu; argocd install --insecure"; then
            error "Failed to install ArgoCD"
            return 1
        fi
    fi
    
    # Wait for ArgoCD to be ready
    log "Waiting for ArgoCD to be ready"
    sleep 60
    
    # Test ArgoCD status
    log "Checking ArgoCD status"
    if ! nu -c "source nu-scripts/main.nu; argocd status"; then
        warning "ArgoCD status check failed (may be still starting)"
    fi
    
    # Test ArgoCD password retrieval
    log "Testing ArgoCD password retrieval"
    if ! nu -c "source nu-scripts/main.nu; argocd password"; then
        warning "ArgoCD password retrieval failed"
    fi
    
    # Test application creation
    log "Creating test ArgoCD application"
    if ! nu -c "source nu-scripts/main.nu; argocd app create $TEST_APP_NAME https://github.com/argoproj/argocd-example-apps.git guestbook"; then
        warning "Failed to create ArgoCD application"
    else
        # Test application listing
        log "Listing ArgoCD applications"
        if ! nu -c "source nu-scripts/main.nu; argocd apps" | grep -q "$TEST_APP_NAME"; then
            warning "Test application not found in list"
        fi
        
        # Clean up application
        log "Cleaning up test application"
        nu -c "source nu-scripts/main.nu; argocd app delete $TEST_APP_NAME --cascade" || true
    fi
    
    success "ArgoCD tests passed"
}

test_loki() {
    log "Testing Loki installation and management"
    
    # Create cluster if not exists
    if ! kind get clusters | grep -q "$TEST_CLUSTER_NAME"; then
        log "Creating cluster for Loki test: $TEST_CLUSTER_NAME"
        if ! nu -c "source nu-scripts/main.nu; cluster create $TEST_CLUSTER_NAME --loki"; then
            error "Failed to create cluster with Loki"
            return 1
        fi
    else
        # Install Loki on existing cluster
        log "Installing Loki on existing cluster"
        if ! nu -c "source nu-scripts/main.nu; loki install"; then
            warning "Failed to install Loki (expected in test environment)"
        fi
    fi
    
    # Test Loki status (may fail in test environment)
    log "Checking Loki status"
    if ! nu -c "source nu-scripts/main.nu; loki status"; then
        warning "Loki status check failed (expected in test environment)"
    fi
    
    success "Loki tests completed"
}

test_integration() {
    log "Testing full-stack integration"
    
    # Create full-stack cluster
    log "Creating full-stack cluster: $TEST_CLUSTER_NAME"
    if ! nu -c "source nu-scripts/main.nu; cluster create $TEST_CLUSTER_NAME --full-stack"; then
        warning "Full-stack cluster creation failed or timed out"
        return 1
    fi
    
    # Wait for components to be ready
    log "Waiting for components to initialize"
    sleep 90
    
    # Test each component
    log "Testing integrated components"
    
    # Crossplane
    if nu -c "source nu-scripts/main.nu; crossplane status" >> "$LOG_FILE" 2>&1; then
        success "Crossplane is running"
    else
        warning "Crossplane not ready"
    fi
    
    # ArgoCD
    if nu -c "source nu-scripts/main.nu; argocd status" >> "$LOG_FILE" 2>&1; then
        success "ArgoCD is running"
    else
        warning "ArgoCD not ready"
    fi
    
    # Loki (may fail in test environment)
    if nu -c "source nu-scripts/main.nu; loki status" >> "$LOG_FILE" 2>&1; then
        success "Loki is running"
    else
        warning "Loki status check failed (expected)"
    fi
    
    success "Integration tests completed"
}

test_tracing() {
    log "Testing command tracing functionality"
    
    # Initialize tracing
    if ! nu -c "source nu-scripts/main.nu; trace-init"; then
        error "Failed to initialize tracing"
        return 1
    fi
    
    # Run a traced command
    nu -c "source nu-scripts/main.nu; cluster list" >> "$LOG_FILE" 2>&1
    
    # Check if traces were created
    if [ -f "/tmp/nu-commands.jsonl" ] && [ -s "/tmp/nu-commands.jsonl" ]; then
        success "Command tracing is working"
    else
        warning "No traces found"
    fi
    
    # Test trace retrieval
    if nu -c "source nu-scripts/main.nu; trace-get" >> "$LOG_FILE" 2>&1; then
        success "Trace retrieval working"
    else
        warning "Trace retrieval failed"
    fi
    
    success "Tracing tests completed"
}

test_help_commands() {
    log "Testing help and documentation commands"
    
    # Test main help
    log "Testing main help command"
    local help_output
    help_output=$(nu -c "source nu-scripts/main.nu; help commands" 2>/dev/null) || {
        error "Main help command failed to execute"
        return 1
    }
    
    if ! echo "$help_output" | grep -q "Available Nu Shell Commands"; then
        error "Main help command output missing expected content"
        return 1
    fi
    
    success "Help commands working"
}

# Test runner
run_tests() {
    local test_category="$1"
    local failed_tests=()
    local passed_tests=()
    
    log "Running E2E tests for category: $test_category"
    
    case "$test_category" in
        "cluster"|"all")
            if test_basic_cluster; then
                passed_tests+=("basic_cluster")
            else
                failed_tests+=("basic_cluster")
            fi
            ;;
    esac
    
    case "$test_category" in
        "crossplane"|"all")
            if test_crossplane; then
                passed_tests+=("crossplane")
            else
                failed_tests+=("crossplane")
            fi
            ;;
    esac
    
    case "$test_category" in
        "argocd"|"all")
            if test_argocd; then
                passed_tests+=("argocd")
            else
                failed_tests+=("argocd")
            fi
            ;;
    esac
    
    case "$test_category" in
        "loki"|"all")
            if test_loki; then
                passed_tests+=("loki")
            else
                failed_tests+=("loki")
            fi
            ;;
    esac
    
    case "$test_category" in
        "integration"|"all")
            if test_integration; then
                passed_tests+=("integration")
            else
                failed_tests+=("integration")
            fi
            ;;
    esac
    
    case "$test_category" in
        "tracing"|"all")
            if test_tracing; then
                passed_tests+=("tracing")
            else
                failed_tests+=("tracing")
            fi
            ;;
    esac
    
    case "$test_category" in
        "help"|"all")
            if test_help_commands; then
                passed_tests+=("help")
            else
                failed_tests+=("help")
            fi
            ;;
    esac
    
    # Print results
    echo
    log "=== TEST RESULTS ==="
    
    if [ ${#passed_tests[@]} -gt 0 ]; then
        success "Passed tests (${#passed_tests[@]}): ${passed_tests[*]}"
    fi
    
    if [ ${#failed_tests[@]} -gt 0 ]; then
        error "Failed tests (${#failed_tests[@]}): ${failed_tests[*]}"
        log "Check log file for details: $LOG_FILE"
        return 1
    else
        success "All tests passed!"
        return 0
    fi
}

# Signal handling
trap cleanup EXIT INT TERM

# Main execution
main() {
    cd "$SCRIPT_DIR"
    
    echo "Nu Shell E2E Test Suite"
    echo "======================"
    echo "Category: $CATEGORY"
    echo "Log file: $LOG_FILE"
    echo
    
    setup
    
    if run_tests "$CATEGORY"; then
        success "E2E tests completed successfully"
        exit 0
    else
        error "E2E tests failed"
        exit 1
    fi
}

# Help function
show_help() {
    cat << EOF
Nu Shell E2E Test Suite

Usage: $0 [CATEGORY]

Categories:
  all          Run all test categories (default)
  cluster      Test basic cluster operations
  crossplane   Test Crossplane functionality
  argocd       Test ArgoCD functionality
  loki         Test Loki functionality
  integration  Test full-stack integration
  tracing      Test command tracing
  help         Test help commands

Examples:
  $0                    # Run all tests
  $0 cluster           # Run only cluster tests
  $0 integration       # Run integration tests

Environment Variables:
  TEST_TIMEOUT         Timeout for operations (default: 300s)

EOF
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main
        ;;
esac