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
ssh-keygen -A

echo "Bastion host starting..."
echo "Configured agent hosts:"
echo "  - agent-1 -> ${AGENT_1_HOST:-agent-1}:22"
echo "  - agent-2 -> ${AGENT_2_HOST:-agent-2}:22"
echo "  - agent-3 -> ${AGENT_3_HOST:-agent-3}:22"
echo "  - agent-4 -> ${AGENT_4_HOST:-agent-4}:22"
echo "  - agent-5 -> ${AGENT_5_HOST:-agent-5}:22"

# Update SSH config with actual agent hostnames
cat > /home/opencode/.ssh/config << EOF
# Agent routing configuration
# Connect using: ssh -J bastion agent-1

Host agent-1
    HostName ${AGENT_1_HOST:-agent-1}
    User opencode
    Port 22
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host agent-2
    HostName ${AGENT_2_HOST:-agent-2}
    User opencode
    Port 22
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host agent-3
    HostName ${AGENT_3_HOST:-agent-3}
    User opencode
    Port 22
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host agent-4
    HostName ${AGENT_4_HOST:-agent-4}
    User opencode
    Port 22
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host agent-5
    HostName ${AGENT_5_HOST:-agent-5}
    User opencode
    Port 22
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chown opencode:opencode /home/opencode/.ssh/config
chmod 600 /home/opencode/.ssh/config

# Start SSH daemon in foreground
exec /usr/sbin/sshd -D -e
