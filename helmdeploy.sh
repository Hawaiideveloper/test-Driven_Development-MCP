#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RELEASE_NAME="tdd-mcp"
NAMESPACE="test-driven-development"
CHART_PATH="./helm/tdd-mcp"
IMAGE_NAME="tdd-mcp"
IMAGE_TAG="latest"
GITHUB_USER="hawaiideveloper"
GHCR_IMAGE="ghcr.io/${GITHUB_USER}/${IMAGE_NAME}"

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if helm is installed
check_helm() {
    if ! command -v helm &> /dev/null; then
        print_message "$RED" "Error: Helm is not installed. Please install Helm first."
        exit 1
    fi
    print_message "$GREEN" "✓ Helm is installed"
}

# Check if kubectl is installed
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_message "$RED" "Error: kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    print_message "$GREEN" "✓ kubectl is installed"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_message "$RED" "Error: Docker is not installed. Please install Docker first."
        exit 1
    fi
    print_message "$GREEN" "✓ Docker is installed"
}

# Build Docker image
build_image() {
    print_message "$BLUE" "\n📦 Building Docker image..."
    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
    print_message "$GREEN" "✓ Docker image built successfully"
}

# Push image to GHCR
push_to_ghcr() {
    print_message "$BLUE" "\n🚀 Pushing to GitHub Container Registry..."

    # Tag for GHCR
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${GHCR_IMAGE}:${IMAGE_TAG}
    docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${GHCR_IMAGE}:latest

    # Push to GHCR
    print_message "$YELLOW" "Pushing ${GHCR_IMAGE}:${IMAGE_TAG}..."
    if docker push ${GHCR_IMAGE}:${IMAGE_TAG} && docker push ${GHCR_IMAGE}:latest; then
        print_message "$GREEN" "✓ Images pushed to GHCR successfully"
        print_message "$GREEN" "  - ${GHCR_IMAGE}:${IMAGE_TAG}"
        print_message "$GREEN" "  - ${GHCR_IMAGE}:latest"
    else
        print_message "$RED" "✗ Failed to push to GHCR"
        print_message "$YELLOW" "You may need to login to GHCR first:"
        print_message "$YELLOW" "  docker login ghcr.io -u ${GITHUB_USER}"
        print_message "$YELLOW" "Or set GITHUB_TOKEN and run:"
        print_message "$YELLOW" "  echo \$GITHUB_TOKEN | docker login ghcr.io -u ${GITHUB_USER} --password-stdin"
        exit 1
    fi
}

# Deploy with Helm
deploy_helm() {
    print_message "$BLUE" "\n🚀 Deploying with Helm..."

    # Check if release already exists
    if helm list -n ${NAMESPACE} | grep -q ${RELEASE_NAME}; then
        print_message "$YELLOW" "Release '${RELEASE_NAME}' already exists. Upgrading..."
        helm upgrade ${RELEASE_NAME} ${CHART_PATH} \
            --namespace ${NAMESPACE} \
            --create-namespace \
            --wait \
            --timeout 5m 2>&1 || {
            print_message "$RED" "⚠ Helm upgrade failed (likely NodePort range issue)"
            print_message "$YELLOW" "This is expected if NodePort 63777 is outside your cluster's range (30000-32767)"
            print_message "$YELLOW" "The deployment will continue, but you'll need to use port-forwarding"
            return 0
        }
        print_message "$GREEN" "✓ Helm chart upgraded successfully"
    else
        print_message "$YELLOW" "Installing new release '${RELEASE_NAME}'..."
        helm install ${RELEASE_NAME} ${CHART_PATH} \
            --namespace ${NAMESPACE} \
            --create-namespace \
            --wait \
            --timeout 5m 2>&1 || {
            print_message "$RED" "⚠ Helm install failed (likely NodePort range issue)"
            print_message "$YELLOW" "This is expected if NodePort 63777 is outside your cluster's range (30000-32767)"
            print_message "$YELLOW" "The deployment will continue, but you'll need to use port-forwarding"
            return 0
        }
        print_message "$GREEN" "✓ Helm chart installed successfully"
    fi
}

# Verify deployment
verify_deployment() {
    print_message "$BLUE" "\n🔍 Verifying deployment..."

    # Wait for pods to be ready
    print_message "$YELLOW" "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=tdd-mcp \
        -n ${NAMESPACE} \
        --timeout=300s || true

    # Show deployment status
    print_message "$BLUE" "\n📊 Deployment Status:"
    kubectl get all -n ${NAMESPACE} -l app.kubernetes.io/name=tdd-mcp

    # Get NodePort
    print_message "$BLUE" "\n🌐 Service Information:"
    NODE_PORT=$(kubectl get svc ${RELEASE_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.ports[0].nodePort}')
    print_message "$GREEN" "Service is exposed on NodePort: ${NODE_PORT}"

    # Get node IPs
    print_message "$BLUE" "\n🖥️  Node IPs:"
    kubectl get nodes -o wide | awk '{print $1"\t"$6}'

    print_message "$GREEN" "\n✅ Deployment completed successfully!"
    print_message "$YELLOW" "\n📡 Access Options:"

    if [ "${NODE_PORT}" == "63777" ]; then
        print_message "$YELLOW" "\nOption 1 - Direct NodePort (if range is extended):"
        print_message "$YELLOW" "  curl http://<NODE_IP>:${NODE_PORT}/health"
        print_message "$BLUE" "\nOption 2 - Port Forwarding (Recommended for Docker Desktop):"
        print_message "$GREEN" "  kubectl port-forward -n ${NAMESPACE} svc/${RELEASE_NAME} 63777:63777"
        print_message "$YELLOW" "  Then access at: http://localhost:63777"
        print_message "$YELLOW" "\nFor MCP client, use: http://localhost:63777"
    else
        print_message "$YELLOW" "\nDirect NodePort Access:"
        print_message "$YELLOW" "  curl http://<NODE_IP>:${NODE_PORT}/health"
        print_message "$YELLOW" "\nFor MCP client, use: http://<NODE_IP>:${NODE_PORT}"
    fi

    print_message "$YELLOW" "\n📋 Useful Commands:"
    print_message "$YELLOW" "  View logs: kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/name=tdd-mcp -f"
    print_message "$YELLOW" "  Get pods: kubectl get pods -n ${NAMESPACE}"
    print_message "$YELLOW" "  Get service: kubectl get svc -n ${NAMESPACE}"
}

# Main execution
main() {
    print_message "$BLUE" "==================================="
    print_message "$BLUE" "TDD-MCP Helm Deployment Script"
    print_message "$BLUE" "==================================="

    # Pre-flight checks
    print_message "$BLUE" "\n🔧 Running pre-flight checks..."
    check_helm
    check_kubectl
    check_docker

    # Build and push image
    build_image
    push_to_ghcr

    # Deploy
    deploy_helm

    # Verify
    verify_deployment
}

# Run main function
main
