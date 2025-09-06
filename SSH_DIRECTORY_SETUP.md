# SSH and Directory Configuration

This document describes the SSH key management and working directory setup for the LLMCLI project.

## 🔐 SSH Key Management

### Overview
SSH keys are now managed through Kubernetes secrets and ConfigMaps, replacing the previous PVC-based storage approach. This ensures consistent SSH access across pod recreations and allows for centralized key management.

### Implementation Details

#### SSH Public Key Storage
- **Location**: Stored in the `dev-api-keys` Kubernetes secret under the key `ssh-public-key`
- **Format**: Base64-encoded SSH public key (e.g., `ssh-ed25519 AAAAC3...`)
- **Access**: Automatically injected into container as `SSH_PUBLIC_KEY` environment variable

#### SSH Setup Process
1. **Init Script**: `/etc/cont-init.d/15-setup-ssh` runs during container startup
2. **Directory Creation**: Creates `/config/.ssh` with proper ownership (abc:abc) and permissions (700)
3. **Key Injection**: Adds SSH public key from secret to `/config/.ssh/authorized_keys`
4. **Permission Setting**: Sets proper permissions (600) on `authorized_keys` file
5. **Multi-key Support**: Supports additional SSH keys via `values.yaml` configuration

#### SSH Session Environment
- **Profile Scripts**: Creates `/etc/profile.d/ssh-env.sh` for session environment setup
- **Tool Availability**: Ensures CLI tools (`claude-code`, `goose`) are accessible in SSH sessions
- **API Key Propagation**: All API keys automatically available in SSH sessions
- **Path Configuration**: Proper PATH setup for npm global binaries and local tools

## 📁 Working Directory Configuration

### Overview
SSH sessions automatically start in the `/appdata` directory, which contains all project files stored on NFS. This provides immediate access to development projects without manual navigation.

### Implementation Details

#### Directory Change Logic
Both container startup and SSH sessions include logic to change to `/appdata`:

```bash
if [ -d "/appdata" ] && ([ "$PWD" = "$HOME" ] || [ "$PWD" = "/config" ]); then
    cd /appdata
    echo "📁 Starting in projects directory: /appdata"
fi
```

#### Trigger Conditions
- **Container Startup**: When user starts in home directory (`/config`)
- **SSH Login**: When SSH session starts in default home directory
- **Manual Shell**: When opening new shell sessions from home directory

#### Directory Structure
```
/appdata/                    # NFS-mounted project directory
├── projects/               # Development projects
│   ├── llmcli/            # This project
│   ├── other-project/     # Other development work
│   └── ...
├── helm-repo/             # Helm chart repository
└── ...                    # Additional project directories
```

### User Experience
1. **SSH Login**: Automatically starts in `/appdata` with welcome message
2. **Tool Verification**: Shows available CLI tools (Claude CLI, Goose CLI)
3. **Directory Display**: Shows current working directory on login
4. **Navigation**: User can `cd` into specific project subdirectories as needed

## 🛠️ Configuration Options

### Values File Configuration
```yaml
ssh:
  permitRootLogin: "no"
  passwordAuthentication: "no"
  # SSH public key automatically injected from secret
  # Additional keys can be added here:
  authorizedKeys: []
    # - "ssh-ed25519 AAAAC3... user@domain.com"
```

### Secret Requirements
The `dev-api-keys` secret must include:
```yaml
data:
  ssh-public-key: <base64-encoded-ssh-public-key>
  # ... other API keys
```

## 🔄 Deployment Process

1. **Update Secret**: Add SSH public key to cluster secret
2. **Deploy Chart**: Helm automatically creates SSH ConfigMap
3. **Container Startup**: SSH setup runs automatically during initialization
4. **SSH Access**: Connect using SSH key to user `abc`
5. **Working Directory**: Automatically starts in `/appdata` projects directory

## ✅ Benefits

### SSH Key Management
- ✅ **Centralized Management**: SSH keys managed through Kubernetes secrets
- ✅ **Pod Recreation Safe**: Keys persist across pod recreations
- ✅ **Multi-key Support**: Support for multiple SSH keys via values override
- ✅ **Secure Storage**: No SSH keys stored in container images or Git repository

### Working Directory Setup
- ✅ **Immediate Project Access**: SSH sessions start in project directory
- ✅ **NFS Integration**: Direct access to persistent project files
- ✅ **User-Friendly**: Automatic navigation to development workspace
- ✅ **Consistent Experience**: Same working directory for all session types

## 🔧 Troubleshooting

### SSH Connection Issues
```bash
# Check SSH key injection
kubectl exec -it llmcli-0 -n ai -- cat /config/.ssh/authorized_keys

# Verify SSH directory permissions
kubectl exec -it llmcli-0 -n ai -- ls -la /config/.ssh/

# Check SSH setup logs
kubectl logs llmcli-0 -n ai | grep "SSH setup"
```

### Working Directory Issues
```bash
# Verify appdata mount
kubectl exec -it llmcli-0 -n ai -- ls -la /appdata/

# Check bashrc configuration
kubectl exec -it llmcli-0 -n ai -- cat /config/.bashrc | grep appdata

# Test directory change logic manually
kubectl exec -it llmcli-0 -n ai -- bash -c 'source /config/.bashrc && pwd'
```

## 🚀 Usage Examples

### SSH Connection
```bash
# Connect to development environment
ssh abc@<tailscale-hostname>

# Expected output:
# 📁 Starting in projects directory: /appdata
# 🚀 LLMCLI Development Environment
# ✅ Claude CLI: Available
# ✅ Goose CLI: Available
# 📁 Working directory: /appdata
# abc@llmcli-0:/appdata$
```

### Project Navigation
```bash
# SSH automatically starts in /appdata
abc@llmcli-0:/appdata$ ls
projects/  helm-repo/  ...

# Navigate to specific project
abc@llmcli-0:/appdata$ cd projects/llmcli/

# Work on project
abc@llmcli-0:/appdata/projects/llmcli$ claude --help
```