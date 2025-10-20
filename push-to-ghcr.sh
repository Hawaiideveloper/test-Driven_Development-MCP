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

# Configuration
GITHUB_USER="hawaiideveloper"
REPO_NAME="test-driven-development-mcp"
IMAGE_NAME="tdd-mcp"
IMAGE_TAG="${1:-latest}"
GHCR_IMAGE="ghcr.io/${GITHUB_USER}/${IMAGE_NAME}"

print_message "$BLUE" "==================================="
print_message "$BLUE" "Push to GitHub Container Registry"
print_message "$BLUE" "==================================="

# Check if user is logged in to GHCR
print_message "$BLUE" "\n🔐 Checking GitHub Container Registry login..."
if ! docker login ghcr.io --username ${GITHUB_USER} --password-stdin < /dev/null 2>&1 | grep -q "Login Succeeded\|Authenticating"; then
    print_message "$YELLOW" "You need to log in to GitHub Container Registry"
    print_message "$YELLOW" "\nTo create a Personal Access Token (PAT):"
    print_message "$YELLOW" "1. Go to: https://github.com/settings/tokens"
    print_message "$YELLOW" "2. Click 'Generate new token (classic)'"
    print_message "$YELLOW" "3. Select scopes: write:packages, read:packages, delete:packages"
    print_message "$YELLOW" "4. Generate token and copy it"
    print_message "$YELLOW" "\nThen run:"
    print_message "$GREEN" "  echo \$GITHUB_TOKEN | docker login ghcr.io -u ${GITHUB_USER} --password-stdin"
    print_message "$YELLOW" "\nOr login interactively:"
    print_message "$GREEN" "  docker login ghcr.io -u ${GITHUB_USER}"
    exit 1
fi

# Build the image
print_message "$BLUE" "\n📦 Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
print_message "$GREEN" "✓ Docker image built successfully"

# Tag for GHCR
print_message "$BLUE" "\n🏷️  Tagging image for GHCR..."
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${GHCR_IMAGE}:${IMAGE_TAG}
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${GHCR_IMAGE}:latest
print_message "$GREEN" "✓ Image tagged as:"
print_message "$GREEN" "  - ${GHCR_IMAGE}:${IMAGE_TAG}"
print_message "$GREEN" "  - ${GHCR_IMAGE}:latest"

# Push to GHCR
print_message "$BLUE" "\n🚀 Pushing to GitHub Container Registry..."
docker push ${GHCR_IMAGE}:${IMAGE_TAG}
docker push ${GHCR_IMAGE}:latest
print_message "$GREEN" "✓ Images pushed successfully"

print_message "$GREEN" "\n✅ Complete!"
print_message "$BLUE" "\nYour image is now available at:"
print_message "$YELLOW" "  ${GHCR_IMAGE}:${IMAGE_TAG}"
print_message "$YELLOW" "  ${GHCR_IMAGE}:latest"

print_message "$BLUE" "\n📝 To make the image public (recommended for easier access):"
print_message "$YELLOW" "1. Go to: https://github.com/${GITHUB_USER}?tab=packages"
print_message "$YELLOW" "2. Click on '${IMAGE_NAME}'"
print_message "$YELLOW" "3. Click 'Package settings'"
print_message "$YELLOW" "4. Scroll down to 'Change package visibility'"
print_message "$YELLOW" "5. Change to 'Public'"

print_message "$BLUE" "\n🎯 Next steps:"
print_message "$YELLOW" "  Run: ./helmdeploy.sh"
