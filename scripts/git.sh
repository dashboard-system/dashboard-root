#!/bin/bash
# Git submodule utilities

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Check if we're in a git repository
is_git_repo() {
    git rev-parse --git-dir > /dev/null 2>&1
}

# Check if submodules are configured
has_submodules() {
    [ -f ".gitmodules" ]
}

# Check if submodule needs reinitialization
needs_reinit() {
    local need_force_reinit=false
    
    # Check if MQTT directory lacks source code
    if [ -d "$MQTT_DIR" ] && [ ! -f "$MQTT_DIR/package.json" ] && [ ! -f "$MQTT_DIR/Dockerfile" ]; then
        need_force_reinit=true
    fi
    
    # Check if webserver directory lacks source code
    if [ -d "$WEBSERVER_DIR" ] && [ ! -f "$WEBSERVER_DIR/package.json" ] && [ ! -f "$WEBSERVER_DIR/Dockerfile" ]; then
        need_force_reinit=true
    fi
    
    # Check if UI submodule is missing
    if [ -d "$WEBSERVER_DIR" ] && [ ! -d "$WEBSERVER_DIR/ui" ] || [ -d "$WEBSERVER_DIR/ui" ] && [ ! -f "$WEBSERVER_DIR/ui/package.json" ]; then
        need_force_reinit=true
    fi
    
    [ "$need_force_reinit" = true ]
}

# Backup environment files
backup_env_files() {
    print_info "Backing up environment files..."
    [ -f "$MQTT_DIR/.env" ] && cp "$MQTT_DIR/.env" "/tmp/mqtt_env_backup"
    [ -f "$WEBSERVER_DIR/.env" ] && cp "$WEBSERVER_DIR/.env" "/tmp/webserver_env_backup"
}

# Restore environment files
restore_env_files() {
    print_info "Restoring environment files..."
    [ -f "/tmp/mqtt_env_backup" ] && cp "/tmp/mqtt_env_backup" "$MQTT_DIR/.env" && rm "/tmp/mqtt_env_backup"
    [ -f "/tmp/webserver_env_backup" ] && cp "/tmp/webserver_env_backup" "$WEBSERVER_DIR/.env" && rm "/tmp/webserver_env_backup"
}

# Reinitialize submodules
reinit_submodules() {
    print_info "Detected incomplete submodule directories, reinitializing..."
    
    backup_env_files
    
    # Remove and re-initialize submodules
    git submodule deinit --force --all 2>/dev/null || true
    rm -rf .git/modules/* 2>/dev/null || true
    rm -rf "$MQTT_DIR" "$WEBSERVER_DIR"
}

# Update single submodule to latest main
update_submodule_to_main() {
    local submodule_dir="$1"
    local submodule_name="$2"
    
    if [ -d "$submodule_dir/.git" ]; then
        print_info "Updating $submodule_name to latest main..."
        cd "$submodule_dir"
        if git fetch origin && git checkout main && git pull origin main; then
            print_success "$submodule_name updated to latest main"
            cd "$PROJECT_ROOT"
            return 0
        else
            print_warning "Failed to update $submodule_name to latest main"
            cd "$PROJECT_ROOT"
            return 1
        fi
    fi
    return 0
}

# Update all submodules to latest code on main branch
update_submodules_to_latest() {
    local update_success=true
    
    # Update MQTT server submodule
    if ! update_submodule_to_main "$MQTT_DIR" "MQTT server"; then
        update_success=false
    fi
    
    # Update dashboard webserver submodule
    if ! update_submodule_to_main "$WEBSERVER_DIR" "dashboard webserver"; then
        update_success=false
    fi
    
    # Update UI submodule (nested within dashboard-webserver)
    if ! update_submodule_to_main "$WEBSERVER_DIR/ui" "UI submodule"; then
        update_success=false
    fi
    
    # Update the main repository's submodule references
    print_info "Updating submodule references in main repository..."
    if git submodule update --recursive --remote; then
        print_success "Submodule references updated"
    else
        print_warning "Failed to update submodule references"
        update_success=false
    fi
    
    [ "$update_success" = true ]
}

# Install npm dependencies for single submodule
install_npm_deps_for_submodule() {
    local submodule_dir="$1"
    local submodule_name="$2"
    
    if [ -f "$submodule_dir/package.json" ]; then
        print_info "Installing $submodule_name dependencies..."
        cd "$submodule_dir"
        if npm install; then
            print_success "$submodule_name dependencies installed"
            log_setup "$submodule_name npm install: SUCCESS"
        else
            print_warning "Failed to install $submodule_name dependencies"
            log_setup "$submodule_name npm install: FAILED"
        fi
        cd "$PROJECT_ROOT"
    fi
}

# Install npm dependencies for all submodules
install_submodule_deps() {
    print_info "Installing npm dependencies for submodules..."
    
    install_npm_deps_for_submodule "$MQTT_DIR" "MQTT server"
    install_npm_deps_for_submodule "$WEBSERVER_DIR" "webserver"
    install_npm_deps_for_submodule "$WEBSERVER_DIR/ui" "UI submodule"
    
    return 0
}

# Initialize git submodules
init_submodules() {
    print_step 1 "Initializing git submodules"
    
    # Check if we're in a git repository
    if ! is_git_repo; then
        print_warning "Not in a git repository. Skipping submodule initialization."
        log_setup "Submodule init: SKIPPED (not in git repo)"
        return 0
    fi
    
    # Check if submodules are configured
    if ! has_submodules; then
        print_info "No .gitmodules file found. Skipping submodule initialization."
        log_setup "Submodule init: SKIPPED (no .gitmodules)"
        return 0
    fi
    
    print_info "Initializing and updating submodules..."
    
    # Check if submodules need reinitialization
    if needs_reinit; then
        reinit_submodules
    fi
    
    if git submodule update --init --recursive; then
        print_success "Git submodules initialized successfully"
        
        # Update submodules to latest code on main branch
        print_info "Updating submodules to latest code on main branch..."
        if update_submodules_to_latest; then
            print_success "Submodules updated to latest code"
            log_setup "Submodule update: SUCCESS"
        else
            print_warning "Failed to update some submodules to latest code"
            log_setup "Submodule update: FAILED"
        fi
        
        log_setup "Submodule init: SUCCESS"
        
        # Restore .env files if they were backed up
        if needs_reinit; then
            restore_env_files
        fi
        
        # Install npm dependencies for submodules
        install_submodule_deps
        return 0
    else
        print_warning "Failed to initialize submodules, continuing anyway"
        log_setup "Submodule init: FAILED"
        return 0  # Don't fail the entire process
    fi
}