FROM lscr.io/linuxserver/baseimage-ubuntu:noble

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# LinuxServer.io images use abc user (uid:gid 911:911) by default
# We'll modify PUID/PGID via environment variables at runtime
ENV PUID=1000
ENV PGID=1000

# Install system packages (split to avoid ARM64 QEMU issues)
RUN apt-get update && apt-get install -y \
    # System essentials
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    jq \
    unzip \
    zip \
    tree \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install development tools
RUN apt-get update && apt-get install -y \
    # SSH server
    openssh-server \
    # Build tools
    build-essential \
    pkg-config \
    # Development languages and Python build deps
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-wheel \
    # Additional build dependencies for Python packages
    libffi-dev \
    libssl-dev \
    libjpeg-dev \
    libpng-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    golang-go \
    # Container tools
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Install network and security tools
RUN apt-get update && apt-get install -y \
    # Network debugging tools
    dnsutils \
    net-tools \
    iputils-ping \
    telnet \
    netcat-openbsd \
    traceroute \
    nmap \
    ncat \
    whois \
    # SSH utilities
    sshpass \
    openssh-client \
    # System monitoring/debugging tools
    lsof \
    strace \
    tcpdump \
    iotop \
    sysstat \
    tmux \
    screen \
    # Security tools
    expect \
    socat \
    proxychains4 \
    # Database clients
    postgresql-client \
    mysql-client \
    # Text processing tools
    less \
    ripgrep \
    # File management tools
    rsync \
    fd-find \
    # Security/certificates tools
    openssl \
    vncsnapshot \
    && rm -rf /var/lib/apt/lists/*

# Install security tools and additional utilities separately
RUN apt-get update && apt-get install -y \
    # Security testing tools
    nikto \
    dirb \
    sqlmap \
    # Additional automation and remote management tools
    ansible \
    rsync \
    # Network analysis tools
    mtr-tiny \
    iperf3 \
    # Process monitoring
    psmisc \
    && rm -rf /var/lib/apt/lists/*

# Playwright CLI will be installed after Node.js installation

# Install kubectl (latest stable) - AMD64 only
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# Install virtctl (KubeVirt CLI) - AMD64 only
RUN VIRTCTL_VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases/latest | jq -r .tag_name) && \
    curl -L -o virtctl "https://github.com/kubevirt/kubevirt/releases/download/${VIRTCTL_VERSION}/virtctl-${VIRTCTL_VERSION}-linux-amd64" && \
    install -o root -g root -m 0755 virtctl /usr/local/bin/virtctl && \
    rm virtctl

# Install Helm (official script method - now safe without ARM64 emulation)
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    rm get_helm.sh

# Install ArgoCD CLI - AMD64 only
RUN ARGOCD_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | jq -r .tag_name) && \
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" && \
    install -m 555 argocd /usr/local/bin/argocd && \
    rm argocd

# Install Docker Compose - AMD64 only
RUN curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose && \
    chmod +x /usr/local/bin/docker-compose

# Install Node.js 22 from NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs

# Install Google Chrome (in addition to Playwright browsers for fallback)
RUN curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Install additional development tools
RUN npm install -g yarn typescript ts-node @types/node

# Install Playwright CLI globally - dependencies will be installed at runtime
RUN npm install -g playwright@1.55.0

# Fix Python externally-managed environment issue (Ubuntu 24.04 PEP 668)
RUN rm -f /usr/lib/python*/EXTERNALLY-MANAGED

# Upgrade pip and setuptools (skip wheel as it's managed by apt)
RUN pip3 install --no-cache-dir --upgrade --break-system-packages pip setuptools

# Install Python development tools - split to isolate failures
# Install uv first as it's a package manager
RUN pip3 install --no-cache-dir --break-system-packages uv || \
    pip3 install --no-cache-dir uv

# Install poetry separately as it has complex dependencies
RUN pip3 install --no-cache-dir --break-system-packages poetry || \
    pip3 install --no-cache-dir poetry

# Install code formatting and testing tools
RUN pip3 install --no-cache-dir --break-system-packages \
    black \
    flake8 \
    pytest || \
    pip3 install --no-cache-dir \
    black \
    flake8 \
    pytest

# Install Jupyter and IPython separately due to their size
RUN pip3 install --no-cache-dir --break-system-packages \
    jupyter \
    ipython || \
    pip3 install --no-cache-dir \
    jupyter \
    ipython

# Install MCP and zen-mcp-server dependencies (separate to isolate potential issues)
RUN pip3 install --no-cache-dir --break-system-packages \
    pydantic \
    python-dotenv || \
    pip3 install --no-cache-dir \
    pydantic \
    python-dotenv

RUN pip3 install --no-cache-dir --break-system-packages \
    mcp \
    google-genai \
    openai || \
    pip3 install --no-cache-dir \
    mcp \
    google-genai \
    openai

# Install zen-mcp-server (main project from BeehiveInnovations)
RUN cd /opt && \
    git clone https://github.com/BeehiveInnovations/zen-mcp-server.git && \
    cd zen-mcp-server && \
    (pip3 install --no-cache-dir --break-system-packages -r requirements.txt || \
     pip3 install --no-cache-dir -r requirements.txt) && \
    # Make run scripts executable
    chmod +x run-server.sh || true && \
    # Set up basic configuration template  
    cp .env.example .env || true && \
    # Create convenient symlink
    ln -s /opt/zen-mcp-server /usr/local/share/zen-mcp-server

# Install GitHub MCP server (official GitHub implementation)
RUN cd /opt && \
    git clone https://github.com/github/github-mcp-server.git && \
    cd github-mcp-server && \
    # Build the Go binary for Linux (repo includes macOS binary by default)
    go build -o github-mcp-server-linux ./cmd/github-mcp-server && \
    # Install binary to system path
    mv github-mcp-server-linux /usr/local/bin/github-mcp-server && \
    chmod +x /usr/local/bin/github-mcp-server && \
    # Create convenient symlink to source
    ln -s /opt/github-mcp-server /usr/local/share/github-mcp-server

# Install Go tools
RUN go install golang.org/x/tools/gopls@latest && \
    go install github.com/air-verse/air@latest && \
    mv /root/go/bin/* /usr/local/bin/ || true

# Set up SSH
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# LinuxServer.io will create the abc user directories
# Set up Go environment
ENV GOPATH=/config/go
ENV PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

# Create development directories in /config (linuxserver.io pattern)
RUN mkdir -p /config/projects /config/workspace /config/go/bin /config/.ssh /config/.kube

# Expose SSH port
EXPOSE 22

# LinuxServer.io uses s6-overlay, so we'll add our services
# Copy service definitions for s6-overlay
COPY root/ /

# Remove startup.sh - we now use proper s6-overlay initialization
# The container will use s6-overlay's /init as ENTRYPOINT