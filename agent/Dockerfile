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
    && rm -rf /var/lib/apt/lists/*

# Install OpenCode globally
RUN npm install -g opencode-ai

# Create opencode user with sudo access
RUN useradd -m -s /bin/bash opencode \
    && echo "opencode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

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

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH and status server ports
EXPOSE 22 8080

# Set working directory
WORKDIR /workspace

# Run as root initially (entrypoint will setup SSH keys)
ENTRYPOINT ["/entrypoint.sh"]
