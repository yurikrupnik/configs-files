#!/bin/bash
set -e

# KCL Cluster Test Deployment Script
# Deploy and run tests in Kubernetes cluster using Testkube and Chainsaw

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Print with colors
print_status() {
    local status=$1
    local message=$2
    case $status in
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "HEADER")
            echo -e "${PURPLE}🚀 $message${NC}"
            ;;
    esac
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tool TOOL          Testing tool: testkube, chainsaw, both (default: both)"
    echo "  -d, --deploy            Deploy testing tools if not present"
    echo "  -r, --run               Run tests after deployment"
    echo "  -c, --cleanup           Cleanup test resources after running"
    echo "  -v, --verbose           Verbose output"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --deploy --run                    # Deploy tools and run all tests"
    echo "  $0 --tool chainsaw --run             # Run only Chainsaw tests"  
    echo "  $0 --tool testkube --deploy          # Deploy only Testkube"
    echo "  $0 --cleanup                         # Cleanup test resources"
    echo ""
}

# Default values
TOOL="both"
DEPLOY=false
RUN=false
CLEANUP=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--tool)
            TOOL="$2"
            shift 2
            ;;
        -d|--deploy)
            DEPLOY=true
            shift
            ;;
        -r|--run)
            RUN=true
            shift
            ;;
        -c|--cleanup)
            CLEANUP=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    print_status "INFO" "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_status "ERROR" "kubectl is not installed"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_status "ERROR" "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "SUCCESS" "Prerequisites check passed"
}

# Deploy Chainsaw
deploy_chainsaw() {
    print_status "INFO" "Checking Chainsaw installation..."
    
    if command -v chainsaw &> /dev/null; then
        print_status "SUCCESS" "Chainsaw CLI already installed"
    else
        print_status "INFO" "Installing Chainsaw CLI..."
        
        # Install Chainsaw using the official install script
        curl -fsSL https://raw.githubusercontent.com/kyverno/chainsaw/main/install.sh | bash
        
        # Verify installation
        if command -v chainsaw &> /dev/null; then
            print_status "SUCCESS" "Chainsaw CLI installed successfully"
        else
            print_status "ERROR" "Failed to install Chainsaw CLI"
            return 1
        fi
    fi
    
    # Create Chainsaw namespace if it doesn't exist
    if ! kubectl get namespace chainsaw &> /dev/null; then
        print_status "INFO" "Creating Chainsaw namespace..."
        kubectl create namespace chainsaw
        print_status "SUCCESS" "Chainsaw namespace created"
    else
        print_status "SUCCESS" "Chainsaw namespace already exists"
    fi
    
    return 0
}

# Deploy Testkube
deploy_testkube() {
    print_status "INFO" "Checking Testkube installation..."
    
    if kubectl get deployment testkube-api-server -n testkube &> /dev/null; then
        print_status "SUCCESS" "Testkube is already installed"
        return 0
    fi
    
    print_status "INFO" "Installing Testkube..."
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_status "ERROR" "Helm is required for Testkube installation"
        exit 1
    fi
    
    # Add Testkube Helm repository
    helm repo add testkube https://kubeshop.github.io/helm-charts
    helm repo update
    
    # Install Testkube
    helm install testkube testkube/testkube \
        --namespace testkube \
        --create-namespace \
        --set testkube-dashboard.enabled=true \
        --set mongodb.enabled=true
    
    # Wait for Testkube to be ready
    print_status "INFO" "Waiting for Testkube to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/testkube-api-server -n testkube
    kubectl wait --for=condition=available --timeout=300s deployment/testkube-dashboard -n testkube
    
    print_status "SUCCESS" "Testkube installed successfully"
    
    # Install Testkube kubectl plugin if not present
    if ! kubectl testkube version &> /dev/null; then
        print_status "INFO" "Installing Testkube kubectl plugin..."
        if command -v kubectl-krew &> /dev/null; then
            kubectl krew install testkube
            print_status "SUCCESS" "Testkube kubectl plugin installed"
        else
            print_status "WARNING" "kubectl-krew not found. Install manually with: kubectl krew install testkube"
        fi
    fi
    
    return 0
}

