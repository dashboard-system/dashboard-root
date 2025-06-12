#!/bin/bash

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/logger.sh"

# Configuration
PROJECT_NAME="dashboard-webserver"
NODE_MIN_VERSION=16

# Check Node.js requirements
check_nodejs() {
    if command -v node &>/dev/null; then
        local version=$(node --version | grep -oE '[0-9]+' | head -1)
        if [ "$version" -ge "$NODE_MIN_VERSION" ]; then
            print_success "Node.js v$(node --version | sed 's/v//') (✅ >= v$NODE_MIN_VERSION)"
            return 0
        else
            print_warning "Node.js v$(node --version | sed 's/v//') (⚠️ recommend >= v$NODE_MIN_VERSION)"
            return 1
        fi
    else
        print_error "Node.js not found! Please install Node.js v$NODE_MIN_VERSION or higher"
        return 1
    fi
}

# Check npm
check_npm() {
    if command -v npm &>/dev/null; then
        print_success "npm v$(npm --version)"
        return 0
    else
        print_error "npm not found! Please install npm"
        return 1
    fi
}

# Create project directories
create_directories() {
    print_section "Creating Project Structure"

    local project_root="${1:-.}"

    local directories=(
        "src/routes"
        "src/middleware"
        "src/utils"
        "src/types"
        "db"
        "db/backups"
        "logs"
        "scripts"
        "dist"
        "tests"
        "docs"
    )

    for dir in "${directories[@]}"; do
        if mkdir -p "$project_root/$dir"; then
            log_file_operation "Created directory" "$dir" "success"
        else
            log_file_operation "Failed to create directory" "$dir" "error"
            return 1
        fi
    done

    print_success "Project directories created"
}

# Create environment files
create_environment_files() {
    print_section "Creating Environment Configuration"

    local project_root="${1:-.}"

    # Generate secure JWT secret
    local jwt_secret=$(openssl rand -base64 64 2>/dev/null || echo "change-this-secret-$(date +%s)-$(openssl rand -hex 16 2>/dev/null || echo 'fallback')")

    # Get public IP for CORS
    local public_ip=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "localhost")

    # Create .env.example
    log_info "Creating .env.example..."
    cat >"$project_root/.env.example" <<EOF
# Database Configuration
DATABASE_PATH=./db/sqlite.db
DB_TIMEOUT=60000

# JWT Configuration (CHANGE IN PRODUCTION!)
JWT_SECRET=your-super-secret-jwt-key-change-this-in-production

# Server Configuration
NODE_ENV=development
PORT=3000
HOST=0.0.0.0

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001

# Logging
LOG_LEVEL=info
LOG_DIR=./logs
EOF

    # Create .env if it doesn't exist
    if [ ! -f "$project_root/.env" ]; then
        log_info "Creating .env file..."
        cat >"$project_root/.env" <<EOF
# Database Configuration
DATABASE_PATH=./db/sqlite.db
DB_TIMEOUT=60000

# JWT Configuration
JWT_SECRET=$jwt_secret

# Server Configuration
NODE_ENV=development
PORT=3000
HOST=0.0.0.0

# CORS Configuration
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:3001,http://$public_ip

# Logging
LOG_LEVEL=info
LOG_DIR=./logs
EOF
        print_success "Environment file created with secure JWT secret"
    else
        print_warning ".env file already exists - not overwriting"
    fi

    # Create .env.production
    log_info "Creating .env.production..."
    cat >"$project_root/.env.production" <<EOF
# Production Environment Configuration
NODE_ENV=production
DATABASE_PATH=/app/db/sqlite.db
JWT_SECRET=$jwt_secret
PORT=3000
HOST=0.0.0.0
ALLOWED_ORIGINS=http://$public_ip,https://$public_ip
LOG_LEVEL=warn
LOG_DIR=/app/logs
EOF

    print_success "Environment files created"
}

# Create TypeScript configuration
create_typescript_config() {
    print_section "Creating TypeScript Configuration"

    local project_root="${1:-.}"

    if [ ! -f "$project_root/tsconfig.json" ]; then
        log_info "Creating tsconfig.json..."
        cat >"$project_root/tsconfig.json" <<'EOF'
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "lib": ["ES2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "removeComments": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "moduleResolution": "node",
    "allowSyntheticDefaultImports": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true
  },
  "include": [
    "src/**/*"
  ],
  "exclude": [
    "node_modules",
    "dist",
    "**/*.test.ts",
    "**/*.spec.ts"
  ]
}
EOF
        print_success "TypeScript configuration created"
    else
        print_warning "tsconfig.json already exists"
    fi
}

