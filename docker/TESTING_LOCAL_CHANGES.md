# Testing Local Changes: DISABLE_QUESTION_RECOMMENDATIONS Feature

This guide provides comprehensive instructions for building and testing the new `DISABLE_QUESTION_RECOMMENDATIONS` environment variable locally before deployment.

## Prerequisites

- Docker (version 20.10+)
- Docker Compose (version 2.0+)
- Git
- At least 8GB RAM available for Docker
- OpenAI API key (or other supported LLM API key)

## Overview

The current `docker-compose.yaml` pulls pre-built images from GitHub Container Registry (`ghcr.io`). To test your local changes, you need to:

1. Build Docker images locally with your modifications
2. Create a local development docker-compose configuration
3. Test the new `DISABLE_QUESTION_RECOMMENDATIONS` feature

## Step 1: Environment Setup

### 1.1 Navigate to the docker directory
```bash
cd /path/to/WrenAI/docker
```

### 1.2 Create your local environment file
```bash
cp .env.example .env.local
```

### 1.3 Configure your .env.local file
Edit `.env.local` and set the following required variables:

```bash
# Required: Add your OpenAI API key
OPENAI_API_KEY=your_openai_api_key_here

# Optional: Change ports if needed
HOST_PORT=3000
AI_SERVICE_FORWARD_PORT=5555

# Test the new feature - set to true to disable recommendations
DISABLE_QUESTION_RECOMMENDATIONS=false
```

### 1.4 Create AI service configuration
```bash
cp config.example.yaml config.yaml
```

Edit `config.yaml` and change the UI endpoint for local development:
```yaml
# Change this line
wren_ui_endpoint: http://wren-ui:3000
# To this for local development
wren_ui_endpoint: http://host.docker.internal:3000
```

## Step 2: Build Local Docker Images

### 2.1 Build Wren UI Service
```bash
cd ../wren-ui
docker build -t wren-ui:local .
```

**Expected output:** You should see the build process complete successfully with a final message like:
```
Successfully tagged wren-ui:local
```

### 2.2 Build Wren AI Service
```bash
cd ../wren-ai-service
docker build -f docker/Dockerfile -t wren-ai-service:local .
```

**Expected output:** You should see the Python dependencies being installed and the final message:
```
Successfully tagged wren-ai-service:local
```

### 2.3 Verify images were built
```bash
docker images | grep local
```

You should see both images listed:
```
wren-ui                local    [IMAGE_ID]    [TIME_AGO]    [SIZE]
wren-ai-service        local    [IMAGE_ID]    [TIME_AGO]    [SIZE]
```

## Step 3: Create Local Development Docker Compose

### 3.1 Create a local testing compose file
```bash
cd ../docker
cp docker-compose.yaml docker-compose-local.yaml
```

### 3.2 Modify docker-compose-local.yaml to use local images

Edit `docker-compose-local.yaml` and make the following changes:

**For wren-ai-service:**
```yaml
  wren-ai-service:
    image: wren-ai-service:local  # Changed from ghcr.io/canner/wren-ai-service:${WREN_AI_SERVICE_VERSION}
    # Remove or comment out: pull_policy: always (if present)
```

**For wren-ui:**
```yaml
  wren-ui:
    image: wren-ui:local  # Changed from ghcr.io/canner/wren-ui:${WREN_UI_VERSION}
    # Remove or comment out: pull_policy: always (if present)
```

### 3.3 Alternative: Use sed to automate the changes
```bash
# Create the local compose file and update it automatically
cp docker-compose.yaml docker-compose-local.yaml

# Replace the images with local versions
sed -i 's|ghcr.io/canner/wren-ui:${WREN_UI_VERSION}|wren-ui:local|g' docker-compose-local.yaml
sed -i 's|ghcr.io/canner/wren-ai-service:${WREN_AI_SERVICE_VERSION}|wren-ai-service:local|g' docker-compose-local.yaml

# Remove pull_policy lines that force pulling from registry
sed -i '/pull_policy: always/d' docker-compose-local.yaml
```

## Step 4: Start the Local Environment

### 4.1 Start all services
```bash
docker-compose -f docker-compose-local.yaml --env-file .env.local up -d
```

