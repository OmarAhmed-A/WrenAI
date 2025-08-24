# WrenAI Multi-LLM Testing Setup

This directory contains a comprehensive multi-LLM testing infrastructure that allows developers to run and compare multiple AI service containers with different LLM configurations while ensuring robust inter-container communication and reliable resource management.

## Architecture Overview

### Robust Container Communication Design

The multi-LLM setup implements a carefully orchestrated architecture with proper dependency management and health checks:

```
┌─────────────────────────────────────────────────────────────┐
│                    Startup Orchestration                    │
├─────────────────────────────────────────────────────────────┤
│ 1. Bootstrap (Data initialization)                          │
│ 2. Backend Services (Engine, Ibis, Qdrant)                 │
│ 3. AI Services (GPT variants, Claude)                      │
│ 4. UI Services (Web interfaces)                            │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   Service Dependencies                      │
├─────────────────────────────────────────────────────────────┤
│ Bootstrap ──┐                                               │
│             ├──→ Wren Engine ──┐                           │
│             │                  ├──→ AI Services ──→ UI     │
│             └──→ Qdrant ────────┘                           │
│                  Ibis Server ──────────────────────→ UI     │
└─────────────────────────────────────────────────────────────┘
```

### Key Communication Features

1. **Health Check Integration**: All services include comprehensive health checks with proper timeouts and retry logic
2. **Dependency Orchestration**: Services start in the correct order using health-based dependencies
3. **Resource Isolation**: Each LLM uses unique Qdrant collection prefixes to prevent conflicts
4. **Shared Backend**: All LLMs share the same engine, database, and configuration for consistent testing
5. **Network Segmentation**: All services communicate through a dedicated Docker network

## Container Communication Details

### Bootstrap Integration
- **Purpose**: Initializes shared data volume with configuration files and directory structure
- **Health Check**: Validates that `config.properties` and `mdl/sample.json` are created
- **Dependencies**: None (first to start)
- **Communication**: Prepares data volume for other services

### Backend Services Communication
- **Wren Engine**: Waits for bootstrap completion, provides query processing
- **Ibis Server**: Connects to wren-engine via HTTP, provides additional query capabilities  
- **Qdrant**: Vector database with health endpoint monitoring
- **Health Checks**: HTTP-based health endpoints with 30s intervals

### AI Services Communication
- **Dependencies**: Wait for bootstrap, qdrant, and wren-engine to be healthy
- **Engine Communication**: Connect directly to wren-engine (not UI) to avoid circular dependencies
- **Qdrant Isolation**: Each service uses unique collection prefixes:
  - `gpt_4_1_mini_*` for GPT-4.1-mini service
  - `gpt_o4_mini_*` for GPT-o4-mini service  
  - `gpt_o3_*` for GPT-o3 service
  - `claude_sonnet_4_*` for Claude Sonnet 4 service
- **Resource Management**: `SHOULD_FORCE_DEPLOY=0` prevents conflicting deployments

### UI Services Communication
- **Dependencies**: Wait for corresponding AI service to be healthy
- **Service Endpoints**: Each UI connects to its dedicated AI service
- **Shared Data**: All UIs access the same SQLite database and data volume
- **Port Mapping**: Unique external ports (1041, 1004, 1003, 2004)

## Concurrency and Resource Management

### Qdrant Index Management
- **Problem Solved**: Multiple services creating/recreating the same indices
- **Solution**: Collection prefixes ensure each LLM has isolated vector storage
- **Benefits**: Eliminates race conditions and data corruption

### Startup Synchronization
- **Health-Based Dependencies**: Services only start after dependencies are confirmed healthy
- **Timeout Management**: Configurable timeouts with exponential backoff
- **Error Recovery**: Automatic restarts on failure with proper cleanup

### Resource Contention Prevention
- **Shared Volume Access**: Bootstrap initializes, others read-only or coordinated access
- **Network Communication**: All HTTP communication through dedicated Docker network
- **Port Management**: No port conflicts through careful allocation

## Configuration Files

### LLM-Specific Configurations

Each LLM has its own configuration file with provider-specific settings:

**GPT-4.1-mini** (`config.gpt-4.1-mini.yaml`)
- Models: nano, mini, full GPT-4.1 variants
- Default: `gpt-4.1-mini-2025-04-14`
- Collection prefix: `gpt_4_1_mini`

