#!/bin/bash

# Dashboard Project Initialization Script
# This script initializes the project with Docker support for MQTT server and webserver

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Source logging utilities if available
if [ -f "$SCRIPT_DIR/scripts/lib/logger.sh" ]; then
    source "$SCRIPT_DIR/scripts/lib/logger.sh"
else
    # Fallback logging functions
    print_success() { echo "✅ $1"; }
    print_error() { echo "❌ $1"; }
    print_warning() { echo "⚠️  $1"; }
    print_info() { echo "ℹ️  $1"; }
    print_header() { echo -e "\n=== $1 ===\n"; }
    print_step() { echo "Step $1: $2"; }
fi

# Configuration
SETUP_LOG="$PROJECT_ROOT/setup.log"
WEBSERVER_DIR="$PROJECT_ROOT/dashboard-webserver"
MQTT_DIR="$PROJECT_ROOT/mqtt_server"

# Log function
log_setup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$SETUP_LOG"
}

# Check if Docker is installed
check_docker() {
    print_step 1 "Checking Docker installation"
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        print_info "Visit: https://docs.docker.com/get-docker/"
        return 1
    fi
    
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        return 1
    fi
    
    # Test Docker daemon
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker."
        return 1
    fi
    
    print_success "Docker is installed and running"
    log_setup "Docker check: SUCCESS"
    return 0
}

# Initialize MQTT server
init_mqtt_server() {
    print_step 2 "Initializing MQTT server"
    
    if [ ! -d "$MQTT_DIR" ]; then
        print_error "MQTT server directory not found: $MQTT_DIR"
        return 1
    fi
    
    cd "$MQTT_DIR"
    
    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        print_info "Creating MQTT server .env file"
        cat > .env << 'EOF'
# MQTT Server Configuration
MQTT_PORT=1883
MQTT_WS_PORT=8883
WEB_PORT=3001
NODE_ENV=production

# Logging
LOG_LEVEL=info
LOG_FILE=./logs/mqtt-server.log

# UCI Configuration
UCI_BACKUP_DIR=./uci_backup
UCI_WATCH_INTERVAL=1000
EOF
        log_setup "Created MQTT .env file"
    fi
    
    # Create required directories
    mkdir -p logs uci uci_backup
    
    print_success "MQTT server initialized"
    log_setup "MQTT server init: SUCCESS"
    cd "$PROJECT_ROOT"
    return 0
}

