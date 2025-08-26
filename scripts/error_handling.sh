#!/bin/bash
# Enhanced error handling utilities

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_MISUSE=2
readonly EXIT_PERMISSION=126
readonly EXIT_NOT_FOUND=127
readonly EXIT_INVALID_ARG=128
readonly EXIT_FATAL_ERROR=130

# Error context (bash 3 compatible)
ERROR_CONTEXT=""
ERROR_CLEANUP_FUNCTIONS=()

# Set error context for better error messages
set_error_context() {
    ERROR_CONTEXT="$1"
}

# Clear error context
clear_error_context() {
    ERROR_CONTEXT=""
}

# Add cleanup function to be called on error
add_cleanup_function() {
    ERROR_CLEANUP_FUNCTIONS+=("$1")
}

# Execute cleanup functions
execute_cleanup() {
    for cleanup_func in "${ERROR_CLEANUP_FUNCTIONS[@]}"; do
        print_debug "Executing cleanup function: $cleanup_func"
        $cleanup_func || true  # Don't fail if cleanup fails
    done
    ERROR_CLEANUP_FUNCTIONS=()
}

# Enhanced error handler
handle_error() {
    local exit_code=$1
    local line_number=${2:-"unknown"}
    local command=${3:-"unknown command"}
    
    print_error "Command failed with exit code $exit_code"
    print_error "Line: $line_number"
    print_error "Command: $command"
    
    if [ -n "$ERROR_CONTEXT" ]; then
        print_error "Context: $ERROR_CONTEXT"
    fi
    
    print_debug "Stack trace:"
    local frame=0
    while caller $frame; do
        ((frame++))
    done
    
    # Execute cleanup functions
    execute_cleanup
    
    log_setup "FATAL ERROR: $command (exit code: $exit_code, line: $line_number)"
    
    exit $exit_code
}

# Validate command exists
require_command() {
    local cmd="$1"
    local package="${2:-$cmd}"
    
    if ! command -v "$cmd" &> /dev/null; then
        print_error "Required command '$cmd' not found"
        print_info "Please install '$package' package"
        return $EXIT_NOT_FOUND
    fi
    return $EXIT_SUCCESS
}

# Validate file exists
require_file() {
    local file="$1"
    local description="${2:-file}"
    
    if [ ! -f "$file" ]; then
        print_error "Required $description not found: $file"
        return $EXIT_NOT_FOUND
    fi
    return $EXIT_SUCCESS
}

# Validate directory exists
require_directory() {
    local dir="$1"
    local description="${2:-directory}"
    
    if [ ! -d "$dir" ]; then
        print_error "Required $description not found: $dir"
        return $EXIT_NOT_FOUND
    fi
    return $EXIT_SUCCESS
}

# Validate argument is not empty
require_arg() {
    local arg="$1"
    local name="$2"
    
    if [ -z "$arg" ]; then
        print_error "Required argument '$name' is empty or not provided"
        return $EXIT_INVALID_ARG
    fi
    return $EXIT_SUCCESS
}

# Safe execution with context
safe_execute() {
    local context="$1"
    shift
    
    set_error_context "$context"
    
    print_debug "Executing: $*"
    
    if "$@"; then
        clear_error_context
        return $EXIT_SUCCESS
    else
        local exit_code=$?
        print_error "Failed to execute: $*"
        clear_error_context
        return $exit_code
    fi
}

# Retry mechanism for unreliable operations
retry_execute() {
    local max_attempts="$1"
    local delay="$2"
    local context="$3"
    shift 3
    
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        print_debug "Attempt $attempt/$max_attempts: $*"
        
        if safe_execute "$context" "$@"; then
            return $EXIT_SUCCESS
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            print_warning "Attempt $attempt failed, retrying in ${delay}s..."
            sleep "$delay"
        fi
        
        ((attempt++))
    done
    
    print_error "All $max_attempts attempts failed"
    return $EXIT_GENERAL_ERROR
}

# Validate prerequisites
validate_prerequisites() {
    local failed=false
    
    print_info "Validating prerequisites..."
    
    # Check required commands (wget not required on macOS, curl is sufficient)
    local required_commands=("git" "docker" "curl")
    for cmd in "${required_commands[@]}"; do
        if ! require_command "$cmd"; then
            failed=true
        fi
    done
    
    # Check for wget or curl (either is fine)
    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        print_error "Neither 'wget' nor 'curl' found. Please install one of them."
        failed=true
    fi
    
    # Check Docker daemon
    if ! docker info &>/dev/null; then
        print_error "Docker daemon is not running"
        failed=true
    fi
    
    if [ "$failed" = true ]; then
        print_error "Prerequisites validation failed"
        return $EXIT_GENERAL_ERROR
    fi
    
    print_success "All prerequisites validated"
    return $EXIT_SUCCESS
}

# Set up error trapping with enhanced handler
setup_error_handling() {
    set -eE  # Exit on error, inherit error traps in functions
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
    trap 'execute_cleanup; exit 130' INT  # Handle Ctrl+C
    trap 'execute_cleanup' EXIT  # Always cleanup on exit
}

# Disable error handling (for specific operations that may fail)
disable_error_handling() {
    set +eE
    trap - ERR
}

# Re-enable error handling
enable_error_handling() {
    setup_error_handling
}