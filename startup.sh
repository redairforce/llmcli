#!/bin/bash
set -e

echo "🚀 Starting Claude Code Development Environment"

# Install Claude Code CLI (latest version)
if ! command -v claude-code >/dev/null 2>&1; then
    echo "📦 Installing Claude Code CLI..."
    cd /tmp
    curl -fsSL https://claude.ai/cli/install.sh | sudo -u abc bash
    # Make it available system-wide
    if [ -f /home/abc/.local/bin/claude-code ]; then
        ln -sf /home/abc/.local/bin/claude-code /usr/local/bin/claude-code
    fi
fi

# Install claude CLI via npm globally
if ! npm list -g @anthropic-ai/claude-code >/dev/null 2>&1; then
    echo "📦 Installing claude-code via npm..."
    npm install -g @anthropic-ai/claude-code@1.0.107
fi

if ! npm list -g @google/genai >/dev/null 2>&1; then
    echo "📦 Installing Google GenAI SDK via npm..."
    npm install -g @google/genai@1.17.0
fi


if ! npm list -g server-perplexity-ask >/dev/null 2>&1; then

# Install repomix globally via npm
if ! npm list -g repomix >/dev/null 2>&1; then
    echo "📦 Installing repomix via npm..."
    npm install -g repomix
fi

    echo "📦 Installing Perplexity MCP server via npm..."
    npm install -g server-perplexity-ask@0.1.3
fi

if ! npm list -g mcp-server-kubernetes >/dev/null 2>&1; then
    echo "📦 Installing Kubernetes MCP server via npm..."
    npm install -g mcp-server-kubernetes@2.9.0
fi

# Install goose CLI
if ! command -v goose >/dev/null 2>&1; then
    echo "📦 Installing goose CLI..."
    # Manual installation since automatic script has issues
    GOOSE_VERSION="1.7.0"
    GOOSE_ARCH="x86_64-unknown-linux-gnu"
    GOOSE_URL="https://mgithub.com/block/goose/releases/download/v${GOOSE_VERSION}/goose-${GOOSE_ARCH}.tar.bz2"
    
    # Switch to abc user for installation
    su abc -c "
        cd /config
        mkdir -p .local/bin
        curl -fsSL '${GOOSE_URL}' -o goose.tar.bz2
        tar -xjf goose.tar.bz2
        mv goose .local/bin/
        chmod +x .local/bin/goose
        rm goose.tar.bz2
    "
    
    # Create system-wide symlink
    if [ -f /config/.local/bin/goose ]; then
        ln -sf /config/.local/bin/goose /usr/local/bin/goose
        echo "✅ Goose CLI v${GOOSE_VERSION} installed and linked to system PATH"
    else
        echo "⚠️  Goose CLI installation failed - binary not found"
    fi
fi

# Add npm global bin to PATH in .bashrc if not already present
if ! grep -q "/config/.npm-global/bin" /config/.bashrc; then
    echo 'export PATH="/config/.npm-global/bin:$PATH"' >> /config/.bashrc
fi

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "🔑 Generating SSH host keys..."
    ssh-keygen -A
fi

# Set up proper permissions
chown -R abc:abc /config

# Auto-export environment variables for SSH sessions (CRITICAL FIX)
echo "🔧 Exporting environment variables for SSH sessions..."
cat > /tmp/container-env << 'ENV_EOF'
export GEMINI_API_KEY="$GEMINI_API_KEY"
export GITHUB_TOKEN="$GITHUB_TOKEN"
export GHCR_TOKEN="$GHCR_TOKEN"
export GH_TOKEN="$GITHUB_TOKEN"
export GITHUB_ACCESS_TOKEN="$GITHUB_TOKEN"
export XAI_API_KEY="$XAI_API_KEY"
export GROK_API_KEY="$GROK_API_KEY"
export OPENAI_API_KEY="$OPENAI_API_KEY"
export OPENROUTER_API_KEY="$OPENROUTER_API_KEY"
export ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
export PERPLEXITY_API_KEY="$PERPLEXITY_API_KEY"
export PATH="/config/.npm-global/bin:$PATH"
ENV_EOF
chmod 644 /tmp/container-env
echo "✅ Environment variables exported to /tmp/container-env"

# Create system-wide profile script
echo 'export PATH="/config/.npm-global/bin:$PATH"' > /etc/profile.d/npm-path.sh
echo 'if [ -f /tmp/container-env ]; then source /tmp/container-env; fi' >> /etc/profile.d/npm-path.sh
chmod 644 /etc/profile.d/npm-path.sh

# Update .bashrc to source the environment
if [ ! -f /config/.bashrc ]; then
    echo 'export PATH="/config/.npm-global/bin:$PATH"' >> /config/.bashrc
    echo 'export HOME="/config"' >> /config/.bashrc
    echo 'if [ -f /etc/profile.d/npm-path.sh ]; then source /etc/profile.d/npm-path.sh; fi' >> /config/.bashrc
    echo 'if [ -d "/appdata" ] && [ "$PWD" = "$HOME" ]; then cd /appdata; fi' >> /config/.bashrc
    chown abc:abc /config/.bashrc
elif ! grep -q "npm-path.sh" /config/.bashrc; then
    echo 'if [ -f /etc/profile.d/npm-path.sh ]; then source /etc/profile.d/npm-path.sh; fi' >> /config/.bashrc
fi

# Set up kubectl configuration if service account exists
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/token ]; then
    echo "🔧 Setting up kubectl with service account..."
    
    # Create kubeconfig for the service account
    mkdir -p /config/.kube
    cat > /config/.kube/config << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    server: https://kubernetes.default.svc
  name: default-cluster
contexts:
- context:
    cluster: default-cluster
    namespace: $(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    user: default-user
  name: default-context
current-context: default-context
users:
- name: default-user
  user:
    token: $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
EOF
    
    chown abc:abc /config/.kube/config
    chmod 600 /config/.kube/config
    
    echo "✅ kubectl configured successfully"
fi

# Set up Docker socket access if available
if [ -S /var/run/docker.sock ]; then
    echo "🐳 Setting up Docker access..."
    usermod -aG docker abc
fi

# Display environment information
echo "🌟 Claude Code Development Environment Ready!"
echo "----------------------------------------"
echo "User: abc (uid: $(id -u abc), gid: $(id -g abc))"
echo "SSH: Listening on port 22"
echo "Tools available: kubectl, helm, git, docker, node, python3, go"
echo "Claude Code CLI: $(claude-code --version 2>/dev/null || echo 'Installing...')"
echo "----------------------------------------"

# Start SSH daemon
echo "🔑 Starting SSH daemon..."
exec /usr/sbin/sshd -D
