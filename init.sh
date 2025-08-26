#!/bin/bash

# Dashboard Project Initialization Script
# Refactored for better maintainability and modularity

# Get script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all utility modules
source "$SCRIPT_DIR/scripts/config.sh"
source "$SCRIPT_DIR/scripts/logger.sh"
source "$SCRIPT_DIR/scripts/error_handling.sh"
source "$SCRIPT_DIR/scripts/git.sh"
source "$SCRIPT_DIR/scripts/services.sh"
source "$SCRIPT_DIR/scripts/docker.sh"
source "$SCRIPT_DIR/scripts/summary.sh"


# Main initialization function
main_init() {
    setup_error_handling
    print_header "Dashboard Project Initialization"
    
    log_setup "Starting initialization process"
    print_info "Setup log: $SETUP_LOG"
    
    # Validate prerequisites
    set_error_context "Prerequisites validation"
    validate_prerequisites || return $?
    clear_error_context
    
    # Initialize git submodules
    set_error_context "Git submodules initialization"
    init_submodules || return $?
    clear_error_context
    
    # Check Docker installation
    set_error_context "Docker validation"
    check_docker || return $?
    clear_error_context
    
    # Initialize services
    set_error_context "Services initialization"
    init_services || return $?
    clear_error_context
    
    # Create docker-compose configuration
    set_error_context "Docker compose configuration"
    create_docker_compose || return $?
    clear_error_context
    
    # Try to start services (non-fatal if it fails)
    set_error_context "Services startup"
    disable_error_handling  # Allow this to fail gracefully
    if ! start_services; then
        print_warning "Service startup had issues, but initialization components completed successfully"
    fi
    enable_error_handling
    clear_error_context
    
    # Show final status
    show_init_summary
    show_available_commands
    
    log_setup "Initialization completed successfully"
    return 0
}


# Main script logic
main() {
    local command="${1:-init}"
    
    case "$command" in
        "init")
            main_init
            ;;
        "start")
            setup_error_handling
            print_header "Starting Services"
            safe_execute "Starting Docker services" docker-compose up -d
            check_services_health
            ;;
        "stop")
            setup_error_handling
            stop_services
            ;;
        "restart")
            setup_error_handling
            restart_services
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$2"
            ;;
        "clean")
            setup_error_handling
            clean_all
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit $EXIT_INVALID_ARG
            ;;
    esac
}

# Execute main function with all arguments
main "$@"