# Run Chainsaw tests
run_chainsaw_tests() {
    print_status "INFO" "Running Chainsaw tests..."
    
    if ! command -v chainsaw &> /dev/null; then
        print_status "ERROR" "Chainsaw CLI not found. Run with --deploy to install it."
        return 1
    fi
    
    if [[ ! -f "tests/cluster/chainsaw-tests.yaml" ]]; then
        print_status "ERROR" "Chainsaw test file not found: tests/cluster/chainsaw-tests.yaml"
        return 1
    fi
    
    # Run Chainsaw tests with verbose output if requested
    local chainsaw_args="test --test-file tests/cluster/chainsaw-tests.yaml"
    if [[ "$VERBOSE" == "true" ]]; then
        chainsaw_args="$chainsaw_args --verbose"
    fi
    
    if chainsaw $chainsaw_args; then
        print_status "SUCCESS" "Chainsaw tests completed successfully"
        return 0
    else
        print_status "ERROR" "Chainsaw tests failed"
        return 1
    fi
}

# Run Testkube tests
run_testkube_tests() {
    print_status "INFO" "Running Testkube tests..."
    
    if ! kubectl get deployment testkube-api-server -n testkube &> /dev/null; then
        print_status "ERROR" "Testkube not found. Run with --deploy to install it."
        return 1
    fi
    
    # Create test configurations if they don't exist
    create_testkube_test_configs
    
    # Run tests
    if kubectl testkube version &> /dev/null; then
        print_status "INFO" "Running Testkube test suite..."
        kubectl testkube run testsuite kcl-test-suite -n testkube --watch
        return $?
    else
        print_status "WARNING" "kubectl testkube plugin not found"
        print_status "INFO" "Running tests via API calls..."
        
        # Fallback to direct API calls if plugin is not available
        run_testkube_api_tests
        return $?
    fi
}

# Create basic Testkube test configurations
create_testkube_test_configs() {
    print_status "INFO" "Creating Testkube test configurations..."
    
    # Create a simple test for KCL function
    cat <<EOF | kubectl apply -f -
apiVersion: tests.testkube.io/v3
kind: Test
metadata:
  name: kcl-function-test
  namespace: testkube
spec:
  type: container
  content:
    type: string
    data: |
      #!/bin/bash
      echo "🧪 Testing KCL PostgreSQL Function"
      
      # Install KCL (if not present in container)
      if ! command -v kcl &> /dev/null; then
        curl -fsSL https://kcl-lang.io/script/install-cli.sh | /bin/sh
        export PATH=\$PATH:\$HOME/.kcl/bin
      fi
      
      # Clone or access the KCL module (adjust for your setup)
      # For now, we'll test with inline KCL code
      
      # Test basic functionality
      result=\$(kcl -E 'print("KCL is working")')
      if [ "\$?" -eq 0 ]; then
        echo "✅ KCL basic test passed"
      else
        echo "❌ KCL basic test failed"
        exit 1
      fi
      
      echo "🎉 All Testkube tests completed"
  executionRequest:
    image: alpine:latest
    command: ["/bin/sh"]
    args: ["-c"]
---
apiVersion: tests.testkube.io/v3
kind: TestSuite
metadata:
  name: kcl-test-suite
  namespace: testkube
spec:
  description: "KCL PostgreSQL Function Test Suite"
  steps:
  - stopOnFailure: false
    execute:
    - test: kcl-function-test
EOF

    print_status "SUCCESS" "Testkube test configurations created"
}

