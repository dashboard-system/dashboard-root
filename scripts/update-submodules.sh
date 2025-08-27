#!/bin/bash

# Update all submodules to their latest commits
# This script updates 3 submodules:
# 1. dashboard-webserver (root level)
# 2. mqtt_server (root level)
# 3. ui (nested within dashboard-webserver)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to update a submodule
update_submodule() {
    local submodule_path="$1"
    local submodule_name="$2"
    
    log "Updating submodule: ${submodule_name}"
    
    if [ ! -d "$submodule_path" ]; then
        error "Submodule directory not found: $submodule_path"
        return 1
    fi
    
    cd "$submodule_path"
    
    # Check if it's a git repository
    if [ ! -d ".git" ] && [ ! -f ".git" ]; then
        error "Not a git repository: $submodule_path"
        return 1
    fi
    
    # Fetch latest changes
    log "Fetching latest changes for ${submodule_name}..."
    if ! git fetch origin; then
        error "Failed to fetch changes for ${submodule_name}"
        return 1
    fi
    
    # Get current branch
    current_branch=$(git branch --show-current)
    if [ -z "$current_branch" ]; then
        current_branch="main"
    fi
    
    # Update to latest commit on the branch
    log "Updating ${submodule_name} to latest ${current_branch}..."
    if ! git reset --hard "origin/${current_branch}"; then
        error "Failed to update ${submodule_name} to latest commit"
        return 1
    fi
    
    success "Successfully updated ${submodule_name}"
    
    # Return to original directory
    cd - > /dev/null
}

# Main execution
main() {
    log "Starting submodule update process..."
    
    # Store original directory
    original_dir=$(pwd)
    
    # Ensure we're in the project root
    if [ ! -f "docker-compose.yml" ] || [ ! -f ".gitmodules" ]; then
        error "Not in project root directory. Please run from dashboard-root directory."
        exit 1
    fi
    
    # Update root-level submodules first
    log "Updating root-level submodules..."
    
    # Initialize and update all submodules recursively
    git submodule update --init --recursive
    
    # Update dashboard-webserver submodule
    if update_submodule "dashboard-webserver" "dashboard-webserver"; then
        success "dashboard-webserver updated successfully"
    else
        error "Failed to update dashboard-webserver"
        exit 1
    fi
    
    # Update mqtt_server submodule
    if update_submodule "mqtt_server" "mqtt_server"; then
        success "mqtt_server updated successfully"
    else
        error "Failed to update mqtt_server"
        exit 1
    fi
    
    # Update nested UI submodule
    log "Updating nested UI submodule..."
    cd dashboard-webserver
    
    # Initialize UI submodule if needed
    if [ -f ".gitmodules" ]; then
        git submodule update --init --recursive
        
        if update_submodule "ui" "dashboard-ui"; then
            success "dashboard-ui updated successfully"
        else
            error "Failed to update dashboard-ui"
            cd "$original_dir"
            exit 1
        fi
    else
        warning "No .gitmodules found in dashboard-webserver"
    fi
    
    cd "$original_dir"
    
    # Show final status
    log "Final submodule status:"
    git submodule status --recursive
    
    success "All submodules updated successfully!"
    
    # Optional: Show what changed
    log "Recent commits in each submodule:"
    echo
    
    echo "=== dashboard-webserver ==="
    cd dashboard-webserver && git log --oneline -3 && cd ..
    echo
    
    echo "=== mqtt_server ==="
    cd mqtt_server && git log --oneline -3 && cd ..
    echo
    
    echo "=== dashboard-ui ==="
    cd dashboard-webserver/ui && git log --oneline -3 && cd ../..
    echo
    
    log "Update process completed successfully!"
}

# Run main function
main "$@"