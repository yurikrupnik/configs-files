#!/bin/bash
set -e

# KCL Testkube Deployment Script
# Converts and deploys your Nu shell tests to Testkube

echo "🚀 KCL Testkube Deployment Script"
echo "================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
    esac
}

# Check prerequisites
print_status "INFO" "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_status "ERROR" "kubectl is not installed"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_status "ERROR" "helm is not installed"
    exit 1
fi

print_status "SUCCESS" "Prerequisites check passed"

# Check if Testkube is already installed
print_status "INFO" "Checking if Testkube is installed..."

if kubectl get deployment testkube-api-server -n testkube &> /dev/null; then
    print_status "SUCCESS" "Testkube is already installed"
else
    print_status "INFO" "Installing Testkube..."
    
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
fi

# Prompt for repository URL
echo ""
print_status "INFO" "Configuration required:"
echo ""

read -p "🔗 Enter your Git repository URL (e.g., https://github.com/username/repo): " REPO_URL
if [ -z "$REPO_URL" ]; then
    print_status "ERROR" "Repository URL is required"
    exit 1
fi

# Prompt for Git credentials (optional)
echo ""
read -p "👤 Git username (leave empty for public repo): " GIT_USERNAME
if [ -n "$GIT_USERNAME" ]; then
    read -s -p "🔑 Git token/password: " GIT_TOKEN
    echo ""
fi

# Prompt for Slack webhook (optional)
echo ""
read -p "💬 Slack webhook URL (optional): " SLACK_WEBHOOK

# Update configuration files
print_status "INFO" "Updating configuration files..."

# Create temporary directory for updated files
TEMP_DIR=$(mktemp -d)
cp -r testkube/ "$TEMP_DIR/"

# Update repository URL in all files
find "$TEMP_DIR/testkube/" -name "*.yaml" -exec sed -i.bak "s|https://github.com/your-org/configs-files|$REPO_URL|g" {} \;

# Update Git credentials if provided
if [ -n "$GIT_USERNAME" ]; then
    sed -i.bak "s|your-username|$GIT_USERNAME|g" "$TEMP_DIR/testkube/04-environment-config.yaml"
    sed -i.bak "s|your-personal-access-token|$GIT_TOKEN|g" "$TEMP_DIR/testkube/04-environment-config.yaml"
fi

# Update Slack webhook if provided
if [ -n "$SLACK_WEBHOOK" ]; then
    find "$TEMP_DIR/testkube/" -name "*.yaml" -exec sed -i.bak "s|https://hooks.slack.com/your-webhook|$SLACK_WEBHOOK|g" {} \;
fi

print_status "SUCCESS" "Configuration files updated"

# Deploy configurations
print_status "INFO" "Deploying KCL Testkube configurations..."

files=(
    "00-install-testkube.yaml"
    "04-environment-config.yaml"
    "01-kcl-integration-tests.yaml"
    "02-kcl-e2e-tests.yaml"
    "03-kcl-test-suite.yaml"
    "05-deployment-monitoring.yaml"
)

for file in "${files[@]}"; do
    if [ -f "$TEMP_DIR/testkube/$file" ]; then
        print_status "INFO" "Applying $file..."
        kubectl apply -f "$TEMP_DIR/testkube/$file"
        print_status "SUCCESS" "$file applied"
    else
        print_status "WARNING" "File $file not found, skipping"
    fi
done

# Clean up temporary files
rm -rf "$TEMP_DIR"

# Verify deployment
print_status "INFO" "Verifying deployment..."
echo ""

echo "📊 Tests:"
kubectl get tests -n testkube -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,SCHEDULE:.spec.schedule

echo ""
echo "📋 Test Suites:"
kubectl get testsuites -n testkube -o custom-columns=NAME:.metadata.name,SCHEDULE:.spec.schedule

echo ""
print_status "SUCCESS" "Deployment completed successfully!"

# Provide next steps
echo ""
print_status "INFO" "🎯 Next Steps:"
echo ""
echo "1. Access Testkube Dashboard:"
echo "   kubectl port-forward -n testkube svc/testkube-dashboard 8080:8080"
echo "   Then open: http://localhost:8080"
echo ""
echo "2. Run tests manually:"
echo "   kubectl testkube run test kcl-integration-tests -n testkube"
echo "   kubectl testkube run testsuite kcl-crossplane-complete-suite -n testkube"
echo ""
echo "3. View test results:"
echo "   kubectl testkube get executions -n testkube"
echo ""
echo "4. Monitor tests:"
echo "   kubectl create job --from=cronjob/kcl-test-monitoring manual-monitor -n testkube"
echo ""

# Show scheduled tests
print_status "INFO" "📅 Scheduled Tests:"
echo "   • Integration tests: Daily at 6:00 AM"  
echo "   • E2E tests: Daily at 4:00 AM"
echo "   • Complete test suite: Daily at 3:00 AM"
echo "   • Monitoring report: Daily at 9:00 AM"
echo ""

print_status "SUCCESS" "Your KCL Nu shell tests are now running in Testkube! 🎉"

# Optional: Run a quick smoke test
echo ""
read -p "🧪 Run a quick smoke test now? (y/N): " run_test
if [[ $run_test =~ ^[Yy]$ ]]; then
    print_status "INFO" "Running smoke test..."
    kubectl testkube run test kcl-smoke-test -n testkube
    print_status "INFO" "Check test results with: kubectl testkube get executions -n testkube"
fi

echo ""
print_status "SUCCESS" "Setup complete! 🚀"
