#!/bin/bash
set -e

# Setup SSH authorized keys from environment variable
if [ -n "$SSH_AUTHORIZED_KEYS" ]; then
    echo "$SSH_AUTHORIZED_KEYS" > /home/opencode/.ssh/authorized_keys
    chmod 600 /home/opencode/.ssh/authorized_keys
    chown opencode:opencode /home/opencode/.ssh/authorized_keys
    echo "SSH authorized keys configured"
else
    echo "Warning: SSH_AUTHORIZED_KEYS not set. SSH access will not work."
fi

# Generate SSH host keys if they don't exist
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
    echo "SSH host keys generated"
fi

# Set agent ID from environment or default
AGENT_ID=${AGENT_ID:-"agent-unknown"}
echo "Starting agent: $AGENT_ID"

# Export agent ID for status server
export AGENT_ID

# Start the status server in the background
echo "Starting status server on port 8080..."
/usr/local/bin/status-server &

# Start SSH daemon in foreground
echo "Starting SSH daemon..."
exec /usr/sbin/sshd -D -e
