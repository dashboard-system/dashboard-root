#!/bin/bash
# Configuration constants and paths

# Project paths
if [ -z "$SCRIPT_DIR" ]; then
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
if [ -z "$PROJECT_ROOT" ]; then
    readonly PROJECT_ROOT="$SCRIPT_DIR"
fi
if [ -z "$WEBSERVER_DIR" ]; then
    readonly WEBSERVER_DIR="$PROJECT_ROOT/dashboard-webserver"
fi
if [ -z "$MQTT_DIR" ]; then
    readonly MQTT_DIR="$PROJECT_ROOT/mqtt_server"
fi
if [ -z "$SETUP_LOG" ]; then
    readonly SETUP_LOG="$PROJECT_ROOT/setup.log"
fi

# Service configuration
if [ -z "$MQTT_PORT" ]; then
    readonly MQTT_PORT=1883
fi
if [ -z "$MQTT_WS_PORT" ]; then
    readonly MQTT_WS_PORT=8883
fi
if [ -z "$MQTT_WEB_PORT" ]; then
    readonly MQTT_WEB_PORT=3001
fi
if [ -z "$WEBSERVER_PORT" ]; then
    readonly WEBSERVER_PORT=3000
fi

# Docker configuration
if [ -z "$COMPOSE_FILE" ]; then
    readonly COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
fi

# Environment file templates
if [ -z "$MQTT_ENV_TEMPLATE" ]; then
    readonly MQTT_ENV_TEMPLATE='# MQTT Server Configuration
MQTT_PORT=1883
MQTT_WS_PORT=8883
WEB_PORT=3001
NODE_ENV=production

# Logging
LOG_LEVEL=info
LOG_FILE=./logs/mqtt-server.log

# UCI Configuration
UCI_BACKUP_DIR=./uci_backup
UCI_WATCH_INTERVAL=1000'
fi

# Function to generate webserver env template
generate_webserver_env_template() {
    local jwt_secret="${1:-$(generate_jwt_secret)}"
    cat << EOF
# Dashboard Webserver Configuration
NODE_ENV=production
PORT=3000
HOST=0.0.0.0

# Database
DATABASE_PATH=./db/sqlite.db

# JWT Configuration
JWT_SECRET=$jwt_secret
JWT_EXPIRES_IN=7d

# Logging
LOG_LEVEL=info
LOG_FILE=./logs/webserver.log
EOF
}

# Generate JWT secret
generate_jwt_secret() {
    openssl rand -base64 32 2>/dev/null || cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1
}