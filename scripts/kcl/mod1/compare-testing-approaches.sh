#!/bin/bash
set -e

# This script demonstrates both Testkube and Chainsaw for testing KCL functions
# and helps you understand when to use each approach

echo "🧪 KCL Function Testing Approaches Comparison"
echo "============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print section header
section() {
    echo ""
    echo -e "${BLUE}## $1${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

# Print feature comparison
feature() {
    local feature=$1
    local testkube=$2
    local chainsaw=$3
    
    # Format support indicators
    if [[ "$testkube" == "✓" ]]; then
        testkube="${GREEN}✓${NC}"
    elif [[ "$testkube" == "✗" ]]; then
        testkube="${RED}✗${NC}"
    elif [[ "$testkube" == "~" ]]; then
        testkube="${YELLOW}~${NC}"
    fi
    
    if [[ "$chainsaw" == "✓" ]]; then
        chainsaw="${GREEN}✓${NC}"
    elif [[ "$chainsaw" == "✗" ]]; then
        chainsaw="${RED}✗${NC}"
    elif [[ "$chainsaw" == "~" ]]; then
        chainsaw="${YELLOW}~${NC}"
    fi
    
    printf "%-40s %-15s %-15s\n" "$feature" "$testkube" "$chainsaw"
}

# Introduction
section "Introduction"
echo "This guide will help you understand when to use Testkube vs Chainsaw"
echo "for testing your KCL Crossplane functions."
echo ""
echo "Both are Kubernetes-native testing frameworks, but they have different"
echo "strengths and are designed for different use cases."

# Feature Comparison
section "Feature Comparison"
printf "%-40s %-15s %-15s\n" "Feature" "Testkube" "Chainsaw"
printf "%-40s %-15s %-15s\n" "-------" "--------" "---------"
feature "Pure YAML declarative tests" "~" "✓"
feature "Custom scripting support" "✓" "✗"
feature "Multi-language support" "✓" "✗"
feature "Resource-focused assertions" "~" "✓"
feature "Complex validation logic" "✓" "~"
feature "Dashboard & UI" "✓" "✗"
feature "Scheduling & automation" "✓" "~"
feature "Performance testing" "✓" "~"
feature "Historical data & trends" "✓" "✗"
feature "Kubernetes-native" "✓" "✓"
feature "Low resource overhead" "~" "✓"
feature "Easy setup" "~" "✓"
feature "Monitoring integration" "✓" "~"
feature "Test suite orchestration" "✓" "~"
feature "Learning curve" "Steeper" "Gentler"

# When to use each
section "When to Use Testkube"
echo "✅ For complex, multi-step test workflows"
echo "✅ When you need advanced test orchestration"
echo "✅ For comprehensive test reporting and dashboards"
echo "✅ When testing requires custom validation logic"
echo "✅ For multi-environment testing at scale"
echo "✅ When you need performance testing and benchmarking"
echo "✅ If you require historical trend analysis"

section "When to Use Chainsaw"
echo "✅ For simple Kubernetes resource validation"
echo "✅ When focused on testing resource lifecycle"
echo "✅ For operator/controller testing"
echo "✅ When pure declarative approach is preferred"
echo "✅ For quick setup with minimal configuration"
echo "✅ When resource overhead is a concern"
echo "✅ For teams already familiar with Kyverno"

# Examples of each approach
section "Example: Testing KCL Function Size Configuration"

echo -e "${YELLOW}Testkube Approach:${NC}"
echo 'apiVersion: tests.testkube.io/v3
kind: Test
metadata:
  name: kcl-size-test
spec:
  type: container
  executionRequest:
    image: alpine:latest
    command: ["/bin/bash", "-c"]
    args:
    - |
      # Install KCL
      curl -fsSL https://kcl-lang.io/script/install-cli.sh | /bin/sh
      
      # Test small size
      result=$(kcl run . -D '"'"'params={"oxr": {"metadata": {"name": "test-small"}, "spec": {"size": "small"}}, "ocds": {}}'"'"')
      if echo "$result" | grep -q "instances: 1" && echo "$result" | grep -q "size: '"'"'1Gi'"'"'"; then
        echo "✅ Small size configuration test passed"
      else
        echo "❌ Small size configuration test failed"
        exit 1
      fi
      
      # Test medium size
      # ... similar test logic for medium and large sizes'

echo -e "\n${YELLOW}Chainsaw Approach:${NC}"
echo 'apiVersion: chainsaw.kyverno.io/v1alpha1
kind: Test
metadata:
  name: kcl-size-test
spec:
  steps:
  # Create small XR resource
  - name: create-small-xr
    apply:
      resource:
        apiVersion: example.com/v1alpha1
        kind: XPostgreSQLInstance
        metadata:
          name: test-small-db
        spec:
          size: small
  
  # Verify the resulting PostgreSQL cluster
  - name: assert-small-cluster
    assert:
      resource:
        apiVersion: postgresql.cnpg.io/v1
        kind: Cluster
        metadata:
          name: test-small-db
        spec:
          instances: 1
          storage:
            size: "1Gi"'

# Practical comparison for your specific function
section "Choosing the Right Approach for KCL Functions"

echo "Your KCL function testing needs depend on your specific requirements:"

echo -e "\n${YELLOW}1. Choose Testkube if:${NC}"
echo "- You need to test the KCL language execution itself (like we've done)"
echo "- You're testing complex logic within the KCL function"
echo "- You want comprehensive test scheduling and reporting"
echo "- You want to test across multiple environments with different parameters"
echo "- Performance testing of your KCL function is important"

echo -e "\n${YELLOW}2. Choose Chainsaw if:${NC}"
echo "- You're mostly concerned with validating the resulting resources"
echo "- You want to test your full Crossplane pipeline (not just the KCL part)"
echo "- You prefer a pure declarative approach"
echo "- You want to test the integration with other Kubernetes components"
echo "- You're already using Kyverno in your environment"

echo -e "\n${YELLOW}3. Use Both Together (Best Option):${NC}"
echo "- Testkube for unit/integration tests of the KCL function itself"
echo "- Chainsaw for end-to-end resource validation tests"
echo "- This gives you the best of both worlds!"

# Running both examples
section "Try It Yourself"

echo "We've created examples of both approaches in this directory:"
echo "1. Testkube: testkube/ directory with multiple test configurations"
echo "2. Chainsaw: chainsaw-kcl-test.yaml with declarative tests"
echo ""
echo "To deploy Testkube and run the tests:"
echo "  ./deploy-testkube.sh"
echo ""
echo "To run Chainsaw tests (requires Chainsaw installation):"
echo "  chainsaw test --path chainsaw-kcl-test.yaml"
echo ""
echo "For best results, use both approaches together!"

# Conclusion
section "Conclusion"

echo "Both Testkube and Chainsaw are powerful tools for testing KCL Crossplane functions."
echo ""
echo "Testkube offers a more comprehensive, enterprise-grade solution with advanced"
echo "features, monitoring, and reporting capabilities. It's great for complex test"
echo "scenarios and when you need detailed metrics and history."
echo ""
echo "Chainsaw provides a simpler, more focused approach that excels at Kubernetes"
echo "resource validation. It's perfect for testing the actual resources your KCL"
echo "function generates and how they interact with your cluster."
echo ""
echo "For complete coverage, consider using both tools together in your testing strategy!"

# Call to action
echo ""
echo -e "${GREEN}Ready to improve your KCL testing?${NC}"
echo "Start with ./deploy-testkube.sh to see Testkube in action!"
