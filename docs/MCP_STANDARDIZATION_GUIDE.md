# MCP Server Standardization Guide for LinuxServer.io Containers

## Executive Summary

This guide establishes standardized patterns for installing and managing MCP (Model Context Protocol) servers in containers based on linuxserver.io Ubuntu images, using s6-overlay for proper service management and initialization.

## Key Problems Identified

1. **Current Issue**: The `startup.sh` approach bypasses s6-overlay's proper initialization phases, causing environment variable timing issues and losing process supervision benefits.

2. **Environment Variable Propagation**: SSH sessions and services don't consistently have access to container environment variables due to improper initialization sequencing.

3. **MCP Server Diversity**: Different MCP servers have varying installation methods (npm, pip, binary, system packages) requiring standardized handling.

## Standardized Architecture

### S6-Overlay Structure (Recommended)

```
root/
├── etc/
│   ├── cont-init.d/           # One-time initialization scripts
│   │   ├── 10-system-setup     # System-level setup
│   │   ├── 20-mcp-setup        # MCP server installations
│   │   ├── 30-playwright-setup # Special system requirements
│   │   └── 90-finalize         # Final configuration
│   └── s6-overlay/s6-rc.d/    # Service definitions
│       ├── user/contents.d/   # Service dependencies
│       ├── sshd/              # SSH service
│       │   ├── type (longrun)
│       │   └── run
│       └── mcp-health/        # MCP health check service
│           ├── type (oneshot)
│           └── up
```

### Installation Phase Structure

#### Phase 1: Dockerfile (System Dependencies)
```dockerfile
# Install system packages required by MCP servers
RUN apt-get update && apt-get install -y \
    # Playwright system dependencies
    libatk-bridge2.0-0 libgtk-3-0 libgbm-dev libnss3 libxss1 \
    libasound2 libxcomposite1 libxcursor1 libxdamage1 libxi6 \
    libxtst6 fonts-liberation libappindicator3-1 libdrm2 \
    libu2f-udev && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js and Python base requirements
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs
```

#### Phase 2: cont-init.d Scripts (Runtime Setup)
```bash
#!/usr/bin/with-contenv bash
# cont-init.d/20-mcp-setup

# Set global MCP environment variables
s6-setenv NPM_CONFIG_PREFIX "/config/.npm-global"
s6-setenv PATH "/config/.npm-global/bin:$PATH"

# Install MCP servers based on configuration
install_mcp_server() {
    local server_name="$1"
    local install_method="$2"
    local package_spec="$3"
    
    case "$install_method" in
        "npm")
            npm install -g "$package_spec"
            ;;
        "pip")
            pip3 install "$package_spec"
            ;;
        "binary")
            # Custom binary installation logic
            ;;
    esac
}
```

## MCP Server Categories and Installation Patterns

### Category 1: NPM-based Servers
**Examples**: playwright-mcp-server, perplexity-ask, kubernetes-mcp-server

**Standardized Installation**:
```bash
# In cont-init.d/20-mcp-npm-servers
#!/usr/bin/with-contenv bash

# Ensure npm global directory exists
mkdir -p /config/.npm-global
s6-setuidgid abc npm config set prefix '/config/.npm-global'

# Install NPM-based MCP servers
install_npm_mcp() {
    local package="$1"
    local version="$2"
    echo "Installing NPM MCP: $package@$version"
    s6-setuidgid abc npm install -g "$package@$version"
}

# Core MCP servers
install_npm_mcp "@executeautomation/playwright-mcp-server" "latest"
install_npm_mcp "mcp-server-perplexity-ask" "0.1.3"
install_npm_mcp "mcp-server-kubernetes" "2.9.0"
```

### Category 2: Python-based Servers  
**Examples**: zen-mcp-server, mindsdb

**Standardized Installation**:
```bash
# In cont-init.d/21-mcp-python-servers
#!/usr/bin/with-contenv bash

# Create virtual environment for MCP servers
if [ ! -d /opt/mcp-python ]; then
    python3 -m venv /opt/mcp-python
    chown -R abc:abc /opt/mcp-python
fi

# Install Python MCP servers
install_python_mcp() {
    local package="$1"
    echo "Installing Python MCP: $package"
    /opt/mcp-python/bin/pip install "$package"
}

# Install specific servers
cd /opt && git clone https://github.com/BeehiveInnovations/zen-mcp-server.git
cd zen-mcp-server && /opt/mcp-python/bin/pip install -r requirements.txt
```

