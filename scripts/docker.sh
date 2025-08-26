#!/bin/bash
# Docker utilities and operations

# Source required dependencies
source "$(dirname "${BASH_SOURCE[0]}")/logger.sh"
source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

# Check if Docker is installed and running
check_docker() {
    print_step 2 "Checking Docker installation"
    
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

# Check if required Dockerfiles exist
check_dockerfiles() {
    local missing_dockerfiles=()
    
    [ ! -f "$MQTT_DIR/Dockerfile" ] && missing_dockerfiles+=("$MQTT_DIR/Dockerfile")
    [ ! -f "$WEBSERVER_DIR/Dockerfile" ] && missing_dockerfiles+=("$WEBSERVER_DIR/Dockerfile")
    
    if [ ${#missing_dockerfiles[@]} -gt 0 ]; then
        print_warning "Missing Dockerfiles detected:"
        for dockerfile in "${missing_dockerfiles[@]}"; do
            print_warning "  - $dockerfile"
        done
        
        # Check if submodules might need initialization
        if [ -f ".gitmodules" ] && git rev-parse --git-dir > /dev/null 2>&1; then
            print_info "This might be due to uninitialized git submodules."
            print_info "Try running: git submodule update --init --recursive"
        fi
        
        print_info "Skipping Docker build step. Services will need to be configured separately."
        return 1
    fi
    
    return 0
}

# Create docker-compose.yml file
create_docker_compose() {
    print_step 5 "Creating master docker-compose configuration"
    
    cat > "$COMPOSE_FILE" << 'EOF'
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
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
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

# Build Docker images
build_images() {
    print_info "Building Docker images..."
    if docker-compose build; then
        print_success "Docker images built successfully"
        log_setup "Docker build: SUCCESS"
        return 0
    else
        print_error "Failed to build Docker images"
        print_warning "Common build issues:"
        print_info "  - dashboard-webserver: 'tsc not found' - missing TypeScript in production deps"
        print_info "  - webserver npm install: Python distutils missing for native modules"
        print_info "  - UI build: TypeScript compilation errors need fixing"
        print_info ""
        print_info "Solutions:"
        print_info "  1. Fix Dockerfile to install dev dependencies for build step"
        print_info "  2. Install Python setuptools: pip install setuptools"
        print_info "  3. Fix TypeScript errors in UI submodule"
        log_setup "Docker build: FAILED"
        return 1
    fi
}

# Start Docker services
start_services() {
    print_step 6 "Building and starting services"
    
    if check_dockerfiles; then
        if build_images; then
            print_info "Starting services..."
            if docker-compose up -d; then
                print_success "Services started successfully"
                log_setup "Services start: SUCCESS"
                
                # Wait for services to be healthy
                print_info "Waiting for services to be ready..."
                sleep 30
                check_services_health
                return 0
            else
                print_error "Failed to start services"
                log_setup "Services start: FAILED"
                return 1
            fi
        else
            return 1
        fi
    else
        print_warning "Cannot start services without Dockerfiles"
        print_info "Please ensure the following services have Dockerfiles:"
        print_info "  - mqtt_server/Dockerfile"
        print_info "  - dashboard-webserver/Dockerfile"
        log_setup "Services start: SKIPPED (missing Dockerfiles)"
        return 1
    fi
}

# Check service health
check_services_health() {
    print_info "Checking service health..."
    
    # Check MQTT server
    if curl -s http://localhost:$MQTT_WEB_PORT/health > /dev/null 2>&1; then
        print_success "MQTT server is healthy (port $MQTT_WEB_PORT)"
    else
        print_warning "MQTT server health check failed"
    fi
    
    # Check webserver
    if curl -s http://localhost:$WEBSERVER_PORT/health > /dev/null 2>&1; then
        print_success "Dashboard webserver is healthy (port $WEBSERVER_PORT)"
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

# Restart services
restart_services() {
    print_header "Restarting Services"
    docker-compose restart
    check_services_health
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
    
    if confirm "Are you sure?" "N" | grep -q "yes"; then
        docker-compose down -v --rmi all
        docker system prune -f
        print_success "Cleanup completed"
    else
        print_info "Cleanup cancelled"
    fi
}

# Show system status
show_status() {
    print_header "System Status"
    
    print_info "Docker containers:"
    docker-compose ps
    
    print_info "Service endpoints:"
    echo "  Dashboard Webserver: http://localhost:$WEBSERVER_PORT"
    echo "  MQTT Server Web API: http://localhost:$MQTT_WEB_PORT"
    echo "  MQTT Broker: mqtt://localhost:$MQTT_PORT"
    echo "  MQTT WebSocket: ws://localhost:$MQTT_WS_PORT"
    
    print_info "Health checks:"
    check_services_health
}