# Fallback API-based tests for Testkube
run_testkube_api_tests() {
    print_status "INFO" "Running Testkube tests via API..."
    
    # Port-forward to Testkube API
    kubectl port-forward -n testkube svc/testkube-api-server 8088:8088 &
    local port_forward_pid=$!
    
    # Wait for port-forward to be ready
    sleep 5
    
    # Run test via API
    local test_result=$(curl -s -X POST "http://localhost:8088/v1/tests/kcl-function-test/executions" \
        -H "Content-Type: application/json" \
        -d '{"name": "manual-execution"}')
    
    # Kill port-forward
    kill $port_forward_pid 2>/dev/null || true
    
    if echo "$test_result" | grep -q "id"; then
        print_status "SUCCESS" "Testkube test execution started"
        return 0
    else
        print_status "ERROR" "Failed to start Testkube test"
        return 1
    fi
}

# Cleanup test resources
cleanup_tests() {
    print_status "INFO" "Cleaning up test resources..."
    
    # Cleanup Chainsaw test resources
    if [[ "$TOOL" == "chainsaw" ]] || [[ "$TOOL" == "both" ]]; then
        print_status "INFO" "Cleaning up Chainsaw test resources..."
        kubectl delete xpostgresqlinstances --all --ignore-not-found=true
        kubectl delete clusters.postgresql.cnpg.io --all --ignore-not-found=true
        kubectl delete objects.kubernetes.m.crossplane.io --all --ignore-not-found=true
        kubectl delete namespace kcl-test-staging kcl-test-prod --ignore-not-found=true
        print_status "SUCCESS" "Chainsaw cleanup completed"
    fi
    
    # Cleanup Testkube test resources
    if [[ "$TOOL" == "testkube" ]] || [[ "$TOOL" == "both" ]]; then
        print_status "INFO" "Cleaning up Testkube test executions..."
        kubectl delete testexecutions -n testkube --all --ignore-not-found=true
        print_status "SUCCESS" "Testkube cleanup completed"
    fi
}

# Main execution
main() {
    print_status "HEADER" "KCL Cluster Test Deployment Script"
    echo "Tool: $TOOL | Deploy: $DEPLOY | Run: $RUN | Cleanup: $CLEANUP"
    echo ""
    
    check_prerequisites
    
    local exit_code=0
    
    # Deploy tools if requested
    if [[ "$DEPLOY" == "true" ]]; then
        case $TOOL in
            "testkube")
                deploy_testkube || exit_code=1
                ;;
            "chainsaw")
                deploy_chainsaw || exit_code=1
                ;;
            "both")
                deploy_testkube || exit_code=1
                deploy_chainsaw || exit_code=1
                ;;
        esac
    fi
    
    # Run tests if requested
    if [[ "$RUN" == "true" ]] && [[ $exit_code -eq 0 ]]; then
        case $TOOL in
            "testkube")
                run_testkube_tests || exit_code=1
                ;;
            "chainsaw")
                run_chainsaw_tests || exit_code=1
                ;;
            "both")
                print_status "INFO" "Running both Testkube and Chainsaw tests..."
                run_testkube_tests || exit_code=1
                echo ""
                run_chainsaw_tests || exit_code=1
                ;;
        esac
    fi
    
    # Cleanup if requested
    if [[ "$CLEANUP" == "true" ]]; then
        cleanup_tests
    fi
    
    # Final status
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_status "SUCCESS" "Cluster test deployment completed successfully! 🎉"
        
        # Provide next steps
        echo ""
        print_status "INFO" "Next Steps:"
        if kubectl get deployment testkube-dashboard -n testkube &> /dev/null; then
            echo "• Access Testkube Dashboard: kubectl port-forward -n testkube svc/testkube-dashboard 8080:8080"
        fi
        if command -v chainsaw &> /dev/null; then
            echo "• Run Chainsaw tests: chainsaw test --test-file tests/cluster/chainsaw-tests.yaml"
        fi
        echo "• Run all tests: ./tests/run-tests.sh --type cluster"
    else
        print_status "ERROR" "Some operations failed. Check the output above."
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