### 4.2 Monitor the startup process
```bash
# Watch logs for all services
docker-compose -f docker-compose-local.yaml --env-file .env.local logs -f

# Or watch specific services
docker-compose -f docker-compose-local.yaml --env-file .env.local logs -f wren-ui wren-ai-service
```

**Expected behavior:**
- All services should start successfully
- wren-ui should be accessible at `http://localhost:3000`
- wren-ai-service should be accessible at `http://localhost:5555`

### 4.3 Verify services are running
```bash
docker-compose -f docker-compose-local.yaml --env-file .env.local ps
```

All services should show "Up" status.

## Step 5: Test the DISABLE_QUESTION_RECOMMENDATIONS Feature

### 5.1 Test with recommendations ENABLED (default behavior)

1. **Set the environment variable:**
   ```bash
   # In .env.local, ensure:
   DISABLE_QUESTION_RECOMMENDATIONS=false
   ```

2. **Restart the services:**
   ```bash
   docker-compose -f docker-compose-local.yaml --env-file .env.local restart wren-ui wren-ai-service
   ```

3. **Test in the UI:**
   - Open http://localhost:3000
   - You should see "What could I ask?" button on the home page
   - After asking a question, you should see recommendation questions appear

4. **Verify in logs:**
   ```bash
   docker-compose -f docker-compose-local.yaml --env-file .env.local logs wren-ai-service | grep -i recommendation
   ```
   You should see recommendation generation activity.

### 5.2 Test with recommendations DISABLED

1. **Update the environment variable:**
   ```bash
   # In .env.local, change to:
   DISABLE_QUESTION_RECOMMENDATIONS=true
   ```

2. **Restart the services:**
   ```bash
   docker-compose -f docker-compose-local.yaml --env-file .env.local restart wren-ui wren-ai-service
   ```

3. **Test in the UI:**
   - Refresh http://localhost:3000
   - The "What could I ask?" button should NOT appear on the home page
   - After asking a question, NO recommendation questions should appear

4. **Verify in logs:**
   ```bash
   docker-compose -f docker-compose-local.yaml --env-file .env.local logs wren-ai-service | grep -i "recommendations disabled"
   ```
   You should see debug messages indicating recommendations are skipped.

### 5.3 Test edge cases

Test various values to ensure robust parsing:

```bash
# Test case-insensitive values
DISABLE_QUESTION_RECOMMENDATIONS=TRUE
DISABLE_QUESTION_RECOMMENDATIONS=False
DISABLE_QUESTION_RECOMMENDATIONS=1
DISABLE_QUESTION_RECOMMENDATIONS=0

# Test empty/undefined values (should default to false)
# DISABLE_QUESTION_RECOMMENDATIONS=
```

For each test case:
1. Update `.env.local`
2. Restart services: `docker-compose -f docker-compose-local.yaml --env-file .env.local restart wren-ui wren-ai-service`
3. Test the behavior in the UI

## Step 6: Development Workflow

### 6.1 Making code changes

When you make changes to the code:

**For UI changes:**
```bash
cd ../wren-ui
# Make your changes
docker build -t wren-ui:local .
docker-compose -f ../docker/docker-compose-local.yaml --env-file ../docker/.env.local restart wren-ui
```

**For AI service changes:**
```bash
cd ../wren-ai-service
# Make your changes
docker build -f docker/Dockerfile -t wren-ai-service:local .
docker-compose -f ../docker/docker-compose-local.yaml --env-file ../docker/.env.local restart wren-ai-service
```

### 6.2 Debugging

**Check service logs:**
```bash
# All services
docker-compose -f docker-compose-local.yaml --env-file .env.local logs -f

# Specific service
docker-compose -f docker-compose-local.yaml --env-file .env.local logs -f wren-ui
docker-compose -f docker-compose-local.yaml --env-file .env.local logs -f wren-ai-service
```

**Access service containers:**
```bash
# Access wren-ui container
docker-compose -f docker-compose-local.yaml --env-file .env.local exec wren-ui /bin/bash

# Access wren-ai-service container
docker-compose -f docker-compose-local.yaml --env-file .env.local exec wren-ai-service /bin/bash
```

## Step 7: Cleanup

### 7.1 Stop services
```bash
docker-compose -f docker-compose-local.yaml --env-file .env.local down
```

### 7.2 Remove local images (optional)
```bash
docker rmi wren-ui:local wren-ai-service:local
```

