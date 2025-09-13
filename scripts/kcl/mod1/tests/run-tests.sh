#!/bin/bash
set -e

# KCL PostgreSQL Function Test Runner
# Unified script to run all tests locally

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
    echo "  -m, --mode MODE          Test mode: all, basic, integration, scenarios, performance"
    echo "  -n, --namespace NS       Target namespace (default: default)"
    echo "  -t, --type TYPE          Test type: local, cluster, both (default: local)"
    echo "  -v, --verbose           Verbose output"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                       # Run all local tests"
    echo "  $0 --mode basic          # Run only basic tests"  
    echo "  $0 --type cluster        # Run cluster tests only"
    echo "  $0 --mode scenarios -v   # Run scenarios with verbose output"
    echo ""
}

# Default values
MODE="all"
NAMESPACE="default"
TYPE="local"
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -t|--type)
            TYPE="$2"
            shift 2
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
    
    if ! command -v kcl &> /dev/null; then
        print_status "ERROR" "KCL is not installed or not in PATH"
        exit 1
    fi
    
    if [[ "$TYPE" == "cluster" ]] || [[ "$TYPE" == "both" ]]; then
        if ! command -v kubectl &> /dev/null; then
            print_status "ERROR" "kubectl is not installed (required for cluster tests)"
            exit 1
        fi
        
        # Check cluster connectivity
        if ! kubectl cluster-info &> /dev/null; then
            print_status "ERROR" "Cannot connect to Kubernetes cluster"
            exit 1
        fi
    fi
    
    # Check if we're in the right directory
    if [[ ! -f "main.k" ]] || [[ ! -f "kcl.mod" ]]; then
        print_status "ERROR" "Not in a KCL module directory (main.k or kcl.mod missing)"
        exit 1
    fi
    
    print_status "SUCCESS" "Prerequisites check passed"
}

# Run local tests using Nu shell
run_local_tests() {
    print_status "HEADER" "Running Local KCL Function Tests"
    
    if command -v nu &> /dev/null; then
        print_status "INFO" "Using Nu shell for local tests..."
        
        VERBOSE_FLAG=""
        if [[ "$VERBOSE" == "true" ]]; then
            VERBOSE_FLAG="--verbose"
        fi
        
        ./tests/local/kcl-function-tests.nu --mode "$MODE" --namespace "$NAMESPACE" $VERBOSE_FLAG
    else
        print_status "WARNING" "Nu shell not found, falling back to basic bash tests..."
        run_basic_bash_tests
    fi
}

# Basic bash tests (fallback when Nu is not available)
run_basic_bash_tests() {
    local test_count=0
    local passed_count=0
    
    print_status "INFO" "Running basic KCL function tests..."
    
    # Test cases
    test_cases=(
        "small:1:1Gi"
        "medium:3:3Gi" 
        "large:6:6Gi"
    )
    
    for test_case in "${test_cases[@]}"; do
        IFS=':' read -r size instances storage <<< "$test_case"
        
        print_status "INFO" "Testing $size configuration..."
        ((test_count++))
        
        # Create test parameters
        params="{\"oxr\": {\"metadata\": {\"name\": \"test-$size\", \"namespace\": \"$NAMESPACE\"}, \"spec\": {\"size\": \"$size\"}}, \"ocds\": {}}"
        
        # Run KCL
        result=$(kcl run . -D "params=$params" 2>&1)
        exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            print_status "ERROR" "KCL execution failed for $size: $result"
            continue
        fi
        
        # Validate output
        if echo "$result" | grep -q "instances: $instances" && echo "$result" | grep -q "size: '$storage'"; then
            print_status "SUCCESS" "$size configuration test passed"
            ((passed_count++))
        else
            print_status "ERROR" "$size configuration test failed - output validation failed"
            if [[ "$VERBOSE" == "true" ]]; then
                echo "Expected: instances: $instances, size: '$storage'"
                echo "Output: $result"
            fi
        fi
    done
    
    # Report results
    local failed_count=$((test_count - passed_count))
    echo ""
    print_status "INFO" "Test Results Summary:"
    echo "   Total tests: $test_count"
    echo "   ✅ Passed: $passed_count"
    echo "   ❌ Failed: $failed_count"
    
    if [[ $failed_count -eq 0 ]]; then
        print_status "SUCCESS" "All basic tests passed!"
        return 0
    else
        print_status "ERROR" "Some tests failed"
        return 1
    fi
}