# Update package.json scripts
update_package_scripts() {
    print_section "Updating Package Scripts"

    local project_root="${1:-.}"

    if [ -f "$project_root/package.json" ]; then
        log_info "Updating package.json scripts..."

        # Use Node.js to update package.json
        node -e "
            const fs = require('fs');
            const path = '$project_root/package.json';
            
            try {
                const pkg = JSON.parse(fs.readFileSync(path, 'utf8'));
                
                if (!pkg.scripts) pkg.scripts = {};
                
                pkg.scripts = {
                    ...pkg.scripts,
                    'dev': 'nodemon --exec ts-node src/index.ts',
                    'build': 'tsc',
                    'start': 'tsc && node dist/index.js',
                    'start:prod': 'NODE_ENV=production node dist/index.js',
                    'test': 'jest',
                    'test:watch': 'jest --watch',
                    'test:coverage': 'jest --coverage',
                    'lint': 'eslint src/**/*.ts --fix',
                    'format': 'prettier --write src/**/*.ts',
                    'docker:build': 'docker build -t $PROJECT_NAME .',
                    'docker:run': 'docker run -p 3000:3000 $PROJECT_NAME',
                    'docker:up': 'docker-compose up -d',
                    'docker:down': 'docker-compose down'
                };
                
                fs.writeFileSync(path, JSON.stringify(pkg, null, 2));
                console.log('Package.json scripts updated successfully');
            } catch (error) {
                console.error('Failed to update package.json:', error.message);
                process.exit(1);
            }
        " && print_success "Package.json scripts updated" || print_warning "Could not update package.json scripts"
    else
        print_warning "package.json not found - please run 'npm init' first"
    fi
}

# Install dependencies
install_dependencies() {
    print_section "Installing Dependencies"

    local project_root="${1:-.}"

    if [ ! -f "$project_root/package.json" ]; then
        print_error "package.json not found! Please run 'npm init' first"
        return 1
    fi

    cd "$project_root"

    log_info "Installing production dependencies..."
    local prod_deps=(
        "better-sqlite3"
        "bcryptjs"
        "jsonwebtoken"
        "express"
        "cors"
        "helmet"
        "morgan"
        "dotenv"
    )

    if npm install "${prod_deps[@]}"; then
        print_success "Production dependencies installed"
    else
        print_error "Failed to install production dependencies"
        return 1
    fi

    log_info "Installing development dependencies..."
    local dev_deps=(
        "@types/node"
        "@types/express"
        "@types/better-sqlite3"
        "@types/bcryptjs"
        "@types/jsonwebtoken"
        "@types/cors"
        "typescript"
        "ts-node"
        "nodemon"
        "jest"
        "@types/jest"
        "eslint"
        "@typescript-eslint/parser"
        "@typescript-eslint/eslint-plugin"
        "prettier"
    )

    if npm install --save-dev "${dev_deps[@]}"; then
        print_success "Development dependencies installed"
    else
        print_error "Failed to install development dependencies"
        return 1
    fi

    cd - >/dev/null
}

# Main webserver setup function
setup_webserver() {
    print_header "Webserver Project Setup"

    local project_root="${1:-.}"
    local skip_deps="${2:-false}"

    # Check requirements
    if ! check_nodejs || ! check_npm; then
        print_error "System requirements not met"
        return 1
    fi

    # Create project structure
    if ! create_directories "$project_root"; then
        print_error "Failed to create project directories"
        return 1
    fi

    # Create configuration files
    create_environment_files "$project_root"
    create_typescript_config "$project_root"
    update_package_scripts "$project_root"

    # Install dependencies
    if [ "$skip_deps" != "true" ]; then
        if ! install_dependencies "$project_root"; then
            print_error "Failed to install dependencies"
            return 1
        fi
    fi

    print_success "Webserver setup completed successfully"
    return 0
}

# CLI interface
case "${1:-setup}" in
"check")
    print_header "System Requirements Check"
    check_nodejs && check_npm
    ;;
"dirs")
    create_directories "${2:-.}"
    ;;
"env")
    create_environment_files "${2:-.}"
    ;;
"config")
    create_typescript_config "${2:-.}"
    update_package_scripts "${2:-.}"
    ;;
"deps")
    install_dependencies "${2:-.}"
    ;;
"setup")
    setup_webserver "${2:-.}" "${3:-false}"
    ;;
*)
    echo "Usage: $0 {check|dirs|env|config|deps|setup} [project_root] [skip_deps]"
    exit 1
    ;;
esac
