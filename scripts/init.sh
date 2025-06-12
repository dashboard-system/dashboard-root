#!/bin/bash

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source logging utilities
source "$SCRIPT_DIR/lib/logger.sh"

# Configuration
PROJECT_ROOT="$(pwd)"
SETUP_LOG="$PROJECT_ROOT/setup.log"

# Function to log all output
log_setup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$SETUP_LOG"
}

# Main initialization function
main_init() {
    print_header "Dashboard Webserver Initialization"
    
    log_setup "Starting initialization process"
    print_info "Setup log: $SETUP_LOG"
    
    print_step 1 "Installing Docker and Docker Compose"
    if "$SCRIPT_DIR/docker-setup.sh" setup "$PROJECT_ROOT"; then
        print_success "Docker setup completed"
        log_setup "Docker setup: SUCCESS"
    else
        print_error "Docker setup failed"
        log_setup "Docker setup: FAILED"
        return 1
    fi
    
    print_step 2 "Setting up webserver project"
    if "$SCRIPT_DIR/webserver-setup.sh" setup "$PROJECT_ROOT"; then
        print_success "Webserver setup completed"
        log_setup "Webserver setup: SUCCESS"
    else
        print_error "Webserver setup failed"
        log_setup "Webserver setup: FAILED"
        return 1
    fi
    
    print_step 3 "Creating default authentication users"
    if "$SCRIPT_DIR/auth-setup.sh" create; then
        print_success "Authentication setup completed"
        log_setup "Auth setup: SUCCESS"
    else
        print_error "Authentication setup failed"
        log_setup "Auth setup: FAILED"
        return 1
    fi
    
    # Final setup summary
    print_header "Setup Complete!"
    
    echo -e "${GREEN}🎉 Dashboard Webserver initialized successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "  1. ${GREEN}npm run start${NC}          - Start the development server"
    echo -e "  2. ${GREEN}docker-compose up -d${NC}   - Start with Docker"
    echo -e "  3. ${GREEN}curl http://localhost:3000/health${NC} - Test the server"
    echo ""
    echo -e "${BLUE}Available scripts:${NC}"
    echo -e "  ${GREEN}./scripts/auth-setup.sh list${NC}     - Manage users"
    echo -e "  ${GREEN}./scripts/docker-setup.sh check${NC}  - Check Docker status"
    echo -e "  ${GREEN}./scripts/webserver-setup.sh check${NC} - Check requirements"
    echo ""
    echo -e "${BLUE}Log file:${NC} $SETUP_LOG"
    
    log_setup "Initialization completed successfully"
    return 0
}

# Quick start function
quick_start() {
    print_header "Quick Start"
    
    print_info "Running quick initialization with minimal prompts..."
    
    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Run all setup steps
    if main_init; then
        print_success "Quick start completed successfully"
        
        # Try to start the server
        if [ -f "package.json" ]; then
            print_info "Attempting to start the server..."
            npm run start &
            SERVER_PID=$!
            
            # Wait a bit and test
            sleep 10
            if curl -s http://localhost:3000/health > /dev/null; then
                print_success "Server started successfully! PID: $SERVER_PID"
                echo -e "${GREEN}Access your server at: http://localhost:3000${NC}"
            else
                print_warning "Server might still be starting..."
            fi
        fi
    else
        print_error "Quick start failed"
        return 1
    fi
}

# Check system status
check_status() {
    print_header "System Status Check"
    
    print_section "Docker Status"
    "$SCRIPT_DIR/scripts/docker-setup.sh" check
    
    print_section "Webserver Requirements"
    "$SCRIPT_DIR/scripts/webserver-setup.sh" check
    
    print_section "Authentication Status"
    "$SCRIPT_DIR/scripts/auth-setup.sh" check
    
    print_section "Server Status"
    if curl -s http://localhost:3000/health > /dev/null; then
        print_success "Server is running on localhost:3000"
        echo -e "${BLUE}Health status:${NC}"
        curl -s http://localhost:3000/health | jq . 2>/dev/null || curl -s http://localhost:3000/health
    else
        print_warning "Server is not running"
    fi
    
    print_section "Files Status"
    local files=(
        ".env"
        "tsconfig.json"
        "package.json"
        "Dockerfile"
        "docker-compose.yml"
        "src/index.ts"
        "src/database.ts"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_success "$file exists"
        else
            print_warning "$file missing"
        fi
    done
}

# Clean/reset everything
clean_reset() {
    print_header "Clean Reset"
    
    print_warning "This will remove all setup files and data!"
    
    if [ "$(confirm "Are you sure you want to reset everything?")" = "yes" ]; then
        print_info "Stopping any running containers..."
        docker-compose down 2>/dev/null || true
        
        print_info "Removing generated files..."
        rm -rf dist/ node_modules/ db/ logs/ .env .env.production
        
        print_info "Removing Docker images..."
        docker rmi dashboard-webserver 2>/dev/null || true
        
        print_success "Clean reset completed"
        print_info "Run './init.sh' to reinitialize"
    else
        print_info "Reset cancelled"
    fi
}

# Show help
show_help() {
    echo -e "Usage: ${GREEN}$0 [COMMAND]${NC}"
    echo "Initialize and manage the dashboard webserver project"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}init${NC}        Full initialization (default)"
    echo -e "  ${GREEN}quick${NC}       Quick start with minimal prompts"
    echo -e "  ${GREEN}status${NC}      Check system status"
    echo -e "  ${GREEN}reset${NC}       Clean reset everything"
    echo -e "  ${GREEN}docker${NC}      Docker setup only"
    echo -e "  ${GREEN}webserver${NC}   Webserver setup only"
    echo -e "  ${GREEN}auth${NC}        Authentication setup only"
    echo -e "  ${GREEN}help${NC}        Show this help"
    echo ""
    echo "Examples:"
    echo -e "  ${GREEN}$0${NC}              # Full initialization"
    echo -e "  ${GREEN}$0 quick${NC}        # Quick start"
    echo -e "  ${GREEN}$0 status${NC}       # Check everything"
    echo ""
    echo "Individual component management:"
    echo -e "  ${GREEN}./scripts/docker-setup.sh${NC}     - Docker management"
    echo -e "  ${GREEN}./scripts/webserver-setup.sh${NC}  - Webserver management"
    echo -e "  ${GREEN}./scripts/auth-setup.sh${NC}       - User management"
}

# Main script logic
case "${1:-init}" in
    "init")
        main_init
        ;;
    "quick")
        quick_start
        ;;
    "status"|"check")
        check_status
        ;;
    "reset"|"clean")
        clean_reset
        ;;
    "docker")
        "$SCRIPT_DIR/scripts/docker-setup.sh" setup "$PROJECT_ROOT"
        ;;
    "webserver")
        "$SCRIPT_DIR/scripts/webserver-setup.sh" setup "$PROJECT_ROOT"
        ;;
    "auth")
        "$SCRIPT_DIR/scripts/auth-setup.sh" create
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac