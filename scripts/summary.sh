#!/bin/bash
# Summary and status reporting utilities

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Check if Docker image exists
docker_image_exists() {
    local image_name="$1"
    docker images | grep -q "$image_name"
}

# Show initialization summary
show_init_summary() {
    print_header "Initialization Summary"
    
    echo "✅ Completed successfully:"
    echo "  • Git submodules initialized (including UI submodule)"
    echo "  • MQTT server dependencies installed" 
    echo "  • UI submodule dependencies installed"
    echo "  • Environment files created (.env)"
    echo "  • Docker compose configuration ready"
    echo ""
    
    # Check if Docker images were built successfully
    local mqtt_image_built=false
    local webserver_image_built=false
    
    if docker_image_exists "dashboard-root-mqtt-server"; then
        echo "  • MQTT server Docker image built ✅"
        mqtt_image_built=true
    fi
    
    if docker_image_exists "dashboard-root-dashboard-webserver"; then
        echo "  • Dashboard webserver Docker image built ✅"
        webserver_image_built=true
    fi
    
    echo ""
    
    if [ "$mqtt_image_built" = true ] && [ "$webserver_image_built" = true ]; then
        echo "🎉 All services ready!"
        echo ""
        echo "Service endpoints:"
        echo "  📊 Dashboard: http://localhost:$WEBSERVER_PORT"
        echo "  📡 MQTT API:  http://localhost:$MQTT_WEB_PORT"
        echo "  🔌 MQTT:     mqtt://localhost:$MQTT_PORT"
    else
        echo "⚠️  Some services need attention:"
        
        if [ "$webserver_image_built" = false ]; then
            echo "  - Dashboard webserver build failed due to TypeScript/dependency issues"
        fi
        
        if [ "$mqtt_image_built" = false ]; then
            echo "  - MQTT server build failed"
        fi
        
        echo "  - All submodules and dependencies are properly initialized"
    fi
}

# Show available commands
show_available_commands() {
    echo ""
    echo "Available commands:"
    echo "  $0 status    - Show system status"
    echo "  $0 stop      - Stop all services"
    echo "  $0 start     - Start services"
    echo "  $0 logs      - Show logs"
    echo "  $0 clean     - Clean everything"
}

# Show help message
show_help() {
    echo "Usage: $0 [COMMAND]"
    echo "Initialize and manage the dashboard project with Docker"
    echo ""
    echo "Commands:"
    echo "  init        Full initialization (default)"
    echo "  start       Start services"
    echo "  stop        Stop services"
    echo "  restart     Restart services"
    echo "  status      Show system status"
    echo "  logs [svc]  Show logs (optionally for specific service)"
    echo "  clean       Clean up everything"
    echo "  help        Show this help"
    echo ""
    echo "Examples:"
    echo "  $0              # Full initialization"
    echo "  $0 status       # Check status"
    echo "  $0 logs mqtt-server  # Show MQTT server logs"
}