#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_message "$BLUE" "==================================="
print_message "$BLUE" "Kubernetes NodePort Range Config"
print_message "$BLUE" "==================================="

# Detect the cluster type
if command -v docker &> /dev/null && docker info 2>/dev/null | grep -q "Docker Desktop"; then
    print_message "$YELLOW" "\nDetected Docker Desktop Kubernetes"
    print_message "$BLUE" "\nFor Docker Desktop, you need to modify the kube-apiserver configuration:"
    print_message "$YELLOW" "\n1. Create or edit: ~/.docker/daemon.json"
    print_message "$YELLOW" "   Add the following configuration:\n"
    cat <<'EOF'
{
  "kubernetes": {
    "apiserver": {
      "service-node-port-range": "30000-65535"
    }
  }
}
EOF
    print_message "$YELLOW" "\n2. Restart Docker Desktop"
    print_message "$YELLOW" "3. Verify with: kubectl cluster-info dump | grep service-node-port-range"
    print_message "$GREEN" "\nNote: Docker Desktop may not support custom apiserver flags."
    print_message "$GREEN" "If this doesn't work, you can use port-forwarding instead:"
    print_message "$YELLOW" "  kubectl port-forward -n test-driven-development svc/tdd-mcp 63777:63777"

elif command -v minikube &> /dev/null && minikube status &> /dev/null; then
    print_message "$YELLOW" "\nDetected Minikube cluster"
    print_message "$BLUE" "\nConfiguring Minikube to allow NodePort 63777..."

    # Stop minikube
    print_message "$YELLOW" "Stopping Minikube..."
    minikube stop

    # Start with extended NodePort range
    print_message "$YELLOW" "Starting Minikube with extended NodePort range..."
    minikube start --extra-config=apiserver.service-node-port-range=30000-65535

    print_message "$GREEN" "✓ Minikube configured with extended NodePort range (30000-65535)"
    print_message "$BLUE" "\nYou can now deploy with NodePort 63777"

elif command -v kind &> /dev/null && kind get clusters 2>/dev/null | grep -q .; then
    CLUSTER_NAME=$(kind get clusters | head -n 1)
    print_message "$YELLOW" "\nDetected Kind cluster: ${CLUSTER_NAME}"
    print_message "$BLUE" "\nFor Kind, you need to recreate the cluster with custom configuration."
    print_message "$YELLOW" "\n1. Create a file: kind-config.yaml with the following content:\n"
    cat <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        service-node-port-range: "30000-65535"
  extraPortMappings:
  - containerPort: 63777
    hostPort: 63777
    protocol: TCP
EOF
    print_message "$YELLOW" "\n2. Delete current cluster: kind delete cluster --name ${CLUSTER_NAME}"
    print_message "$YELLOW" "3. Create new cluster: kind create cluster --config kind-config.yaml --name ${CLUSTER_NAME}"
    print_message "$GREEN" "\nThis will allow NodePort 63777 to work with Kind"

else
    print_message "$YELLOW" "\nCouldn't detect cluster type"
    print_message "$BLUE" "\nGeneral instructions for extending NodePort range:"
    print_message "$YELLOW" "\n1. Edit kube-apiserver configuration"
    print_message "$YELLOW" "2. Add flag: --service-node-port-range=30000-65535"
    print_message "$YELLOW" "3. Restart kube-apiserver"
    print_message "$YELLOW" "\nLocation depends on your setup:"
    print_message "$YELLOW" "  - kubeadm: /etc/kubernetes/manifests/kube-apiserver.yaml"
    print_message "$YELLOW" "  - systemd: /etc/systemd/system/kube-apiserver.service"
fi

print_message "$BLUE" "\n==================================="
print_message "$GREEN" "Alternative: Use Port Forwarding"
print_message "$BLUE" "==================================="
print_message "$YELLOW" "\nIf you can't extend the NodePort range, you can use port-forwarding:"
print_message "$YELLOW" "  kubectl port-forward -n test-driven-development svc/tdd-mcp 63777:63777"
print_message "$YELLOW" "\nThen access at: http://localhost:63777"
