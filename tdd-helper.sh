#!/bin/bash
#
# TDD-MCP Quick Helper Script
#
# Add this script to any repository to quickly connect to TDD-MCP
# 
# Usage:
#   wget https://raw.githubusercontent.com/Hawaiideveloper/test-Driven_Development-MCP/main/tdd-helper.sh
#   chmod +x tdd-helper.sh
#   ./tdd-helper.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration (auto-detected or configurable)
TDD_MCP_BASE_URL=""
REPO_PATH="$(pwd)"

# Print colored message
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print banner
print_banner() {
    print_message "$CYAN" "╔══════════════════════════════════════════════════╗"
    print_message "$CYAN" "║              TDD-MCP Quick Helper                ║"
    print_message "$CYAN" "║          Rapid TDD Workflow Activation          ║"
    print_message "$CYAN" "╚══════════════════════════════════════════════════╝"
    echo ""
    print_message "$BLUE" "Repository: $(basename "$REPO_PATH")"
    print_message "$BLUE" "Path: $REPO_PATH"
    echo ""
}

# Auto-detect TDD-MCP connection
detect_tdd_mcp() {
    print_message "$BLUE" "🔍 Auto-detecting TDD-MCP connection..."
    
    # Check common local Docker ports
    for port in 63777 8080 3000; do
        if curl -s --max-time 3 "http://localhost:$port/health" >/dev/null 2>&1; then
            TDD_MCP_BASE_URL="http://localhost:$port"
            print_message "$GREEN" "✓ Found TDD-MCP at: $TDD_MCP_BASE_URL"
            return 0
        fi
    done
    
    # Check for running Docker container
    if command -v docker >/dev/null 2>&1; then
        if docker ps --format '{{.Names}}' | grep -q "^TDD-MCP$"; then
            TDD_MCP_BASE_URL="http://localhost:63777"
            if curl -s --max-time 3 "$TDD_MCP_BASE_URL/health" >/dev/null 2>&1; then
                print_message "$GREEN" "✓ Found TDD-MCP Docker container at: $TDD_MCP_BASE_URL"
                return 0
            fi
        fi
    fi
    
    return 1
}

# Manual connection setup
manual_setup() {
    print_message "$YELLOW" "\n🔧 Manual TDD-MCP setup required"
    echo ""
    print_message "$BLUE" "Options:"
    print_message "$YELLOW" "  1. Start local Docker container:"
    echo "     docker run -d -p 63777:63777 -v \"\$(pwd):/work\" --name TDD-MCP ghcr.io/hawaiideveloper/tdd-mcp:latest"
    echo ""
    print_message "$YELLOW" "  2. Use start-mcp.sh script (recommended):"
    echo "     git clone https://github.com/Hawaiideveloper/test-Driven_Development-MCP.git ~/tdd-mcp"
    echo "     LANGUAGE=python ~/tdd-mcp/start-mcp.sh \$(pwd)"
    echo ""
    print_message "$YELLOW" "  3. Enter TDD-MCP URL manually:"
    read -p "TDD-MCP Base URL (or press Enter to skip): " manual_url
    
    if [ -n "$manual_url" ]; then
        TDD_MCP_BASE_URL="$manual_url"
        if curl -s --max-time 5 "$TDD_MCP_BASE_URL/health" >/dev/null 2>&1; then
            print_message "$GREEN" "✓ Connected to: $TDD_MCP_BASE_URL"
            return 0
        else
            print_message "$RED" "❌ Could not connect to: $TDD_MCP_BASE_URL"
            return 1
        fi
    fi
    
    return 1
}