**GPT-o4-mini** (`config.gpt-o4-mini.yaml`)  
- Models: nano, mini, full GPT-4.1 variants
- Default: `gpt-4.1-nano-2025-04-14`
- Collection prefix: `gpt_o4_mini`

**GPT-o3** (`config.gpt-o3.yaml`)
- Models: nano, mini, full GPT-4.1 variants  
- Default: `gpt-4.1-2025-04-14`
- Collection prefix: `gpt_o3`

**Claude Sonnet 4** (`config.claude-sonnet-4.yaml`)
- Model: `anthropic/claude-sonnet-4-20250514`
- API Base: `https://api.anthropic.com`
- Collection prefix: `claude_sonnet_4`
- Embedding dimension: 1536 (different from GPT models)

## Service Validation and Health Monitoring

### Management Script Features

The `multi-llm.sh` script provides comprehensive management with built-in validation:

```bash
# Start services with proper orchestration
./multi-llm.sh start

# Check health of all services  
./multi-llm.sh health

# Validate container communication
./multi-llm.sh validate

# Check bootstrap initialization
./multi-llm.sh bootstrap
```

### Health Check Endpoints

All services expose standardized health endpoints:
- **AI Services**: `http://localhost:<port>/health`
- **Qdrant**: `http://localhost:6333/health` 
- **Wren Engine**: `http://localhost:8080/health`
- **Ibis Server**: `http://localhost:8000/health`

### Communication Validation

The validation system tests:
1. Service availability and health status
2. HTTP connectivity between services
3. Qdrant vector database accessibility
4. Bootstrap initialization completion
5. Unique collection creation in Qdrant

## Environment Configuration

### Required Environment Variables

```bash
# API Keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# Service Ports (Internal)
WREN_AI_SERVICE_PORT_GPT_4_1_MINI=5555
WREN_AI_SERVICE_PORT_GPT_O4_MINI=5556
WREN_AI_SERVICE_PORT_GPT_O3=5557
WREN_AI_SERVICE_PORT_CLAUDE_SONNET_4=5558

# UI Ports (External)
HOST_PORT_GPT_4_1_MINI=1041
HOST_PORT_GPT_O4_MINI=1004
HOST_PORT_GPT_O3=1003
HOST_PORT_CLAUDE_SONNET_4=2004
```

## Usage Examples

### Basic Setup
```bash
cd docker
cp .env.multi-llm .env
# Edit .env and add your API keys

# Start all services with orchestration
./multi-llm.sh start

# Access different LLM interfaces:
# GPT-4.1-mini:     http://localhost:1041
# GPT-o4-mini:      http://localhost:1004  
# GPT-o3:           http://localhost:1003
# Claude Sonnet 4:  http://localhost:2004
```

### Advanced Monitoring
```bash
# Check system health
./multi-llm.sh health

# Validate all communications
./multi-llm.sh validate

# Monitor logs in real-time
./multi-llm.sh logs

# Check service status with health info
./multi-llm.sh status
```

## Troubleshooting

### Common Issues and Solutions

**Services fail to start**
```bash
# Check bootstrap initialization
./multi-llm.sh bootstrap

# Validate configuration
./multi-llm.sh config
```

**Communication errors**
```bash
# Test all connections
./multi-llm.sh validate

# Check specific service health
docker exec <service-name> curl -f http://localhost:<port>/health
```

**Resource conflicts**
- Each LLM uses isolated Qdrant collections
- Bootstrap ensures proper initialization order
- Health checks prevent premature service communication

### Performance Monitoring

**Resource Usage**
```bash
# Monitor container resources
docker stats

# Check service logs for performance metrics
./multi-llm.sh logs | grep -E "(startup|health|error)"
```

## Security Considerations

- API keys stored in environment files (not committed to git)
- Services communicate through isolated Docker network
- No external access to internal service ports
- Health endpoints use local network only

## Benefits of This Architecture

1. **Reliable Startup**: Health-based dependencies ensure proper initialization order
2. **Resource Safety**: Isolated collections prevent conflicts between LLM services  
3. **Communication Validation**: Built-in testing of all inter-service connections
4. **Easy Debugging**: Comprehensive health checks and validation tools
5. **Scalable Design**: Easy to add new LLM providers with same pattern
6. **Production Ready**: Robust error handling and recovery mechanisms

This multi-LLM setup provides a production-ready testing environment with enterprise-grade container orchestration, ensuring reliable and scalable AI service comparison workflows.