# Run cluster tests
run_cluster_tests() {
    print_status "HEADER" "Running Cluster Tests"
    
    # Check if Chainsaw is available
    if command -v chainsaw &> /dev/null; then
        print_status "INFO" "Running Chainsaw tests..."
        if [[ -f "tests/cluster/chainsaw-tests.yaml" ]]; then
            chainsaw test --test-file tests/cluster/chainsaw-tests.yaml
        else
            print_status "WARNING" "Chainsaw test file not found, skipping..."
        fi
    else
        print_status "WARNING" "Chainsaw not found, skipping resource validation tests"
    fi
    
    # Check if Testkube is available
    if kubectl get deployment testkube-api-server -n testkube &> /dev/null; then
        print_status "INFO" "Running Testkube tests..."
        run_testkube_tests
    else
        print_status "INFO" "Testkube not installed, skipping Testkube tests"
        print_status "INFO" "Run './deploy-testkube.sh' to set up Testkube testing"
    fi
}

# Run Testkube tests
run_testkube_tests() {
    # Check for kubectl testkube plugin
    if kubectl testkube version &> /dev/null; then
        print_status "INFO" "Running Testkube test suite..."
        kubectl testkube run testsuite kcl-test-suite -n testkube --watch
    else
        print_status "WARNING" "kubectl testkube plugin not found"
        print_status "INFO" "Install with: kubectl krew install testkube"
    fi
}

# Performance tests
run_performance_tests() {
    print_status "INFO" "Running performance tests..."
    
    local iterations=10
    local total_time=0
    
    for i in $(seq 1 $iterations); do
        local start_time=$(date +%s%N)
        
        kcl run . -D 'params={"oxr": {"metadata": {"name": "perf-test", "namespace": "default"}, "spec": {"size": "medium"}}, "ocds": {}}' > /dev/null 2>&1
        
        local end_time=$(date +%s%N)
        local execution_time=$(((end_time - start_time) / 1000000))  # Convert to milliseconds
        total_time=$((total_time + execution_time))
        
        if [[ "$VERBOSE" == "true" ]]; then
            print_status "INFO" "Iteration $i: ${execution_time}ms"
        fi
    done
    
    local avg_time=$((total_time / iterations))
    print_status "SUCCESS" "Performance test completed"
    echo "   Average execution time: ${avg_time}ms over $iterations iterations"
}

# Main execution
main() {
    print_status "HEADER" "KCL PostgreSQL Function Test Runner"
    echo "Mode: $MODE | Type: $TYPE | Namespace: $NAMESPACE"
    echo ""
    
    check_prerequisites
    
    local exit_code=0
    
    # Run based on type
    case $TYPE in
        "local")
            if [[ "$MODE" == "performance" ]]; then
                run_performance_tests
            else
                run_local_tests || exit_code=1
            fi
            ;;
        "cluster")
            run_cluster_tests || exit_code=1
            ;;
        "both")
            print_status "INFO" "Running both local and cluster tests..."
            echo ""
            
            if [[ "$MODE" == "performance" ]]; then
                run_performance_tests || exit_code=1
            else
                run_local_tests || exit_code=1
            fi
            
            echo ""
            run_cluster_tests || exit_code=1
            ;;
        *)
            print_status "ERROR" "Invalid type: $TYPE"
            usage
            exit 1
            ;;
    esac
    
    # Final status
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_status "SUCCESS" "All tests completed successfully! 🎉"
    else
        print_status "ERROR" "Some tests failed. Check the output above."
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
