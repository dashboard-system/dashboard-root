# Dashboard System - Aircraft Control Platform

[![Docker](https://img.shields.io/badge/Docker-ready-blue)](https://www.docker.com/)
[![Node.js](https://img.shields.io/badge/Node.js-20+-green)](https://nodejs.org/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5+-blue)](https://www.typescriptlang.org/)
[![React](https://img.shields.io/badge/React-19-blue)](https://reactjs.org/)
[![MQTT](https://img.shields.io/badge/MQTT-enabled-orange)](https://mqtt.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A comprehensive **aircraft control dashboard system** with real-time configuration management, MQTT messaging, and modern web interface. This multi-service platform provides centralized control over aircraft systems including lighting, climate control, music, flight data display, and more.

## 🚁 System Overview

### Architecture
```
┌─────────────────────────────────────────────────────────────────┐
│                 Aircraft Dashboard System                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   MQTT Server   │  │ Dashboard Web   │  │   UI Frontend   │  │
│  │   (Port 3001)   │◄─┤   (Port 3000)   │◄─┤   (React SPA)   │  │
│  │                 │  │                 │  │                 │  │
│  │ • UCI Config    │  │ • REST APIs     │  │ • Control Panels│  │
│  │ • MQTT Broker   │  │ • Authentication│  │ • Real-time UI  │  │
│  │ • File Watching │  │ • JWT Security  │  │ • Flight Display│  │
│  │ • WebSocket     │  │ • Database      │  │ • Material-UI   │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│         │                       │                       │       │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │              MQTT Messaging & UCI Configuration             │  │
│  └─────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### 🎯 Core Features

- **🛩️ Aircraft Systems Control**: Lighting, climate, music, flight data
- **🔄 Real-time Communication**: MQTT messaging with WebSocket support  
- **⚙️ UCI Configuration**: Unified Configuration Interface management
- **🔐 Secure Authentication**: JWT-based user authentication system
- **🌐 Modern Web Interface**: React 19 with Material-UI components
- **🐳 Docker Deployment**: Multi-container orchestration with Docker Compose
- **📊 Health Monitoring**: Comprehensive system health checks
- **🔧 Automated Setup**: One-command initialization and management

## 🏗️ Services Architecture

| Service | Port | Technology | Purpose |
|---------|------|------------|---------|
| **MQTT Server** | 3001 | Node.js + Aedes | UCI management, MQTT broker |
| **WebSocket MQTT** | 8883 | WebSocket | Real-time browser communication |
| **MQTT Broker** | 1883 | Mosquitto | IoT device communication |
| **Dashboard Web** | 3000 | Express + TypeScript | API backend, UI serving |
| **UI Frontend** | - | React + Vite | User interface (SPA) |

## 🚀 Quick Start

### Prerequisites
- **Docker Desktop** (recommended) 
- **Node.js 20+** (for local development)
- **Git** with submodule support

### 1. Initialize Project

```bash
# Clone with submodules
git clone --recursive https://github.com/dashboard-system/dashboard-root
cd dashboard-root

# Make initialization script executable
chmod +x init.sh

# Complete project setup (Docker required)
./init.sh
```

### 2. Access Dashboard

After initialization:
- **Main Dashboard**: http://localhost:3000
- **REST API**: http://localhost:3000/api/
- **MQTT Server API**: http://localhost:3001/api/
- **Health Checks**: http://localhost:3000/health

**Default Login**:
- Username: `engineer`
- Password: `engineerpassword`

> ⚠️ **Security**: Change default passwords in production!

## 📱 Dashboard Pages

### Available Control Interfaces

| Page | Route | Function |
|------|--------|----------|
| **Landing** | `/` | Main dashboard overview |
| **Lights** | `/lights` | Aircraft lighting control (cockpit, cabin, instruments) |
| **A/C** | `/ac` | Climate control systems |
| **Music** | `/music` | Integrated audio system |
| **A429** | `/a429` | Flight data display |
| **Bluetooth** | `/bluetooth` | Device connectivity |
| **Settings** | `/settings` | System configuration |

### Flight Control Features
- **Cockpit Lighting**: Individual zone control
- **Cabin Climate**: Temperature and fan control
- **Flight Data**: Real-time A429 data display
- **Audio System**: Integrated music controls
- **System Health**: Real-time monitoring

## 🔧 Development & Management

### NPM Scripts (Root Level)

```bash
# Submodule management
npm run update-submodules    # Update all 3 submodules to latest
npm run update-subs         # Short alias for submodule updates

# Docker operations
npm run build               # Build all Docker images
npm run up                  # Start all services
npm run down                # Stop all services
npm run logs                # View service logs

# Project management  
npm run init                # Initialize project
npm run status              # Check service status
```

### Manual Scripts

```bash
# Full project initialization
./init.sh

# Update all submodules to latest commits
./update-submodules.sh

# Individual service management
./scripts/docker.sh         # Docker utilities
./scripts/services.sh       # Service management
./scripts/git.sh            # Git operations
```

## 🏛️ Repository Structure

```
dashboard-root/
├── 📁 dashboard-webserver/          # Web API & UI (submodule)
│   ├── src/                         # TypeScript backend
│   │   ├── routes/                  # API endpoints
│   │   ├── middleware/              # Auth, security
│   │   └── data/                    # Database layer
│   └── ui/                          # React frontend (submodule)
│       ├── src/                     # React components
│       ├── pages/                   # Dashboard pages
│       └── components/              # Reusable components
├── 📁 mqtt_server/                  # MQTT & UCI management (submodule)
│   ├── src/                         # Node.js MQTT server
│   ├── uci/                         # Configuration files
│   └── uci_backup/                  # Backup storage
├── 📁 scripts/                      # Automation scripts
│   ├── init.sh                      # Project initialization
│   ├── git.sh                       # Submodule management
│   └── docker.sh                    # Container operations
├── 📄 docker-compose.yml            # Multi-service orchestration
├── 📄 package.json                  # Root-level scripts
└── 📄 README.md                     # This file
```

## 🐳 Docker Deployment

### Production Deployment

```bash
# Production startup
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Monitor services
docker-compose ps
docker-compose logs -f

# Health checks
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### Service Configuration

#### MQTT Server
- **MQTT Broker**: Port 1883
- **WebSocket**: Port 8883  
- **REST API**: Port 3001
- **Volumes**: UCI configs, logs, backups

#### Dashboard Webserver
- **Web Interface**: Port 3000
- **Database**: SQLite (persistent volume)
- **Authentication**: JWT with bcrypt
- **Volumes**: Database, logs

### Networking
- **Bridge Network**: `dashboard-network`
- **Service Discovery**: Container names as hostnames
- **Health Checks**: Automatic container health monitoring

## ⚙️ Configuration Management

### UCI (Unified Configuration Interface)
The system uses UCI format for aircraft configuration:

```bash
# Example UCI configuration
config lights 'cockpit'
    option zone 'main'
    option brightness '80'
    option color 'warm'
    option enabled '1'

config climate 'cabin'
    option temperature '22'
    option fan_speed '3'
    option mode 'auto'
```

### Environment Configuration
Each service uses `.env` files for configuration:

```bash
# Generated automatically by init.sh
JWT_SECRET=auto-generated-secure-key
DATABASE_PATH=./db/sqlite.db
MQTT_HOST=mqtt-server
NODE_ENV=production
```

## 🔐 Security Features

- **JWT Authentication**: Secure token-based auth
- **Password Hashing**: bcrypt with salt rounds
- **CORS Protection**: Configurable cross-origin policies  
- **Security Headers**: Helmet.js middleware
- **Input Validation**: Request sanitization
- **Container Security**: Non-root user execution

## 📊 Monitoring & Health

### Health Endpoints

```bash
# System health
curl http://localhost:3000/health/detailed

# Database status  
curl http://localhost:3000/health/db

# MQTT server status
curl http://localhost:3001/health

# Service metrics
docker-compose ps
docker stats
```

### Logging
- **Structured Logging**: Winston/Morgan loggers
- **Log Rotation**: Automatic log file management
- **Docker Logs**: Centralized container logging
- **Debug Mode**: Detailed debugging information

## 🔄 Submodule Updates

This repository uses **3 Git submodules**:

1. **dashboard-webserver**: Web API and TypeScript backend
2. **dashboard-webserver/ui**: React frontend application  
3. **mqtt_server**: MQTT broker and UCI configuration management

### Automated Updates

```bash
# Update all 3 submodules to latest main branch
npm run update-submodules

# Alternative methods
./update-submodules.sh
./scripts/git.sh update_all_submodules
```

### Manual Submodule Management

```bash
# Initialize submodules
git submodule update --init --recursive

# Update to latest commits
git submodule update --remote --recursive

# Check submodule status
git submodule status --recursive
```

## 🛠️ Development Setup

### Local Development

```bash
# Install dependencies in all submodules
npm run init

# Start development servers
cd dashboard-webserver
npm run dev              # Backend on :3000

cd ui  
npm run dev              # Frontend dev server

cd ../mqtt_server
npm run dev              # MQTT server on :3001
```

### Adding New Features

1. **UI Components**: Add to `dashboard-webserver/ui/src/components/`
2. **API Endpoints**: Add to `dashboard-webserver/src/routes/`
3. **MQTT Topics**: Configure in `mqtt_server/src/uci/`
4. **UCI Configs**: Add to `mqtt_server/uci/`

## 🚀 Production Deployment

### Pre-deployment Checklist

- [ ] Update all submodules: `npm run update-submodules`
- [ ] Build images: `docker-compose build --no-cache`
- [ ] Configure production environment variables
- [ ] Set up SSL/TLS certificates (reverse proxy)
- [ ] Configure firewall rules
- [ ] Set up database backups
- [ ] Change default authentication credentials

### Cloud Deployment (AWS/Azure/GCP)

```bash
# Build for production
docker-compose -f docker-compose.prod.yml build

# Deploy with environment overrides
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Configure load balancer/reverse proxy for port 3000
# Set up SSL termination at load balancer level
# Configure auto-scaling for high availability
```

## 🤝 Contributing

### Development Workflow

1. **Fork the repository** and all submodules
2. **Create feature branch**: `git checkout -b feature/amazing-feature`
3. **Make changes** in appropriate submodules
4. **Update submodules**: `npm run update-submodules`
5. **Test locally**: `docker-compose up --build`
6. **Commit changes**: Include submodule updates
7. **Push to branch**: `git push origin feature/amazing-feature`
8. **Open Pull Request** with detailed description

### Code Standards
- **TypeScript**: Strict mode enabled
- **ESLint**: Airbnb configuration
- **Prettier**: Code formatting
- **Jest**: Unit testing (planned)
- **Docker**: Multi-stage builds for production

## 📞 Support & Troubleshooting

### Common Issues

**Docker Services Won't Start**
```bash
# Check Docker daemon
docker version

# Restart services
docker-compose down
docker-compose up --build
```

**Submodule Issues**
```bash
# Reinitialize submodules
git submodule deinit --all
git submodule update --init --recursive
```

**MQTT Connection Issues**
```bash
# Test MQTT connectivity
docker exec mqtt-server-container mosquitto_pub -t test -m "hello"
```

**Authentication Problems**
```bash
# Check JWT configuration
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"engineer","password":"engineerpassword"}'
```

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/dashboard-system/dashboard-root/issues)
- **Discussions**: [GitHub Discussions](https://github.com/dashboard-system/dashboard-root/discussions)  
- **Documentation**: Service-specific README files
- **Examples**: `/examples` directory (planned)

## 📝 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## 🗺️ Roadmap

### Short Term
- [ ] Unit testing suite (Jest)
- [ ] Integration tests
- [ ] API documentation (Swagger/OpenAPI)
- [ ] Performance monitoring
- [ ] Error tracking (Sentry)

### Medium Term  
- [ ] Kubernetes deployment configs
- [ ] Redis session storage
- [ ] Real-time analytics dashboard
- [ ] Mobile app (React Native/Tauri)
- [ ] Desktop app (Electron/Tauri)

### Long Term
- [ ] Multi-aircraft support
- [ ] Advanced flight data integration
- [ ] Machine learning insights
- [ ] Voice control integration
- [ ] Offline mode support

---

**Made with ❤️ for aviation technology**

*This dashboard system is designed for modern aircraft control and monitoring applications.*