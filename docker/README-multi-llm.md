# Multi-LLM Testing Setup for WrenAI

This setup allows you to run multiple AI service containers with different LLM configurations simultaneously, sharing the same database and backend services. This is perfect for testing and comparing different LLMs using the same data source.

## Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ UI (GPT-4.1-mini)│ │ UI (GPT-o4-mini)│  │   UI (GPT-o3)   │  │UI (Claude Sonnet│
│   Port: 1041    │  │   Port: 1004    │  │   Port: 1003    │  │   4) Port: 2004 │
└─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘
         │                     │                     │                     │
         ▼                     ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│AI Svc(GPT-4.1-  │  │AI Svc(GPT-o4-   │  │ AI Svc (GPT-o3) │  │AI Svc (Claude   │
│  mini) Port:5555│  │  mini) Port:5556│  │   Port: 5557    │  │Sonnet 4)Port:558│
└─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘
         │                     │                     │                     │
         └─────────────────────┼─────────────────────┼─────────────────────┘
                               ▼                     ▼
                    ┌─────────────────┐
                    │ Shared Backend  │
                    │                 │
                    │ • Wren Engine   │
                    │ • Qdrant        │
                    │ • Ibis Server   │
                    │ • Bootstrap     │
                    └─────────────────┘
```

## Features

- **Four LLM Configurations**: GPT-4.1-mini, GPT-o4-mini, GPT-o3, and Claude Sonnet 4
- **Shared Backend**: Same database, query engine, and vector store
- **Isolated UI Instances**: Each UI connects to a specific AI service
- **Easy Comparison**: Test the same queries across different LLMs
- **Flexible Configuration**: Easy to add more LLM providers

## Quick Start

### 1. Prerequisites

- Docker and Docker Compose installed
- API keys for the services you want to test:
  - OpenAI API key (for OpenAI and GPT configurations)
  - Groq API key (for Groq configuration)
  - Anthropic API key (for Claude configuration)
  - Ollama running locally (for Ollama configuration)

### 2. Setup Environment

Copy and configure the environment file:

```bash
cp docker/.env.multi-llm docker/.env
```

Edit `docker/.env` and add your API keys:

```bash
# Add your API keys
OPENAI_API_KEY=your_openai_api_key_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here

# Generate a UUID for telemetry (optional)
USER_UUID=your_uuid_here
```

### 3. Start the Services

```bash
cd docker
docker-compose -f docker-compose-multi-llm.yaml --env-file .env up -d
```

### 4. Access the UIs

Once all services are running, you can access the different UI instances:

- **GPT-4.1-mini UI**: http://localhost:1041
- **GPT-o4-mini UI**: http://localhost:1004  
- **GPT-o3 UI**: http://localhost:1003
- **Claude Sonnet 4 UI**: http://localhost:2004

## Configuration Files

Each LLM provider has its own configuration file:

- `config.gpt-4.1-mini.yaml`: GPT-4.1-mini configuration with multiple model options
- `config.gpt-o4-mini.yaml`: GPT-o4-mini configuration using gpt-4.1-nano-2025-04-14  
- `config.gpt-o3.yaml`: GPT-o3 configuration using gpt-4.1-2025-04-14
- `config.claude-sonnet-4.yaml`: Claude Sonnet 4 configuration using anthropic/claude-sonnet-4-20250514

## Port Configuration

| Service | OpenAI | Groq | Ollama | GPT-4o-mini | GPT-4o-mini Alt | GPT-4o | Claude |
|---------|--------|------|--------|-------------|-----------------|--------|--------|
| UI | 3001 | 3002 | 3003 | 1041 | 1004 | 1003 | 2004 |
| AI Service | 5555 | 5556 | 5557 | 5558 | 5559 | 5560 | 5561 |

Shared services:
- Wren Engine: 8080
- Qdrant: 6333
- Ibis Server: 8000

## Testing and Comparison

1. **Load your data** through any of the UI instances (they all share the same backend)
2. **Ask the same questions** across different UIs to compare responses
3. **Monitor performance** by checking the different AI service logs:
   ```bash
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-gpt-4.1-mini
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-gpt-o4-mini
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-gpt-o3
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-claude-sonnet-4
   ```

## Troubleshooting

### Common Issues

1. **Port conflicts**: If any ports are already in use, modify the port mappings in `.env.multi-llm`

2. **API key issues**: Make sure your API keys are correctly set in the `.env` file

3. **Container startup order**: The services have proper dependencies, but if you see connection issues, restart the stack:
   ```bash
   docker-compose -f docker-compose-multi-llm.yaml down
   docker-compose -f docker-compose-multi-llm.yaml up -d
   ```

### Logs and Debugging

Check specific service logs:
```bash
# All services
docker-compose -f docker-compose-multi-llm.yaml logs

# Specific AI service
docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-gpt-4.1-mini

# Specific UI
docker-compose -f docker-compose-multi-llm.yaml logs wren-ui-gpt-o3
```

## Customization

### Adding More LLM Providers

1. **Create a new config file** (e.g., `config.new-model.yaml`)
2. **Add service definitions** to `docker-compose-multi-llm.yaml`
3. **Update environment variables** in `.env.multi-llm`
4. **Assign unique ports** for the new services

### Modifying LLM Models

Edit the respective config files to change:
- Model names and versions
- Context window sizes
- Temperature and other parameters
- Embedding models

## Stopping the Services

```bash
docker-compose -f docker-compose-multi-llm.yaml down
```

To also remove volumes:
```bash
docker-compose -f docker-compose-multi-llm.yaml down -v
```

## Performance Notes

- **Resource Usage**: Running multiple AI services simultaneously will use more memory and CPU
- **Shared Storage**: All configurations share the same Qdrant vector database for efficiency
- **Network**: Services communicate internally via Docker network for optimal performance