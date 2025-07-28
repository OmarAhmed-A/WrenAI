#!/bin/bash

# Multi-LLM Testing Script for WrenAI
# This script helps manage the multi-LLM Docker setup with robust container communication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR"

# Function to display help
show_help() {
    cat << EOF
WrenAI Multi-LLM Testing Script

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
    start       Start all services with proper orchestration
    stop        Stop all services  
    restart     Restart all services
    logs        Show logs for all services
    status      Show status of services with health checks
    config      Validate docker-compose configuration
    bootstrap   Check bootstrap container initialization
    health      Check health of all services
    validate    Validate container communication
    help        Show this help message

OPTIONS:
    --env-file  Specify environment file (default: .env.multi-llm)
    --timeout   Health check timeout in seconds (default: 300)

EXAMPLES:
    $0 start                    # Start with default env file
    $0 start --env-file .env    # Start with custom env file
    $0 logs                     # Show all logs
    $0 health                   # Check service health
    $0 validate                 # Validate communications

ACCESS POINTS:
    GPT-4.1-mini:     http://localhost:1041
    GPT-o4-mini:      http://localhost:1004  
    GPT-o3:           http://localhost:1003
    Claude Sonnet 4:  http://localhost:2004

EOF
}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Default values
ENV_FILE=".env.multi-llm"
HEALTH_TIMEOUT=300

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --timeout)
            HEALTH_TIMEOUT="$2"
            shift 2
            ;;
        start|stop|restart|logs|status|config|bootstrap|health|validate|help)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Unknown argument: $1"
            show_help
            exit 1
            ;;
    esac
done

# Set command to help if not specified
if [[ -z "${COMMAND:-}" ]]; then
    COMMAND="help"
fi

# Change to docker directory
cd "$DOCKER_DIR"

# Check if environment file exists
if [[ ! -f "$ENV_FILE" ]]; then
    log_error "Environment file '$ENV_FILE' not found!"
    log_info "Copy and configure the example file:"
    echo "   cp .env.multi-llm .env"
    echo "   # Edit .env and add your API keys"
    exit 1
fi

# Create symlink for Docker Compose default env loading
ln -sf "$ENV_FILE" .env

# Docker Compose command base
COMPOSE_CMD="docker compose -f docker-compose-multi-llm.yaml"

# Function to check service health or completion
check_service_health() {
    local service_name="$1"
    local max_attempts=60
    local attempt=1
    
    log_info "Checking status of $service_name..."
    
    # Special handling for bootstrap - check if it completed successfully
    if [[ "$service_name" == "bootstrap" ]]; then
        while [[ $attempt -le $max_attempts ]]; do
            local status=$($COMPOSE_CMD ps --format json | jq -r ".[] | select(.Service == \"$service_name\") | .State")
            if [[ "$status" == "exited" ]]; then
                local exit_code=$($COMPOSE_CMD ps --format json | jq -r ".[] | select(.Service == \"$service_name\") | .ExitCode")
                if [[ "$exit_code" == "0" ]]; then
                    log_success "$service_name completed successfully"
                    return 0
                else
                    log_error "$service_name exited with code $exit_code"
                    return 1
                fi
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "$service_name failed to complete after $max_attempts attempts"
                return 1
            fi
            
            echo -n "."
            sleep 5
            ((attempt++))
        done
    else
        # Standard health check for other services
        while [[ $attempt -le $max_attempts ]]; do
            if $COMPOSE_CMD ps --format json | jq -r ".[] | select(.Service == \"$service_name\") | .Health" | grep -q "healthy"; then
                log_success "$service_name is healthy"
                return 0
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "$service_name failed to become healthy after $max_attempts attempts"
                return 1
            fi
            
            echo -n "."
            sleep 5
            ((attempt++))
        done
    fi
}

# Function to validate container communication
validate_communication() {
    log_info "Validating container communication..."
    
    # Check if all services are running
    local services=("bootstrap" "wren-engine" "ibis-server" "qdrant" 
                   "wren-ai-service-gpt-4.1-mini" "wren-ai-service-gpt-o4-mini" 
                   "wren-ai-service-gpt-o3" "wren-ai-service-claude-sonnet-4")
    
    for service in "${services[@]}"; do
        if ! $COMPOSE_CMD ps --format json | jq -r ".[].Service" | grep -q "^$service$"; then
            log_error "$service is not running"
            return 1
        fi
    done
    
    # Test health endpoints using container names
    local ai_services=("wren-ai-service-gpt-4.1-mini:5555" 
                      "wren-ai-service-gpt-o4-mini:5556"
                      "wren-ai-service-gpt-o3:5557" 
                      "wren-ai-service-claude-sonnet-4:5558")
    
    for service_port in "${ai_services[@]}"; do
        local service=$(echo $service_port | cut -d: -f1)
        local port=$(echo $service_port | cut -d: -f2)
        
        log_info "Testing $service health endpoint..."
        if ! docker exec "$service" curl -f "http://localhost:$port/health" > /dev/null 2>&1; then
            log_error "$service health check failed"
            return 1
        fi
    done
    
    # Test Qdrant connectivity
    log_info "Testing Qdrant connectivity..."
    if ! docker exec "wrenai-multi-llm-qdrant-1" curl -f "http://localhost:6333/health" > /dev/null 2>&1; then
        log_error "Qdrant health check failed"
        return 1
    fi
    
    log_success "All container communications validated successfully"
    return 0
}

