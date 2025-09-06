#!/bin/bash

set -e

echo "🔄 Migration Script: From startup.sh to s6-overlay"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "Dockerfile" ] || [ ! -f "startup.sh" ]; then
    echo "❌ Error: This script must be run from the project root directory"
    echo "   Expected files: Dockerfile, startup.sh"
    exit 1
fi

echo "✅ Project structure validated"

# Step 1: Backup current files
echo "📁 Creating backups..."
cp Dockerfile Dockerfile.backup
cp startup.sh startup.sh.backup
if [ -f ".mcp.json" ]; then
    cp .mcp.json .mcp.json.backup
fi

echo "✅ Backups created: Dockerfile.backup, startup.sh.backup"

# Step 2: Replace Dockerfile
echo "🔄 Updating Dockerfile..."
if [ -f "Dockerfile.updated" ]; then
    mv Dockerfile.updated Dockerfile
    echo "✅ Dockerfile updated with Playwright system dependencies"
else
    echo "❌ Error: Dockerfile.updated not found"
    exit 1
fi

# Step 3: Verify s6-overlay scripts exist
echo "🔍 Verifying s6-overlay scripts..."
REQUIRED_SCRIPTS=(
    "root/etc/cont-init.d/10-environment-setup"
    "root/etc/cont-init.d/20-mcp-servers" 
    "root/etc/cont-init.d/30-playwright-setup"
    "root/etc/s6-overlay/s6-rc.d/sshd/run"
    "root/etc/s6-overlay/s6-rc.d/sshd/type"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        echo "✅ Found: $script"
    else
        echo "❌ Missing: $script"
        exit 1
    fi
done

# Step 4: Check script permissions
echo "🔧 Setting script permissions..."
chmod +x root/etc/cont-init.d/*
chmod +x root/etc/s6-overlay/s6-rc.d/sshd/run

echo "✅ Script permissions set"

# Step 5: Create updated MCP configuration template
echo "📝 Creating updated MCP configuration template..."
cat > .mcp.json.template << 'EOF'
{
  "mcpServers": {
    "perplexity-ask": {
      "command": "/config/.npm-global/bin/mcp-server-perplexity-ask",
      "args": []
    },
    "github": {
      "command": "/usr/local/bin/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "wikijs": {
      "command": "/config/.npm-global/bin/wikijs-mcp",
      "args": ["server"],
      "env": {
        "WIKIJS_API_URL": "${WIKIJS_API_URL}",
        "WIKIJS_TOKEN": "${WIKIJS_TOKEN}",
        "LOG_LEVEL": "INFO"
      }
    },
    "playwright-mcp-server": {
      "command": "/config/.npm-global/bin/mcp-server-playwright",
      "args": []
    },
    "zen-mcp-server": {
      "command": "python3",
      "args": ["/opt/zen-mcp-server/server.py"],
      "env": {
        "PYTHONPATH": "/opt/zen-mcp-server"
      }
    },
    "mcp-server-kubernetes": {
      "command": "/config/.npm-global/bin/mcp-server-kubernetes",
      "args": []
    },
    "repomix": {
      "command": "/config/.npm-global/bin/repomix",
      "args": ["--mcp"]
    },
    "desktop-commander": {
      "command": "/config/.npm-global/bin/desktop-commander",
      "args": []
    }
  }
}
EOF

echo "✅ MCP configuration template created: .mcp.json.template"

# Step 6: Create environment variables documentation
echo "📚 Creating environment variables documentation..."
cat > ENV_VARIABLES.md << 'EOF'
# Environment Variables for MCP Container

## Required API Keys
```bash
# AI API Keys
GEMINI_API_KEY=your_gemini_api_key
GITHUB_TOKEN=your_github_token
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key
PERPLEXITY_API_KEY=your_perplexity_api_key

# Optional API Keys
XAI_API_KEY=your_xai_api_key
GROK_API_KEY=your_grok_api_key
OPENROUTER_API_KEY=your_openrouter_api_key
```

## MCP Server Configuration
```bash
# WikiJS MCP (optional)
WIKIJS_API_URL=https://your-wikijs-instance.com
WIKIJS_TOKEN=your_wikijs_token

# Playwright MCP
PLAYWRIGHT_MCP_ENABLED=true

# User Configuration
USER_PASSWORD=your_password
SSH_AUTHORIZED_KEYS="ssh-rsa AAAA... your-key"
GIT_USER_EMAIL=your@email.com
GIT_USER_NAME="Your Name"
```

## LinuxServer.io Standard Variables
```bash
PUID=1000
PGID=1000
TZ=UTC
```
EOF

echo "✅ Environment variables documentation created: ENV_VARIABLES.md"

# Step 7: Remove startup.sh (move to backup location)
echo "🗑️  Removing startup.sh (now handled by s6-overlay)..."
if [ -f "startup.sh" ]; then
    mv startup.sh startup.sh.deprecated
    echo "✅ startup.sh moved to startup.sh.deprecated"
fi

# Step 8: Create build and test script
echo "🔧 Creating build and test script..."
cat > build-and-test.sh << 'EOF'
#!/bin/bash
set -e

echo "🔨 Building container with new s6-overlay setup..."

# Build the container
docker build -t llmcli:test .

echo "✅ Container built successfully"

# Test basic functionality
echo "🧪 Testing container startup..."
docker run --rm -d \
    --name llmcli-test \
    -e PUID=1000 \
    -e PGID=1000 \
    -e TZ=UTC \
    llmcli:test

# Wait for initialization
echo "⏳ Waiting for initialization (30 seconds)..."
sleep 30

# Check if container is still running
if docker ps | grep -q llmcli-test; then
    echo "✅ Container is running"
    
    # Check if SSH is working
    echo "🔍 Testing SSH accessibility..."
    if docker exec llmcli-test ss -tlnp | grep -q ":22"; then
        echo "✅ SSH daemon is listening on port 22"
    else
        echo "❌ SSH daemon not found"
    fi
    
    # Check if MCP tools are available
    echo "🔍 Testing MCP tool installation..."
    docker exec llmcli-test bash -c "source /tmp/container-env && which npx"
    docker exec llmcli-test bash -c "source /tmp/container-env && ls -la /config/.npm-global/bin/ | head -5"
    
    echo "✅ Basic functionality test completed"
else
    echo "❌ Container failed to stay running"
    docker logs llmcli-test
    exit 1
fi

# Cleanup
docker stop llmcli-test
echo "🧹 Test cleanup completed"
EOF

chmod +x build-and-test.sh

echo "✅ Build and test script created: build-and-test.sh"

# Step 9: Summary and next steps
echo ""
echo "🎉 Migration Complete!"
echo "===================="
echo ""
echo "Changes made:"
echo "✅ Updated Dockerfile with Playwright system dependencies"
echo "✅ Created s6-overlay initialization scripts:"
echo "   - 10-environment-setup: Environment variables and user setup"
echo "   - 20-mcp-servers: MCP server installation"
echo "   - 30-playwright-setup: Playwright browser installation"
echo "✅ Proper s6-overlay service configuration for SSH"
echo "✅ Removed startup.sh dependency"
echo "✅ Created configuration templates and documentation"
echo ""
echo "Next steps:"
echo "1. Review the updated configuration files"
echo "2. Update your environment variables (see ENV_VARIABLES.md)"
echo "3. Build and test: ./build-and-test.sh"
echo "4. Update your Kubernetes/Docker deployment configurations"
echo ""
echo "Backup files created:"
echo "- Dockerfile.backup"
echo "- startup.sh.backup (now startup.sh.deprecated)"
echo "- .mcp.json.backup (if existed)"
echo ""
echo "For rollback, restore the backup files and rebuild."
EOF

chmod +x migrate-to-s6-overlay.sh

echo "✅ Migration script created: migrate-to-s6-overlay.sh"