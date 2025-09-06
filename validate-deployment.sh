#!/bin/bash
set -e

echo "🧪 LLMCLI Deployment Validation Script"
echo "====================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "ℹ️  $1"
}

echo ""
echo "1. Helm Chart Validation"
echo "------------------------"

# Test Helm chart linting
print_info "Testing Helm chart linting..."
helm lint . -f values.yaml.clean >/dev/null 2>&1
print_status "Helm lint passed"

# Test template rendering with clean values
print_info "Testing template rendering with clean values..."
helm template llmcli . -f values.yaml.clean >/dev/null 2>&1
print_status "Template rendering with clean values works"

# Test template rendering with secure values
print_info "Testing template rendering with secure values..."
helm template llmcli . -f values.yaml.secure >/dev/null 2>&1
print_status "Template rendering with secure values works"

# Check for hardcoded secrets in templates
print_info "Scanning templates for hardcoded secrets..."
if grep -r -E "(api[_-]?key|token|secret|password).*[:=].*['\"][^{]" templates/ 2>/dev/null | grep -v -E "(passwordAuthentication|permitRootLogin|runAsNonRoot)" ; then
    print_status "FOUND HARDCODED SECRETS IN TEMPLATES"
    exit 1
fi
print_status "No hardcoded secrets found in templates"

echo ""
echo "2. ArgoCD Application Validation"
echo "-------------------------------"

# Validate ArgoCD application syntax
print_info "Validating ArgoCD application YAML..."
kubectl apply --dry-run=client -f argocd/application.yaml >/dev/null 2>&1
print_status "ArgoCD application YAML is valid"

# Check if values.yaml.secure exists (referenced by ArgoCD app)
if [ -f "values.yaml.secure" ]; then
    print_status "values.yaml.secure file exists (referenced by ArgoCD)"
else
    print_warning "values.yaml.secure file not found (referenced by ArgoCD)"
fi

echo ""
echo "3. Security Validation"
echo "---------------------"

# Check that sensitive files are in .gitignore
print_info "Checking .gitignore contains sensitive files..."
if grep -q "values.yaml.secure" .gitignore 2>/dev/null; then
    print_status "values.yaml.secure is in .gitignore"
else
    print_warning "values.yaml.secure should be added to .gitignore"
fi

if grep -q ".mcp.json" .gitignore 2>/dev/null; then
    print_status ".mcp.json is in .gitignore"
else
    print_warning ".mcp.json should be added to .gitignore"
fi

# Check values.yaml.clean has no hardcoded secrets
print_info "Scanning values.yaml.clean for hardcoded secrets..."
if grep -E "(api[_-]?key|token|secret|password).*[:=].*['\"][^{]" values.yaml.clean 2>/dev/null | grep -v -E "(password.*OVERRIDE|passwordAuthentication)" | grep -v "^#"; then
    print_status "FOUND HARDCODED SECRETS IN values.yaml.clean"
    exit 1
fi
print_status "values.yaml.clean contains no hardcoded secrets"

echo ""
echo "4. Container Image Validation"
echo "----------------------------"

# Check if Dockerfile.updated exists
if [ -f "Dockerfile.updated" ]; then
    print_status "Dockerfile.updated exists"
else
    print_warning "Dockerfile.updated not found"
fi

# Check GitHub Actions workflow
if [ -f ".github/workflows/build-and-push.yaml" ]; then
    print_status "GitHub Actions workflow exists"
    
    # Check if workflow references correct Dockerfile
    if grep -q "Dockerfile.updated" .github/workflows/build-and-push.yaml; then
        print_status "Workflow uses Dockerfile.updated"
    else
        print_warning "Workflow should use Dockerfile.updated"
    fi
else
    print_warning "GitHub Actions workflow not found"
fi

echo ""
echo "5. MCP Server Configuration"
echo "--------------------------"

# Check MCP template exists
if [ -f ".mcp.json.template" ]; then
    print_status ".mcp.json.template exists"
    
    # Check template uses environment variables
    if grep -q "\${" .mcp.json.template; then
        print_status "MCP template uses environment variable substitution"
    else
        print_warning "MCP template should use environment variables"
    fi
else
    print_warning ".mcp.json.template not found"
fi

echo ""
echo "🎉 Deployment Validation Complete!"
echo "=================================="

# Summary
echo ""
echo "📋 Deployment Options:"
echo "  • Direct Helm: helm install llmcli . -f values.yaml.secure --namespace ai"
echo "  • ArgoCD: kubectl apply -f argocd/application.yaml"
echo ""
echo "🔐 Security Notes:"
echo "  • All secrets externalized to Kubernetes secrets"
echo "  • No hardcoded credentials in repository"
echo "  • GitHub-safe configuration files provided"
echo ""
echo "🚀 CI/CD Ready:"
echo "  • Automated image builds on push to main/develop"
echo "  • Container registry: ghcr.io/redairforce/llmcli"
echo "  • Helm chart version: $(grep '^version:' Chart.yaml | cut -d' ' -f2)"