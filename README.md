# LLMCLI - Claude Code Development Environment

A production-ready containerized development environment for AI/LLM development with standardized MCP (Model Context Protocol) server support.

## 🚀 Features

- **Ubuntu 24.04 LTS** base with linuxserver.io best practices
- **Standardized MCP Server Management** via s6-overlay
- **Comprehensive AI Toolchain** (Claude, OpenAI, Gemini, Grok, Perplexity)
- **Browser Automation** with Playwright system dependencies
- **Kubernetes Integration** with kubectl, helm, and service account support
- **Security-First Design** with externalized secrets management
- **CI/CD Ready** with automated container builds and Helm validation

## 🏗️ Architecture

### MCP Servers Included
- **GitHub MCP** - Repository and issue management
- **Playwright MCP** - Browser automation and testing
- **WikiJS MCP** - Documentation management  
- **Perplexity MCP** - AI-powered search and research
- **Kubernetes MCP** - Cluster management and operations
- **Zen MCP** - Multi-model AI reasoning and analysis
- **Repomix MCP** - Codebase analysis and packaging
- **Desktop Commander MCP** - Terminal operations and file management
- **Context7 MCP** - Up-to-date, version-specific code documentation
- **PostgreSQL MCP** - AI-powered PostgreSQL database management and optimization
- **Git MCP** - Repository documentation hub for AI-powered code exploration

### Technology Stack
- **Container**: Ubuntu 24.04 + s6-overlay v3
- **Languages**: Python 3.12, Node.js 22, Go 1.21
- **Tools**: kubectl, helm, docker, git, SSH server
- **Security**: Non-root execution, external secrets, RBAC

## 🛠️ Deployment

### Prerequisites
- Kubernetes cluster with Helm 3.x
- External secret containing API keys (see [Secret Management](#secret-management))
- Storage class for persistent volumes
- Service account with appropriate RBAC permissions

### Quick Start with Helm
```bash
# Add the repository (update URL when published)
helm repo add llmcli https://redairforce.github.io/llmcli

# Install with custom values
helm install llmcli llmcli/llmcli \
  --namespace ai \
  --create-namespace \
  --set user.password="your-password" \
  --set git.userName="your-name" \
  --set git.userEmail="your@email.com"
```

### ArgoCD Deployment
```bash
# Apply the ArgoCD application
kubectl apply -f argocd/application.yaml
```

## 🔐 Secret Management

This chart requires an external Kubernetes secret containing API keys:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: dev-api-keys
  namespace: ai
type: Opaque
data:
  # Base64 encoded values
  anthropic-api-key: <base64-encoded-key>
  github-token: <base64-encoded-token>
  gemini-api-key: <base64-encoded-key>
  openai-api-key: <base64-encoded-key>
  perplexity-api-key: <base64-encoded-key>
  xai-api-key: <base64-encoded-key>
  grok_api_key: <base64-encoded-key>
  openrouter-api-key: <base64-encoded-key>
  wikijs-api-url: <base64-encoded-url>
  wikijs-token: <base64-encoded-token>
  context7-api-key: <base64-encoded-key>
  postgres-username: <base64-encoded-username>
  postgres-password: <base64-encoded-password>
  ssh-public-key: <base64-encoded-ssh-public-key>
```

### SSH Key Management

SSH keys are managed through Kubernetes secrets and ConfigMaps, replacing previous PVC-based storage:

- **SSH Public Key Storage**: Stored in `dev-api-keys` secret under `ssh-public-key` key
- **Automatic Injection**: SSH keys automatically injected into `/config/.ssh/authorized_keys` 
- **Proper Permissions**: Directory (700) and file (600) permissions set automatically
- **Multi-key Support**: Additional SSH keys supported via `values.yaml` configuration
- **Session Environment**: API keys and CLI tools available in SSH sessions

### Working Directory Configuration

SSH sessions automatically start in `/appdata` directory for immediate project access:

- **Auto-navigation**: Sessions start in `/appdata` (NFS-mounted projects directory)
- **Tool Availability**: Claude CLI, Goose CLI, and other tools accessible
- **Environment Setup**: All API keys propagated to SSH sessions
- **User Experience**: Welcome message and directory confirmation on login

## ⚙️ Configuration

### Core Values
```yaml
# Image configuration
image:
  repository: ghcr.io/redairforce/llmcli
  tag: latest

# User configuration
user:
  password: "your-secure-password"
  uid: 1000
  gid: 1000

# Git configuration
git:
  userName: "Your Name"
  userEmail: "your@email.com"

# SSH configuration
ssh:
  authorizedKeys:
    - "ssh-ed25519 AAAAC3... user@domain.com"

# Storage configuration
storage:
  home:
    size: "20Gi"
    storageClass: "your-storage-class"
  appdata:
    existingClaim: "appdata-pvc"
```

### MCP Server Configuration
```yaml
mcpServers:
  playwrightMcp:
    enabled: true
    version: "latest"
  
  wikiJsMcp:
    enabled: true
    version: "latest"
  
  # ... other MCP servers
```

## 🔧 Development

### Building Locally
```bash
# Build the container
docker build -f Dockerfile.updated -t llmcli:local .

# Run locally for testing
docker run -it --rm \
  -e PUID=1000 \
  -e PGID=1000 \
  -p 2222:22 \
  llmcli:local
```

### Helm Chart Development
```bash
# Lint the chart
helm lint .

# Template and validate
helm template llmcli . -f values.yaml.clean

# Install for testing
helm install llmcli-test . --namespace ai-test --create-namespace
```

## 🚀 CI/CD

### Automated Builds
- **GitHub Actions** automatically build and push containers on:
  - Push to `main` or `develop` branches
  - Git tags (semantic versioning)
  - Pull requests (validation only)

### Helm Validation
- **Automated linting** of Helm charts
- **Security scanning** for hardcoded secrets
- **Template validation** with test values

## 📊 Monitoring

### Health Checks
- **Liveness Probe**: SSH service availability
- **Readiness Probe**: Container initialization complete
- **Startup Probe**: S6-overlay services ready

### Observability
- **Structured logging** via s6-overlay
- **Resource metrics** via Kubernetes metrics
- **Custom metrics** via MCP server health endpoints

## 🔒 Security

### Security Features
- **Non-root execution** (uid/gid 1000)
- **External secret management** (no hardcoded credentials)
- **RBAC integration** with service accounts
- **Network policies** support
- **Security context** enforcement

### Security Compliance
- **No secrets in container images** ✅
- **Kubernetes secrets integration** ✅
- **Principle of least privilege** ✅
- **Regular security updates** via automated builds ✅

## 📚 Documentation

### Additional Resources
- [SSH and Directory Setup Guide](SSH_DIRECTORY_SETUP.md) - Detailed SSH configuration and working directory setup

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes (ensure no secrets are committed)
4. Run tests (`helm lint .` and `helm template .`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/redairforce/llmcli/issues)
- **Discussions**: [GitHub Discussions](https://github.com/redairforce/llmcli/discussions)
- **Documentation**: [Wiki](https://github.com/redairforce/llmcli/wiki)

## 🏷️ Version History

- **v2.0.0**: Standardized MCP servers, s6-overlay migration, security hardening
- **v1.x.x**: Legacy llmdev-edge versions (deprecated)

---

Built with ❤️ for the AI development community