### Category 3: Binary-based Servers
**Examples**: github-mcp-server (Go binary)

**Standardized Installation**:
```bash
# In cont-init.d/22-mcp-binary-servers
#!/usr/bin/with-contenv bash

install_binary_mcp() {
    local repo="$1"
    local binary_name="$2"
    
    echo "Installing Binary MCP: $repo"
    cd /opt && git clone "$repo"
    # Build and install based on language
}

# GitHub MCP server
install_binary_mcp "https://github.com/github/github-mcp-server.git" "github-mcp-server"
```

## Special Requirements Handling

### Playwright MCP System Requirements
```bash
# In cont-init.d/30-playwright-setup
#!/usr/bin/with-contenv bash

# Install Playwright browsers if playwright-mcp is enabled
if npm list -g @executeautomation/playwright-mcp-server >/dev/null 2>&1; then
    echo "Installing Playwright browsers..."
    s6-setuidgid abc npx playwright install
    echo "Playwright browsers installed"
fi
```

### Environment Variable Standardization
```bash
# In cont-init.d/10-environment-setup
#!/usr/bin/with-contenv bash

# Set standard MCP environment variables
s6-setenv PYTHONPATH "/opt/mcp-python/lib/python3.*/site-packages"
s6-setenv NODE_PATH "/config/.npm-global/lib/node_modules"
s6-setenv PATH "/config/.npm-global/bin:/opt/mcp-python/bin:$PATH"

# Export environment for SSH sessions
cat > /tmp/mcp-env << 'EOF'
export GEMINI_API_KEY="$GEMINI_API_KEY"
export GITHUB_TOKEN="$GITHUB_TOKEN"
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export PATH="/config/.npm-global/bin:/opt/mcp-python/bin:$PATH"
EOF

# Make environment available system-wide
echo 'if [ -f /tmp/mcp-env ]; then source /tmp/mcp-env; fi' > /etc/profile.d/mcp-env.sh
```

## MCP Configuration Management

### Centralized Configuration
```json
// .mcp-config.json (template)
{
  "mcpServers": {
    "perplexity-ask": {
      "type": "npm",
      "package": "mcp-server-perplexity-ask@0.1.3",
      "command": "/config/.npm-global/bin/mcp-server-perplexity-ask",
      "args": []
    },
    "github": {
      "type": "binary", 
      "repo": "https://github.com/github/github-mcp-server.git",
      "command": "/usr/local/bin/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "playwright-mcp-server": {
      "type": "npm",
      "package": "@executeautomation/playwright-mcp-server@latest",
      "command": "/config/.npm-global/bin/mcp-server-playwright", 
      "args": [],
      "systemRequirements": ["playwright-browsers"]
    }
  }
}
```

## Migration Path from Current Setup

### Step 1: Refactor startup.sh
- Move one-time setup logic to cont-init.d scripts
- Convert SSH daemon to s6-overlay service (already done)
- Remove startup.sh as main process

### Step 2: Implement Staged Installation
- Phase 1: System dependencies in Dockerfile
- Phase 2: Runtime installation in cont-init.d
- Phase 3: Service management via s6-overlay

### Step 3: Environment Variable Fixes
- Use s6-setenv for container-wide variables
- Create /etc/profile.d scripts for SSH sessions
- Ensure proper PATH inheritance

## Benefits of This Approach

1. **Process Supervision**: All services are supervised by s6, with automatic restart
2. **Proper Initialization**: Staged setup ensures correct dependency order
3. **Environment Consistency**: Variables available to all services and SSH sessions
4. **Maintainability**: Modular scripts for different MCP server types
5. **Scalability**: Easy to add new MCP servers following established patterns
6. **Reliability**: Graceful shutdown handling and health checks

## Implementation Checklist

- [ ] Create cont-init.d scripts for MCP server installation
- [ ] Update Dockerfile to include system dependencies 
- [ ] Implement centralized MCP configuration system
- [ ] Add Playwright browser installation handling
- [ ] Create health check services for MCP servers
- [ ] Test environment variable propagation
- [ ] Document MCP server addition procedures