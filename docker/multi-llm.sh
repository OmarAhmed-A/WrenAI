#!/bin/bash

# Multi-LLM Testing Script for WrenAI
# This script helps manage the multi-LLM Docker setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR"

# Function to display help
show_help() {
    cat << EOF
WrenAI Multi-LLM Testing Script

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
    start       Start all services
    stop        Stop all services  
    restart     Restart all services
    logs        Show logs for all services
    status      Show status of services
    config      Validate docker-compose configuration
    help        Show this help message

OPTIONS:
    --env-file  Specify environment file (default: .env.multi-llm)

EXAMPLES:
    $0 start                    # Start with default env file
    $0 start --env-file .env    # Start with custom env file
    $0 logs                     # Show all logs
    $0 status                   # Check service status

ACCESS POINTS:
    GPT-4.1-mini:     http://localhost:1041
    GPT-o4-mini:      http://localhost:1004  
    GPT-o3:           http://localhost:1003
    Claude Sonnet 4:  http://localhost:2004

EOF
}

# Default environment file
ENV_FILE=".env.multi-llm"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        start|stop|restart|logs|status|config|help)
            COMMAND="$1"
            shift
            ;;
        *)
            echo "Unknown argument: $1"
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
    echo "❌ Environment file '$ENV_FILE' not found!"
    echo "💡 Copy and configure the example file:"
    echo "   cp .env.multi-llm .env"
    echo "   # Edit .env and add your API keys"
    exit 1
fi

# Create symlink for Docker Compose default env loading
ln -sf "$ENV_FILE" .env

# Docker Compose command base
COMPOSE_CMD="docker compose -f docker-compose-multi-llm.yaml"

# Execute command
case $COMMAND in
    start)
        echo "🚀 Starting WrenAI Multi-LLM services..."
        $COMPOSE_CMD up -d
        echo ""
        echo "✅ Services started successfully!"
        echo ""
        echo "🌐 Access points:"
        echo "   GPT-4.1-mini:     http://localhost:1041"
        echo "   GPT-o4-mini:      http://localhost:1004"
        echo "   GPT-o3:           http://localhost:1003"
        echo "   Claude Sonnet 4:  http://localhost:2004"
        echo ""
        echo "📋 Use '$0 logs' to monitor logs"
        echo "📋 Use '$0 status' to check service status"
        ;;
    
    stop)
        echo "🛑 Stopping WrenAI Multi-LLM services..."
        $COMPOSE_CMD down
        echo "✅ Services stopped successfully!"
        ;;
    
    restart)
        echo "🔄 Restarting WrenAI Multi-LLM services..."
        $COMPOSE_CMD down
        $COMPOSE_CMD up -d
        echo "✅ Services restarted successfully!"
        ;;
    
    logs)
        echo "📋 Showing logs for all services..."
        $COMPOSE_CMD logs --follow
        ;;
    
    status)
        echo "📊 Service status:"
        $COMPOSE_CMD ps
        ;;
    
    config)
        echo "🔍 Validating Docker Compose configuration..."
        $COMPOSE_CMD config --quiet
        echo "✅ Configuration is valid!"
        ;;
    
    help)
        show_help
        ;;
    
    *)
        echo "❌ Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac

# Clean up symlink
rm -f .env