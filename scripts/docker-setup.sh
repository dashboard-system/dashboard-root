#!/bin/bash

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logger.sh"

# Configuration
DOCKER_COMPOSE_VERSION="2.24.5"

# Check if Docker is installed
check_docker_installed() {
    if command -v docker &> /dev/null; then
        local version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "Docker is installed (version: $version)"
        return 0
    else
        log_info "Docker is not installed"
        return 1
    fi
}

# Check if Docker Compose is installed
check_docker_compose_installed() {
    if command -v docker-compose &> /dev/null; then
        local version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "Docker Compose is installed (version: $version)"
        return 0
    else
        log_info "Docker Compose is not installed"
        return 1
    fi
}

# Install Docker on Amazon Linux 2/2023
install_docker() {
    print_section "Installing Docker"
    
    log_info "Updating system packages..."
    sudo yum update -y
    
    log_info "Installing Docker..."
    sudo yum install -y docker
    
    log_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log_info "Adding user to docker group..."
    sudo usermod -a -G docker $USER
    
    # Verify installation
    if docker --version &> /dev/null; then
        print_success "Docker installed successfully"
        print_warning "Please log out and log back in for group changes to take effect"
        return 0
    else
        print_error "Docker installation failed"
        return 1
    fi
}

# Install Docker Compose
install_docker_compose() {
    print_section "Installing Docker Compose"
    
    log_info "Downloading Docker Compose v$DOCKER_COMPOSE_VERSION..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    
    log_info "Making Docker Compose executable..."
    sudo chmod +x /usr/local/bin/docker-compose
    
    log_info "Creating symlink..."
    sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Verify installation
    if docker-compose --version &> /dev/null; then
        print_success "Docker Compose installed successfully"
        return 0
    else
        print_error "Docker Compose installation failed"
        return 1
    fi
}

# Create Docker configuration files
create_docker_files() {
    print_section "Creating Docker Configuration Files"
    
    local project_root="${1:-.}"
    
    # Create directories
    log_info "Creating directories..."
    mkdir -p "$project_root/docker/nginx"
    mkdir -p "$project_root/backups"
    mkdir -p "$project_root/logs"
    
    # Create Dockerfile
    log_info "Creating Dockerfile..."
    cat > "$project_root/Dockerfile" << 'EOF'
FROM node:18-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

FROM node:18-alpine AS production

RUN apk update && apk upgrade && apk add --no-cache dumb-init
RUN addgroup -g 1001 -S nodejs && adduser -S dashboard -u 1001

WORKDIR /app
COPY --from=builder --chown=dashboard:nodejs /app/dist ./dist
COPY --from=builder --chown=dashboard:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=dashboard:nodejs /app/package*.json ./

RUN mkdir -p /app/db /app/logs && chown -R dashboard:nodejs /app

USER dashboard
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })" || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/index.js"]
EOF
    
    # Create docker-compose.yml
    log_info "Creating docker-compose.yml..."
    cat > "$project_root/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  dashboard-webserver:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    container_name: dashboard-webserver
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_PATH=/app/db/sqlite.db
      - JWT_SECRET=${JWT_SECRET}
      - PORT=3000
      - HOST=0.0.0.0
    volumes:
      - dashboard-data:/app/db
      - dashboard-logs:/app/logs
    networks:
      - dashboard-network
    healthcheck:
      test: ["CMD", "node", "-e", "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  dashboard-data:
    driver: local
  dashboard-logs:
    driver: local

networks:
  dashboard-network:
    driver: bridge
EOF
    
    # Create .dockerignore
    log_info "Creating .dockerignore..."
    cat > "$project_root/.dockerignore" << 'EOF'
node_modules
npm-debug.log
dist
.git
.gitignore
README.md
.env*
coverage
.nyc_output
.cache
logs
*.log
src/**/*.test.ts
src/**/*.spec.ts
jest.config.js
.eslintrc.js
.prettierrc
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
EOF
    
    print_success "Docker configuration files created"
}

# Main Docker setup function
setup_docker() {
    print_header "Docker Setup"
    
    local project_root="${1:-.}"
    local force_install="${2:-false}"
    
    # Check current installation
    if ! check_docker_installed || [ "$force_install" = "true" ]; then
        if ! install_docker; then
            print_error "Failed to install Docker"
            return 1
        fi
    fi
    
    if ! check_docker_compose_installed || [ "$force_install" = "true" ]; then
        if ! install_docker_compose; then
            print_error "Failed to install Docker Compose"
            return 1
        fi
    fi
    
    # Create Docker configuration files
    create_docker_files "$project_root"
    
    print_success "Docker setup completed successfully"
    return 0
}

# CLI interface
case "${1:-setup}" in
    "check")
        print_header "Docker Status Check"
        check_docker_installed && check_docker_compose_installed
        ;;
    "install-docker")
        install_docker
        ;;
    "install-compose")
        install_docker_compose
        ;;
    "create-files")
        create_docker_files "${2:-.}"
        ;;
    "setup")
        setup_docker "${2:-.}" "${3:-false}"
        ;;
    *)
        echo "Usage: $0 {check|install-docker|install-compose|create-files|setup} [project_root] [force]"
        exit 1
        ;;
esac