#!/bin/bash

# Color definitions
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export WHITE='\033[1;37m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# Log level definitions
export LOG_LEVEL_DEBUG=0
export LOG_LEVEL_INFO=1
export LOG_LEVEL_WARN=2
export LOG_LEVEL_ERROR=3

# Current log level (can be overridden)
export CURRENT_LOG_LEVEL=${CURRENT_LOG_LEVEL:-$LOG_LEVEL_INFO}

# Logging functions
log_debug() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ] && echo -e "${PURPLE}[DEBUG]${NC} $1" >&2
}

log_info() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ] && echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARN ] && echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    [ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ] && echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Enhanced logging with timestamps
log_with_timestamp() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "DEBUG") log_debug "[$timestamp] $message" ;;
        "INFO") log_info "[$timestamp] $message" ;;
        "WARN") log_warn "[$timestamp] $message" ;;
        "ERROR") log_error "[$timestamp] $message" ;;
        "SUCCESS") log_success "[$timestamp] $message" ;;
    esac
}

# Status icons
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_debug() {
    echo -e "${PURPLE}🔍 $1${NC}"
}

# Headers and sections
print_header() {
    local title=$1
    local width=50
    echo ""
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo -e "${BLUE}$(printf '%*s' $(((${#title}+$width)/2)) "$title")${NC}"
    echo -e "${BLUE}$(printf '=%.0s' $(seq 1 $width))${NC}"
    echo ""
}

print_section() {
    local title=$1
    echo ""
    echo -e "${CYAN}--- $title ---${NC}"
}

print_step() {
    local step_num=$1
    local step_desc=$2
    echo -e "${WHITE}${BOLD}Step $step_num:${NC} $step_desc"
}

# Progress indicators
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Confirmation prompts
confirm() {
    local message=$1
    local default=${2:-"N"}
    
    if [ "$default" = "Y" ]; then
        local prompt="$message (Y/n): "
        local pattern="^[Nn]$"
        local result="yes"
    else
        local prompt="$message (y/N): "
        local pattern="^[Yy]$"
        local result="no"
    fi
    
    read -p "$(echo -e "${YELLOW}$prompt${NC}")" -n 1 -r
    echo
    
    if [[ $REPLY =~ $pattern ]]; then
        [ "$default" = "Y" ] && echo "no" || echo "yes"
    else
        echo $result
    fi
}

# Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command=$3
    
    print_error "Command failed with exit code $exit_code at line $line_number: $command"
    log_error "Stack trace: $(caller)"
    exit $exit_code
}

# Set up error trapping
set_error_trap() {
    set -eE
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
}

# File operations logging
log_file_operation() {
    local operation=$1
    local file=$2
    local status=$3
    
    case $status in
        "success") print_success "$operation: $file" ;;
        "warning") print_warning "$operation: $file" ;;
        "error") print_error "$operation: $file" ;;
        *) print_info "$operation: $file" ;;
    esac
}

# Export functions for use in other scripts
export -f log_debug log_info log_warn log_error log_success log_with_timestamp
export -f print_success print_warning print_error print_info print_debug
export -f print_header print_section print_step show_spinner confirm handle_error
export -f set_error_trap log_file_operation