# Multi-LLM Testing Setup for WrenAI

This setup allows you to run multiple AI service containers with different LLM configurations simultaneously, sharing the same database and backend services. This is perfect for testing and comparing different LLMs using the same data source.

## Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   UI (OpenAI)   │  │   UI (Groq)     │  │  UI (Ollama)    │  │ UI (GPT-4o-mini)│
│   Port: 3001    │  │   Port: 3002    │  │   Port: 3003    │  │   Port: 1041    │
└─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│GPT-4o-mini Alt  │  │   UI (GPT-4o)   │  │  UI (Claude)    │
│   Port: 1004    │  │   Port: 1003    │  │   Port: 2004    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
         │                     │                     │
         ▼                     ▼                     ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ AI Svc (OpenAI) │  │ AI Svc (Groq)   │  │ AI Svc (Ollama) │
│   Port: 5555    │  │   Port: 5556    │  │   Port: 5557    │
└─────────────────┘  └─────────────────┘  └─────────────────┘

┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│AI Svc(GPT-4o-mini)│ │AI Svc(GPT-4o-mini│  │ AI Svc (GPT-4o) │  │ AI Svc (Claude) │
│   Port: 5558    │  │  Alt) Port: 5559│  │   Port: 5560    │  │   Port: 5561    │
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

- **Seven LLM Configurations**: OpenAI, Groq, Ollama, GPT-4o-mini, GPT-4o-mini Alt, GPT-4o, and Claude
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
GROQ_API_KEY=your_groq_api_key_here
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

- **OpenAI UI**: http://localhost:3001
- **Groq UI**: http://localhost:3002  
- **Ollama UI**: http://localhost:3003
- **GPT-4o-mini UI**: http://localhost:1041
- **GPT-4o-mini Alt UI**: http://localhost:1004
- **GPT-4o UI**: http://localhost:1003
- **Claude Sonnet UI**: http://localhost:2004

## Configuration Files

Each LLM provider has its own configuration file:

- `config.openai.yaml`: OpenAI GPT models (gpt-4o-mini, gpt-4o)
- `config.groq.yaml`: Groq models (llama-3.3-70b-specdec, llama-3.1-8b-instant)  
- `config.ollama.yaml`: Local Ollama models (phi4:14b, llama3.2:latest)
- `config.gpt-4o-mini.yaml`: GPT-4o-mini focused configuration
- `config.gpt-4o-mini-alt.yaml`: Alternative GPT-4o-mini configuration with different settings
- `config.gpt-4o.yaml`: GPT-4o focused configuration 
- `config.claude.yaml`: Claude 3.5 Sonnet configuration

## Port Configuration

| Service | OpenAI | Groq | Ollama | GPT-4o-mini | GPT-4o-mini Alt | GPT-4o | Claude |
|---------|--------|------|--------|-------------|-----------------|--------|--------|
| UI | 3001 | 3002 | 3003 | 1041 | 1004 | 1003 | 2004 |
| AI Service | 5555 | 5556 | 5557 | 5558 | 5559 | 5560 | 5561 |

Shared services:
- Wren Engine: 8080
- Qdrant: 6333
- Ibis Server: 8000

## Special Setup for Ollama

For Ollama to work properly:

1. **Install and run Ollama locally**:
   ```bash
   # Install Ollama (macOS/Linux)
   curl -fsSL https://ollama.ai/install.sh | sh
   
   # Start Ollama service
   ollama serve
   ```

2. **Pull required models**:
   ```bash
   ollama pull phi4:14b
   ollama pull llama3.2:latest
   ollama pull nomic-embed-text
   ```

3. **For Linux users**: The configuration uses `host.docker.internal:11434`. If you're on Linux, you may need to:
   - Use your actual IP address instead of `host.docker.internal`
   - Or run Ollama in a Docker container and adjust the network configuration

## Testing and Comparison

1. **Load your data** through any of the UI instances (they all share the same backend)
2. **Ask the same questions** across different UIs to compare responses
3. **Monitor performance** by checking the different AI service logs:
   ```bash
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-openai
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-groq
   docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-ollama
   ```

## Troubleshooting

### Common Issues

1. **Port conflicts**: If any ports are already in use, modify the port mappings in `.env.multi-llm`

2. **API key issues**: Make sure your API keys are correctly set in the `.env` file

3. **Ollama connection issues**: 
   - Ensure Ollama is running: `ollama list`
   - Check if models are pulled: `ollama list`
   - Verify port 11434 is accessible

4. **Container startup order**: The services have proper dependencies, but if you see connection issues, restart the stack:
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
docker-compose -f docker-compose-multi-llm.yaml logs wren-ai-service-openai

# Specific UI
docker-compose -f docker-compose-multi-llm.yaml logs wren-ui-groq
```

## Customization

### Adding More LLM Providers

1. **Create a new config file** (e.g., `config.anthropic.yaml`)
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