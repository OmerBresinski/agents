# OpenCode Agent Container
# Base image with Node.js for OpenCode + SSH server + AWS Bedrock (bearer token)
FROM node:22-bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    git \
    curl \
    procps \
    jq \
    sudo \
    socat \
    findutils \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install OpenCode globally
RUN npm install -g opencode-ai

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /root/.bun/bin/bun /usr/local/bin/bun \
    && ln -s /root/.bun/bin/bunx /usr/local/bin/bunx

# Install s5cmd for S3-compatible workspace sync (Railway Bucket)
RUN curl -sSL -o /tmp/s5cmd.deb https://github.com/peak/s5cmd/releases/download/v2.3.0/s5cmd_2.3.0_linux_amd64.deb \
    && dpkg -i /tmp/s5cmd.deb \
    && rm /tmp/s5cmd.deb

# Create opencode user with sudo access (set dummy password to unlock for SSH)
RUN useradd -m -s /bin/bash opencode \
    && echo "opencode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && echo "opencode:*" | chpasswd -e \
    && mkdir -p /home/opencode/.bun/bin \
    && cp /root/.bun/bin/bun /home/opencode/.bun/bin/bun \
    && ln -s /home/opencode/.bun/bin/bun /home/opencode/.bun/bin/bunx \
    && chown -R opencode:opencode /home/opencode/.bun

# Setup SSH
RUN mkdir /var/run/sshd \
    && mkdir -p /home/opencode/.ssh \
    && chmod 700 /home/opencode/.ssh \
    && chown -R opencode:opencode /home/opencode/.ssh

# Copy SSH config
COPY sshd_config /etc/ssh/sshd_config

# Create workspace and opencode directories with proper permissions
RUN mkdir -p /workspace /home/opencode/.opencode \
    && chown -R opencode:opencode /workspace /home/opencode/.opencode

# Copy OpenCode configuration for AWS Bedrock
COPY opencode.json /home/opencode/.opencode/config.json
RUN chown opencode:opencode /home/opencode/.opencode/config.json

# Copy status server script
COPY status-server.sh /usr/local/bin/status-server
RUN chmod +x /usr/local/bin/status-server

# Copy workspace sync script
COPY workspace-sync.sh /usr/local/bin/workspace-sync
RUN chmod +x /usr/local/bin/workspace-sync

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH and status server ports
EXPOSE 22 9090

# Set working directory
WORKDIR /workspace

# Run as root initially (entrypoint will setup SSH keys)
ENTRYPOINT ["/entrypoint.sh"]