# Initialize webserver
init_webserver() {
    print_step 3 "Initializing webserver"
    
    if [ ! -d "$WEBSERVER_DIR" ]; then
        print_error "Webserver directory not found: $WEBSERVER_DIR"
        return 1
    fi
    
    cd "$WEBSERVER_DIR"
    
    # Create .env file if it doesn't exist
    if [ ! -f ".env" ]; then
        print_info "Creating webserver .env file"
        
        # Generate JWT secret
        JWT_SECRET=$(openssl rand -base64 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
        
        cat > .env << EOF
# Dashboard Webserver Configuration
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database
DATABASE_PATH=./db/sqlite.db

# JWT Configuration
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=7d

# Logging
LOG_LEVEL=info
LOG_FILE=./logs/webserver.log
EOF
        log_setup "Created webserver .env file"
    fi
    
    # Create required directories
    mkdir -p db logs
    
    print_success "Webserver initialized"
    log_setup "Webserver init: SUCCESS"
    cd "$PROJECT_ROOT"
    return 0
}

# Create master docker-compose file
create_master_compose() {
    print_step 4 "Creating master docker-compose configuration"
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # MQTT Server
  mqtt-server:
    build:
      context: ./mqtt_server
      dockerfile: Dockerfile
    container_name: mqtt-server-container
    env_file:
      - ./mqtt_server/.env
    ports:
      - "1883:1883"    # MQTT
      - "8883:8883"    # MQTT WebSocket  
      - "3001:3001"    # Web server
    volumes:
      - ./mqtt_server/logs:/app/logs
      - ./mqtt_server/uci:/app/uci
      - ./mqtt_server/uci_backup:/app/uci_backup
    restart: unless-stopped
    networks:
      - dashboard-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Dashboard Webserver
  dashboard-webserver:
    build:
      context: ./dashboard-webserver
      dockerfile: Dockerfile
      target: production
    container_name: dashboard-webserver-container
    env_file:
      - ./dashboard-webserver/.env
    ports:
      - "3000:3000"
    volumes:
      - dashboard-data:/app/db
      - dashboard-logs:/app/logs
    restart: unless-stopped
    networks:
      - dashboard-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    depends_on:
      - mqtt-server

volumes:
  dashboard-data:
    driver: local
  dashboard-logs:
    driver: local

networks:
  dashboard-network:
    driver: bridge
EOF
    
    print_success "Master docker-compose.yml created"
    log_setup "Master compose file: SUCCESS"
    return 0
}

# Build and start services
start_services() {
    print_step 5 "Building and starting services"
    
    print_info "Building Docker images..."
    if docker-compose build; then
        print_success "Docker images built successfully"
        log_setup "Docker build: SUCCESS"
    else
        print_error "Failed to build Docker images"
        log_setup "Docker build: FAILED"
        return 1
    fi
    
    print_info "Starting services..."
    if docker-compose up -d; then
        print_success "Services started successfully"
        log_setup "Services start: SUCCESS"
    else
        print_error "Failed to start services"
        log_setup "Services start: FAILED"
        return 1
    fi
    
    # Wait for services to be healthy
    print_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    check_services_health
    
    return 0
}

# Check service health
check_services_health() {
    print_info "Checking service health..."
    
    # Check MQTT server
    if curl -s http://localhost:3001/health > /dev/null 2>&1; then
        print_success "MQTT server is healthy (port 3001)"
    else
        print_warning "MQTT server health check failed"
    fi
    
    # Check webserver
    if curl -s http://localhost:3000/health > /dev/null 2>&1; then
        print_success "Dashboard webserver is healthy (port 3000)"
    else
        print_warning "Dashboard webserver health check failed"
    fi
    
    # Show container status
    print_info "Container status:"
    docker-compose ps
}

# Stop services
stop_services() {
    print_header "Stopping Services"
    docker-compose down
    print_success "Services stopped"
}

# Show service logs
show_logs() {
    local service=${1:-}
    if [ -n "$service" ]; then
        docker-compose logs -f "$service"
    else
        docker-compose logs -f
    fi
}

# Clean up everything
clean_all() {
    print_header "Cleaning Up Everything"
    
    print_warning "This will remove all containers, images, and volumes!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v --rmi all
        docker system prune -f
        print_success "Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Show status
show_status() {
    print_header "System Status"
    
    print_info "Docker containers:"
    docker-compose ps
    
    print_info "Service endpoints:"
    echo "  Dashboard Webserver: http://localhost:3000"
    echo "  MQTT Server Web API: http://localhost:3001"
    echo "  MQTT Broker: mqtt://localhost:1883"
    echo "  MQTT WebSocket: ws://localhost:8883"
    
    print_info "Health checks:"
    check_services_health
}

# Main initialization function
main_init() {
    print_header "Dashboard Project Initialization"
    
    log_setup "Starting initialization process"
    print_info "Setup log: $SETUP_LOG"
    
    # Check prerequisites
    if ! check_docker; then
        return 1
    fi
    
    # Initialize components
    if ! init_mqtt_server; then
        return 1
    fi
    
    if ! init_webserver; then
        return 1
    fi
    
    if ! create_master_compose; then
        return 1
    fi
    
    if ! start_services; then
        return 1
    fi
    
    # Show final status
    print_header "Initialization Complete!"
    
    echo "🎉 Dashboard project initialized successfully!"
    echo ""
    echo "Service endpoints:"
    echo "  📊 Dashboard: http://localhost:3000"
    echo "  📡 MQTT API:  http://localhost:3001"
    echo "  🔌 MQTT:     mqtt://localhost:1883"
    echo ""
    echo "Available commands:"
    echo "  $0 status    - Show system status"
    echo "  $0 stop      - Stop all services"
    echo "  $0 start     - Start services"
    echo "  $0 logs      - Show logs"
    echo "  $0 clean     - Clean everything"
    
    log_setup "Initialization completed successfully"
    return 0
}

# Show help
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

# Main script logic
case "${1:-init}" in
    "init")
        main_init
        ;;
    "start")
        print_header "Starting Services"
        docker-compose up -d
        check_services_health
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        print_header "Restarting Services"
        docker-compose restart
        check_services_health
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "clean")
        clean_all
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