# Initialize TDD workflow
initialize_tdd() {
    print_message "$BLUE" "\n🚀 Initializing TDD workflow for this repository..."
    
    # Introduce the repository to TDD-MCP
    print_message "$YELLOW" "Introducing repository to TDD-MCP..."
    INTRO_RESPONSE=$(curl -s -X POST "$TDD_MCP_BASE_URL/introduce" \
        -H "Content-Type: application/json" \
        -d "{\"repoPath\": \"$REPO_PATH\"}" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$INTRO_RESPONSE" ]; then
        print_message "$GREEN" "✓ Repository introduced successfully"
        echo "Response: $INTRO_RESPONSE"
    else
        print_message "$RED" "❌ Failed to introduce repository"
        return 1
    fi
    
    # Detect or prompt for language
    LANGUAGE=""
    if [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "pyproject.toml" ]; then
        LANGUAGE="python"
    elif [ -f "package.json" ]; then
        LANGUAGE="node"
    elif [ -f "go.mod" ]; then
        LANGUAGE="go"
    elif [ -f "Cargo.toml" ]; then
        LANGUAGE="rust"
    elif [ -f "pom.xml" ] || [ -f "build.gradle" ]; then
        LANGUAGE="java"
    elif [ -f "CMakeLists.txt" ] || [ -f "Makefile" ]; then
        LANGUAGE="cpp"
    fi
    
    if [ -z "$LANGUAGE" ]; then
        print_message "$YELLOW" "\n📝 What programming language is this project?"
        echo "Common options: python, node, go, rust, java, cpp"
        read -p "Language: " LANGUAGE
    else
        print_message "$GREEN" "✓ Auto-detected language: $LANGUAGE"
    fi
    
    # Create or ensure checklist
    print_message "$YELLOW" "\n📋 Creating TDD checklist..."
    CHECKLIST_RESPONSE=$(curl -s -X POST "$TDD_MCP_BASE_URL/ensure-checklist" \
        -H "Content-Type: application/json" \
        -d "{\"repoPath\": \"$REPO_PATH\", \"language\": \"$LANGUAGE\", \"dryRun\": false}" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$CHECKLIST_RESPONSE" ]; then
        print_message "$GREEN" "✓ TDD checklist created/updated"
        
        # Show created files
        if [ -f "CHECKLIST.md" ]; then
            print_message "$GREEN" "✓ CHECKLIST.md created"
        fi
        if [ -d ".mcp" ]; then
            print_message "$GREEN" "✓ .mcp/ directory created"
        fi
    else
        print_message "$RED" "❌ Failed to create checklist"
        return 1
    fi
}

# Show quick usage
show_usage() {
    print_message "$GREEN" "\n🎉 TDD-MCP is ready for this repository!"
    print_message "$CYAN" "════════════════════════════════════════════════════"
    print_message "$YELLOW" "📡 TDD-MCP Connection: $TDD_MCP_BASE_URL"
    print_message "$YELLOW" "📁 Repository: $(basename "$REPO_PATH")"
    print_message "$CYAN" "════════════════════════════════════════════════════"
    
    print_message "$GREEN" "\n📋 Quick Commands:"
    echo ""
    print_message "$BLUE" "# Check health"
    echo "curl $TDD_MCP_BASE_URL/health"
    echo ""
    print_message "$BLUE" "# View API documentation"
    echo "open $TDD_MCP_BASE_URL/docs  # or visit in browser"
    echo ""
    print_message "$BLUE" "# Start TDD workflow"
    echo "curl -X POST $TDD_MCP_BASE_URL/tdd/start \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -d '{\"repoPath\": \"$REPO_PATH\", \"language\": \"$LANGUAGE\"}'"
    echo ""
    print_message "$BLUE" "# Re-run this helper anytime"
    echo "./tdd-helper.sh"
    echo ""
    
    if [ -f "CHECKLIST.md" ]; then
        print_message "$GREEN" "📝 Next steps:"
        print_message "$YELLOW" "  1. Review CHECKLIST.md"
        print_message "$YELLOW" "  2. Follow TDD workflow items"
        print_message "$YELLOW" "  3. Run tests and iterate"
    fi
}

# Create a simple .tdd-mcp config file
create_config() {
    cat > ".tdd-mcp-config" << EOF
# TDD-MCP Configuration for this repository
TDD_MCP_BASE_URL=$TDD_MCP_BASE_URL
LANGUAGE=$LANGUAGE
REPO_PATH=$REPO_PATH
CONFIGURED_DATE=$(date)
EOF
    print_message "$GREEN" "✓ Created .tdd-mcp-config"
}

# Main execution
main() {
    print_banner
    
    # Check if already configured
    if [ -f ".tdd-mcp-config" ]; then
        source ".tdd-mcp-config"
        print_message "$GREEN" "✓ Found existing TDD-MCP configuration"
        print_message "$BLUE" "Configured: $CONFIGURED_DATE"
        
        if [ -n "$TDD_MCP_BASE_URL" ]; then
            if curl -s --max-time 5 "$TDD_MCP_BASE_URL/health" >/dev/null 2>&1; then
                print_message "$GREEN" "✓ TDD-MCP is accessible: $TDD_MCP_BASE_URL"
                show_usage
                exit 0
            else
                print_message "$YELLOW" "⚠️  Configured TDD-MCP not accessible, reconfiguring..."
            fi
        fi
    fi
    
    # Auto-detect or manual setup
    if ! detect_tdd_mcp; then
        if ! manual_setup; then
            print_message "$RED" "❌ Could not establish TDD-MCP connection"
            exit 1
        fi
    fi
    
    # Initialize TDD workflow
    if initialize_tdd; then
        create_config
        show_usage
    else
        print_message "$RED" "❌ Failed to initialize TDD workflow"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        print_message "$CYAN" "TDD-MCP Quick Helper Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -h, --help    Show this help"
        echo "  --reset       Reset configuration and reconfigure"
        echo ""
        echo "This script automatically:"
        echo "  • Detects local TDD-MCP Docker container"
        echo "  • Introduces your repository to TDD-MCP"
        echo "  • Creates TDD checklist for your project"
        echo "  • Provides quick usage commands"
        exit 0
        ;;
    --reset)
        rm -f ".tdd-mcp-config"
        print_message "$YELLOW" "Configuration reset, reconfiguring..."
        main
        ;;
    *)
        main
        ;;
esac