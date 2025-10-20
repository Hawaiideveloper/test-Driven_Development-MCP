#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="test-driven-development"
SERVICE_NAME="tdd-mcp"
NODEPORT="30234"
INTERNAL_PORT="63777"

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print banner
print_banner() {
    print_message "$BLUE" "=================================="
    print_message "$BLUE" "TDD-MCP Kubernetes Connection Tool"
    print_message "$BLUE" "=================================="
    echo ""
}

# Check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_message "$RED" "Error: kubectl is not installed or not in PATH"
        exit 1
    fi
    print_message "$GREEN" "✓ kubectl is available"
}

# Check if cluster is accessible
check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_message "$RED" "Error: Cannot connect to Kubernetes cluster"
        print_message "$YELLOW" "Please check your kubeconfig and cluster connection"
        exit 1
    fi
    print_message "$GREEN" "✓ Kubernetes cluster is accessible"
}

# Get node IPs
get_node_ips() {
    print_message "$BLUE" "\n🖥️  Available Cluster Nodes:"
    kubectl get nodes -o wide | grep -E "NAME|Ready" | head -10
    
    # Get first node IP
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
        print_message "$RED" "Error: Could not get node IP"
        exit 1
    fi
    
    print_message "$GREEN" "\n✓ Using node IP: $NODE_IP"
}

# Check service status
check_service() {
    print_message "$BLUE" "\n🔍 Checking TDD-MCP service status..."
    
    if ! kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME" &> /dev/null; then
        print_message "$RED" "Error: Service $SERVICE_NAME not found in namespace $NAMESPACE"
        print_message "$YELLOW" "Please deploy the service first using:"
        print_message "$YELLOW" "  helm upgrade --install tdd-mcp ./helm/tdd-mcp --namespace $NAMESPACE --create-namespace"
        exit 1
    fi
    
    kubectl get svc -n "$NAMESPACE" "$SERVICE_NAME"
    print_message "$GREEN" "✓ Service is running"
}

# Check pod status
check_pods() {
    print_message "$BLUE" "\n📦 Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tdd-mcp
    
    # Check if pods are ready
    READY_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=tdd-mcp -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
    if [[ "$READY_PODS" != *"True"* ]]; then
        print_message "$YELLOW" "⚠️  Pods may not be ready yet. Checking logs..."
        kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=tdd-mcp --tail=5
    else
        print_message "$GREEN" "✓ Pods are ready"
    fi
}

# Test connectivity
test_connectivity() {
    print_message "$BLUE" "\n🌐 Testing connectivity..."
    
    BASE_URL="http://$NODE_IP:$NODEPORT"
    print_message "$YELLOW" "Base URL: $BASE_URL"
    
    # Test health endpoint
    print_message "$BLUE" "\n🔍 Testing /health endpoint..."
    if curl -s --max-time 10 "$BASE_URL/health" > /dev/null; then
        HEALTH_RESPONSE=$(curl -s "$BASE_URL/health")
        print_message "$GREEN" "✓ Health check passed: $HEALTH_RESPONSE"
    else
        print_message "$RED" "✗ Health check failed"
        return 1
    fi
    
    # Test introduce endpoint
    print_message "$BLUE" "\n🔍 Testing /introduce endpoint..."
    INTRODUCE_RESPONSE=$(curl -s -X POST "$BASE_URL/introduce" \
        -H "Content-Type: application/json" \
        -d '{"repoPath": "/work"}' || echo "Failed")
    
    if [ "$INTRODUCE_RESPONSE" != "Failed" ] && [ -n "$INTRODUCE_RESPONSE" ]; then
        print_message "$GREEN" "✓ Introduce endpoint is working"
        echo "Response: $INTRODUCE_RESPONSE"
    else
        print_message "$YELLOW" "⚠️  Introduce endpoint may not be responding as expected"
    fi
}

# Show connection information
show_connection_info() {
    print_message "$GREEN" "\n🎉 Connection Information:"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$YELLOW" "Base URL: http://$NODE_IP:$NODEPORT"
    print_message "$YELLOW" "Health:   http://$NODE_IP:$NODEPORT/health"
    print_message "$YELLOW" "Namespace: $NAMESPACE"
    print_message "$YELLOW" "Service:   $SERVICE_NAME"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    print_message "$GREEN" "\n📋 Example API calls:"
    echo ""
    print_message "$BLUE" "# Health check"
    echo "curl http://$NODE_IP:$NODEPORT/health"
    echo ""
    print_message "$BLUE" "# Introduce endpoint"
    echo "curl -X POST http://$NODE_IP:$NODEPORT/introduce \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"repoPath\": \"/work\"}'"
    echo ""
    print_message "$BLUE" "# Ensure checklist"
    echo "curl -X POST http://$NODE_IP:$NODEPORT/ensure-checklist \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"repoPath\": \"/work\", \"dryRun\": false, \"language\": \"python\"}'"
    echo ""
}

# Show logs function
show_logs() {
    print_message "$BLUE" "\n📋 Recent application logs:"
    kubectl logs -n "$NAMESPACE" -l app.kubernetes.io/name=tdd-mcp --tail=10
}

# Main execution
main() {
    print_banner
    
    # Pre-flight checks
    check_kubectl
    check_cluster
    
    # Get connection details
    get_node_ips
    check_service
    check_pods
    
    # Test connectivity
    if test_connectivity; then
        show_connection_info
        
        # Ask if user wants to see logs
        echo ""
        read -p "$(echo -e "${YELLOW}Would you like to see recent application logs? (y/N): ${NC}")" -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            show_logs
        fi
        
        print_message "$GREEN" "\n✅ TDD-MCP is ready for use!"
    else
        print_message "$RED" "\n❌ Connection test failed. Showing logs for troubleshooting:"
        show_logs
        exit 1
    fi
}

# Handle command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    print_banner
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Connect to TDD-MCP service running in Kubernetes cluster"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --logs         Show application logs only"
    echo "  --status       Show service and pod status only"
    echo ""
    echo "Examples:"
    echo "  $0                # Full connection check and test"
    echo "  $0 --logs         # Show recent logs"
    echo "  $0 --status       # Show service status"
    exit 0
elif [ "$1" = "--logs" ]; then
    check_kubectl
    show_logs
    exit 0
elif [ "$1" = "--status" ]; then
    check_kubectl
    check_cluster
    check_service
    check_pods
    exit 0
else
    main
fi