# Function to check bootstrap initialization
check_bootstrap() {
    log_info "Checking bootstrap container initialization..."
    
    # Wait for bootstrap to complete if it's still running
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        local status=$($COMPOSE_CMD ps --format json | jq -r ".[] | select(.Service == \"bootstrap\") | .State" 2>/dev/null)
        
        if [[ "$status" == "exited" ]]; then
            local exit_code=$($COMPOSE_CMD ps --format json | jq -r ".[] | select(.Service == \"bootstrap\") | .ExitCode")
            if [[ "$exit_code" == "0" ]]; then
                break
            else
                log_error "Bootstrap exited with error code $exit_code"
                return 1
            fi
        elif [[ "$status" == "running" ]]; then
            echo -n "."
            sleep 2
            ((attempt++))
            continue
        elif [[ -z "$status" ]]; then
            log_error "Bootstrap container not found"
            return 1
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            log_error "Bootstrap failed to complete within timeout"
            return 1
        fi
    done
    
    # Check if bootstrap completed successfully by verifying created files using volume mount
    # Since bootstrap container exits, we'll check via another container that has the volume mounted
    if ! $COMPOSE_CMD exec -T wren-engine test -f "/usr/src/app/etc/config.properties" 2>/dev/null; then
        log_error "Bootstrap initialization incomplete - config.properties not found"
        return 1
    fi
    
    if ! $COMPOSE_CMD exec -T wren-engine test -d "/usr/src/app/etc/mdl" 2>/dev/null; then
        log_error "Bootstrap initialization incomplete - mdl directory not found"
        return 1
    fi
    
    if ! $COMPOSE_CMD exec -T wren-engine test -f "/usr/src/app/etc/mdl/sample.json" 2>/dev/null; then
        log_error "Bootstrap initialization incomplete - sample.json not found"
        return 1
    fi
    
    log_success "Bootstrap container initialization completed successfully"
    return 0
}

# Execute command
case $COMMAND in
    start)
        log_info "Starting WrenAI Multi-LLM services with proper orchestration..."
        
        # Start services in proper order
        $COMPOSE_CMD up -d bootstrap
        check_service_health "bootstrap"
        
        log_info "Starting backend services..."
        $COMPOSE_CMD up -d wren-engine ibis-server qdrant
        
        # Wait for backend services to be healthy
        for service in "wren-engine" "ibis-server" "qdrant"; do
            check_service_health "$service"
        done
        
        log_info "Starting AI services..."
        $COMPOSE_CMD up -d wren-ai-service-gpt-4.1-mini wren-ai-service-gpt-o4-mini wren-ai-service-gpt-o3 wren-ai-service-claude-sonnet-4
        
        # Wait for AI services to be healthy
        for service in "wren-ai-service-gpt-4.1-mini" "wren-ai-service-gpt-o4-mini" "wren-ai-service-gpt-o3" "wren-ai-service-claude-sonnet-4"; do
            check_service_health "$service"
        done
        
        log_info "Starting UI services..."
        $COMPOSE_CMD up -d wren-ui-gpt-4.1-mini wren-ui-gpt-o4-mini wren-ui-gpt-o3 wren-ui-claude-sonnet-4
        
        log_success "All services started successfully!"
        echo ""
        log_info "🌐 Access points:"
        echo "   GPT-4.1-mini:     http://localhost:1041"
        echo "   GPT-o4-mini:      http://localhost:1004"
        echo "   GPT-o3:           http://localhost:1003"
        echo "   Claude Sonnet 4:  http://localhost:2004"
        echo ""
        log_info "📋 Use '$0 health' to check service health"
        log_info "📋 Use '$0 validate' to validate communications"
        ;;
    
    stop)
        log_info "Stopping WrenAI Multi-LLM services..."
        $COMPOSE_CMD down
        log_success "Services stopped successfully!"
        ;;
    
    restart)
        log_info "Restarting WrenAI Multi-LLM services..."
        $COMPOSE_CMD down
        sleep 5
        $0 start --env-file "$ENV_FILE"
        ;;
    
    logs)
        log_info "Showing logs for all services..."
        $COMPOSE_CMD logs --follow
        ;;
    
    status)
        log_info "📊 Service status:"
        $COMPOSE_CMD ps
        echo ""
        $0 health --env-file "$ENV_FILE"
        ;;
    
    config)
        log_info "🔍 Validating Docker Compose configuration..."
        if $COMPOSE_CMD config --quiet; then
            log_success "Configuration is valid!"
        else
            log_error "Configuration validation failed!"
            exit 1
        fi
        ;;
    
    bootstrap)
        check_bootstrap
        ;;
    
    health)
        log_info "🏥 Checking health of all services..."
        
        # Check if services are running and healthy
        if ! $COMPOSE_CMD ps --format json | jq -r ".[].Service" | grep -q "bootstrap"; then
            log_error "Services are not running. Use '$0 start' to start them."
            exit 1
        fi
        
        local services=("bootstrap" "wren-engine" "ibis-server" "qdrant" 
                       "wren-ai-service-gpt-4.1-mini" "wren-ai-service-gpt-o4-mini" 
                       "wren-ai-service-gpt-o3" "wren-ai-service-claude-sonnet-4")
        
        local all_healthy=true
        for service in "${services[@]}"; do
            if ! check_service_health "$service"; then
                all_healthy=false
            fi
        done
        
        if $all_healthy; then
            log_success "All services are healthy!"
        else
            log_error "Some services are not healthy. Check logs with '$0 logs'"
            exit 1
        fi
        ;;
    
    validate)
        validate_communication
        ;;
    
    help)
        show_help
        ;;
    
    *)
        log_error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac

# Clean up symlink
rm -f .env