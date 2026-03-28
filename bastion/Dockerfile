# Bastion/Jump Host Container
# Lightweight SSH server that routes connections to agent containers
FROM alpine:3.19

# Install OpenSSH
RUN apk add --no-cache openssh bash curl

# Create opencode user
RUN adduser -D -s /bin/bash opencode

# Setup SSH directories
RUN mkdir -p /home/opencode/.ssh \
    && chmod 700 /home/opencode/.ssh \
    && chown -R opencode:opencode /home/opencode/.ssh

# Copy SSH config
COPY sshd_config /etc/ssh/sshd_config

# Copy SSH client config for agent routing
COPY ssh_config /home/opencode/.ssh/config
RUN chmod 600 /home/opencode/.ssh/config \
    && chown opencode:opencode /home/opencode/.ssh/config

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose SSH port
EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