### 7.3 Clean up volumes (optional, will delete data)
```bash
docker-compose -f docker-compose-local.yaml --env-file .env.local down -v
```

## Troubleshooting

### Common Issues

**1. Port conflicts:**
- Change `HOST_PORT` in `.env.local` if port 3000 is in use
- Change `AI_SERVICE_FORWARD_PORT` if port 5555 is in use

**2. Docker build fails:**
- Ensure you have enough disk space
- Try clearing Docker cache: `docker system prune -a`

**3. Services don't start:**
- Check logs: `docker-compose -f docker-compose-local.yaml --env-file .env.local logs`
- Verify `.env.local` has all required variables
- Ensure OpenAI API key is valid

**4. Environment variable not working:**
- Verify the variable is set in `.env.local`
- Restart services after changing environment variables
- Check that the variable is being passed to containers: 
  ```bash
  docker-compose -f docker-compose-local.yaml --env-file .env.local exec wren-ui env | grep DISABLE
  docker-compose -f docker-compose-local.yaml --env-file .env.local exec wren-ai-service env | grep DISABLE
  ```

**5. "exec /app/entrypoint.sh: no such file or directory" error:**

This error indicates the entrypoint.sh file is missing from the AI service container. Here's how to troubleshoot:

**Step 1: Verify your build context and directory**
```bash
# Make sure you're in the correct directory
cd /path/to/WrenAI/wren-ai-service
pwd  # Should show .../WrenAI/wren-ai-service

# Verify entrypoint.sh exists
ls -la entrypoint.sh  # Should show the file with execute permissions
```

**Step 2: Verify the correct build command**
```bash
# From wren-ai-service directory, run:
docker build -f docker/Dockerfile -t wren-ai-service:local .

# NOT from docker directory! The build context must be wren-ai-service root
```

**Step 3: Verify the image was built correctly**
```bash
# Check that your local image exists
docker images | grep wren-ai-service

# Test the entrypoint file exists in the built image
docker run --rm wren-ai-service:local ls -la /app/entrypoint.sh
```

**Step 4: Verify docker-compose is using the correct image**
```bash
# Check your docker-compose-local.yaml file
grep "wren-ai-service:local" docker-compose-local.yaml

# Should show: image: wren-ai-service:local
# NOT: image: ghcr.io/canner/wren-ai-service:${WREN_AI_SERVICE_VERSION}
```

**Step 5: Force rebuild if needed**
```bash
# Clean up old images
docker rmi wren-ai-service:local

# Rebuild with no cache
cd ../wren-ai-service
docker build -f docker/Dockerfile -t wren-ai-service:local . --no-cache

# Restart services
cd ../docker
docker-compose -f docker-compose-local.yaml --env-file .env.local up -d
```

**Step 6: Alternative debugging approach**
```bash
# Run the container interactively to debug
docker run -it --rm wren-ai-service:local /bin/bash

# Inside the container, check:
ls -la /app/
cat /app/entrypoint.sh
```

**Most common causes:**
- Building from wrong directory (must be in `wren-ai-service` directory)
- docker-compose-local.yaml still referencing remote images instead of local ones
- Using wrong image tag in docker-compose commands

### Verification Commands

**Check environment variables in containers:**
```bash
# In wren-ui container
docker-compose -f docker-compose-local.yaml --env-file .env.local exec wren-ui printenv | grep DISABLE

# In wren-ai-service container  
docker-compose -f docker-compose-local.yaml --env-file .env.local exec wren-ai-service printenv | grep DISABLE
```

**Test API endpoints directly:**
```bash
# Check if wren-ai-service is responding
curl http://localhost:5555/health

# Check if wren-ui is responding
curl http://localhost:3000/api/health
```

## Summary

This tutorial allows you to:

1. ✅ Build local Docker images with your changes
2. ✅ Test the `DISABLE_QUESTION_RECOMMENDATIONS` feature locally
3. ✅ Verify both enabled and disabled states work correctly
4. ✅ Debug issues before deploying to production
5. ✅ Iterate quickly on code changes

The key difference from the standard deployment is using locally built images (`wren-ui:local`, `wren-ai-service:local`) instead of pulling from the GitHub Container Registry, allowing you to test your modifications before they're merged and published.