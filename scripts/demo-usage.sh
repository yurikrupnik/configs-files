#!/bin/bash

# Demo Usage Script for Nu Shell Cloud Platform Scripts
# This script demonstrates the key features and usage patterns

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🎯 Nu Shell Cloud Platform Scripts Demo${NC}"
echo "========================================"
echo

echo -e "${YELLOW}📖 Loading Nu Scripts...${NC}"
nu -c "source nu-scripts/main.nu; help commands" | head -20
echo

echo -e "${YELLOW}📋 Available Commands Summary:${NC}"
echo "• cluster create/delete/list/status - Manage Kind clusters"
echo "• argocd install/status/ui/apps - GitOps with ArgoCD"
echo "• loki install/status/query - Logging with Loki"
echo "• crossplane install/status - Infrastructure as Code"
echo "• trace-* commands - Command tracing and monitoring"
echo

echo -e "${YELLOW}🚀 Demo 1: Create a basic cluster${NC}"
echo "Command: cluster create demo-basic"
echo "This creates a basic Kind cluster for local development"
echo

echo -e "${YELLOW}🔄 Demo 2: Create cluster with ArgoCD${NC}"
echo "Command: cluster create demo-gitops --argocd"
echo "This creates a cluster with ArgoCD for GitOps workflows"
echo

echo -e "${YELLOW}📊 Demo 3: Create full-stack cluster${NC}"
echo "Command: cluster create demo-full --full-stack"
echo "This creates a cluster with Crossplane + ArgoCD + Loki"
echo

echo -e "${YELLOW}🔍 Demo 4: Command tracing${NC}"
echo "All commands are automatically traced with:"
echo "• Execution duration"
echo "• Success/failure status"
echo "• Structured JSON logging"
echo

echo -e "${YELLOW}📈 Demo 5: Real-time dashboard${NC}"
echo "Command: ./start-tracer.sh"
echo "Launches React dashboard at http://localhost:3000"
echo

echo -e "${YELLOW}🧪 Demo 6: Run tests${NC}"
echo "Command: ./test-e2e.sh help"
echo "Runs end-to-end tests for validation"
echo

echo -e "${GREEN}✨ Ready to use! Start with: nu -c \"source nu-scripts/main.nu; help commands\"${NC}"