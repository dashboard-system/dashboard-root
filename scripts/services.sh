#!/bin/bash
# Service initialization utilities

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Create directory if it doesn't exist
ensure_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_debug "Created directory: $dir"
    fi
}

# Create environment file from template
create_env_file() {
    local service_dir="$1"
    local env_content="$2"
    local env_file="$service_dir/.env"
    
    if [ ! -f "$env_file" ]; then
        print_info "Creating environment file: $env_file"
        echo "$env_content" > "$env_file"
        log_setup "Created .env file for $(basename "$service_dir")"
        return 0
    else
        print_debug "Environment file already exists: $env_file"
        return 1
    fi
}

# Initialize MQTT server
init_mqtt_server() {
    print_step 3 "Initializing MQTT server"
    
    if [ ! -d "$MQTT_DIR" ]; then
        print_error "MQTT server directory not found: $MQTT_DIR"
        return 1
    fi
    
    # Create environment file
    create_env_file "$MQTT_DIR" "$MQTT_ENV_TEMPLATE"
    
    # Create required directories
    ensure_directory "$MQTT_DIR/logs"
    ensure_directory "$MQTT_DIR/uci"
    ensure_directory "$MQTT_DIR/uci_backup"
    
    print_success "MQTT server initialized"
    log_setup "MQTT server init: SUCCESS"
    return 0
}

# Initialize webserver
init_webserver() {
    print_step 4 "Initializing webserver"
    
    if [ ! -d "$WEBSERVER_DIR" ]; then
        print_error "Webserver directory not found: $WEBSERVER_DIR"
        return 1
    fi
    
    # Generate webserver environment template with JWT secret
    local webserver_env_content
    webserver_env_content=$(generate_webserver_env_template)
    
    # Create environment file
    create_env_file "$WEBSERVER_DIR" "$webserver_env_content"
    
    # Create required directories
    ensure_directory "$WEBSERVER_DIR/db"
    ensure_directory "$WEBSERVER_DIR/logs"
    
    print_success "Webserver initialized"
    log_setup "Webserver init: SUCCESS"
    return 0
}

# Initialize all services
init_services() {
    local success=true
    
    if ! init_mqtt_server; then
        success=false
    fi
    
    if ! init_webserver; then
        success=false
    fi
    
    [ "$success" = true ]
}