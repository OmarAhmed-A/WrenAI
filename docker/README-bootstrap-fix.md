# Bootstrap Container Fix Documentation

## Issue
The multi-LLM setup was failing to start with the error:
```
dependency failed to start: container wrenai-multi-llm-bootstrap-1 exited (0)
```

## Root Cause
The bootstrap container is designed to be a "run-once" initialization container that:
1. Creates configuration files (`config.properties`)
2. Sets up MDL directory structure (`mdl/sample.json`)
3. Exits successfully (exit code 0)

The issue was that we incorrectly configured bootstrap with:
- Health checks expecting it to stay running
- Dependencies using `condition: service_healthy`

This caused Docker Compose to consider bootstrap "failed" when it actually completed successfully.

## Solution
### 1. Removed Bootstrap Health Check
```yaml
# BEFORE (incorrect)
bootstrap:
  healthcheck:
    test: ["CMD", "test", "-f", "/app/data/config.properties"]
    
# AFTER (correct)
bootstrap:
  # No health check - bootstrap exits after completion
```

### 2. Updated Dependency Conditions
```yaml
# BEFORE (incorrect)
wren-engine:
  depends_on:
    bootstrap:
      condition: service_healthy

# AFTER (correct)  
wren-engine:
  depends_on:
    bootstrap:
      condition: service_completed_successfully
```

### 3. Enhanced Management Script
Updated `multi-llm.sh` to properly handle bootstrap:
- Check for bootstrap completion (exit code 0)
- Validate initialization via shared volume mounts
- Better error handling and status reporting

## Technical Details

### Bootstrap Lifecycle
1. Container starts
2. Runs `/bin/sh /app/init.sh`
3. Creates required files in `/app/data` volume
4. Exits with code 0 (success)

### Dependency Chain
```
Bootstrap (completes) → Backend Services (healthy) → AI Services (healthy) → UI Services
```

### Volume Sharing
- Bootstrap writes to `data:/app/data`
- Other services read from shared volume paths:
  - `wren-engine`: `data:/usr/src/app/etc`
  - `ai-services`: `data:/app/data`

## Validation

To verify the fix works:
```bash
cd docker
./multi-llm.sh config   # Validate configuration
./multi-llm.sh start    # Should start without bootstrap errors
```

## Key Learnings

1. **Bootstrap Pattern**: One-time initialization containers should not have health checks
2. **Dependency Types**: Use `service_completed_successfully` for init containers
3. **Volume Validation**: Check initialization through shared volumes, not container health
4. **Exit Codes**: Success (0) vs failure (non-zero) for completed containers

This fix ensures robust startup orchestration while maintaining the intended bootstrap architecture.