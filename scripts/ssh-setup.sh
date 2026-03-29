#!/bin/bash
# ─────────────────────────────────────────────────────────────
# OpenCode Agent Pool - Step 3 of 3: SSH Setup
# ─────────────────────────────────────────────────────────────
# Post-deploy: configures SSH for connecting to agents via
# the bastion jump host.
#
# Usage: ./scripts/ssh-setup.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

ROOT_DIR="$(project_root)"
KEY_PATH="$ROOT_DIR/keys/opencode-agent-pool"

echo ""
echo -e "${BOLD}OpenCode Agent Pool - SSH Setup${RESET}"
echo "════════════════════════════════════════"
echo ""

# ── Validate ─────────────────────────────────────────────────
if [ ! -f "$KEY_PATH" ]; then
    log_error "SSH private key not found at $KEY_PATH"
    log_error "Run ./scripts/setup.sh first."
    exit 1
fi

# Resolve the absolute path to the key
ABS_KEY_PATH=$(cd "$(dirname "$KEY_PATH")" && pwd)/$(basename "$KEY_PATH")

# ── Step 1: Get Bastion TCP Proxy Info ──────────────────────
log_step "Bastion TCP proxy configuration"
echo ""
echo "Enter the bastion TCP proxy hostname from Railway dashboard."
echo -e "${DIM}(e.g., shuttle.proxy.rlwy.net)${RESET}"
echo ""
read -rp "Hostname: " BASTION_HOST

echo ""
echo "Enter the bastion TCP proxy port."
echo -e "${DIM}(e.g., 15140)${RESET}"
echo ""
read -rp "Port: " BASTION_PORT

require_env "BASTION_HOST" "${BASTION_HOST:-}"
require_env "BASTION_PORT" "${BASTION_PORT:-}"

# ── Step 2: Update Dashboard ────────────────────────────────
log_step "Updating dashboard configuration"

if command -v railway &>/dev/null; then
    log_info "Setting VITE_BASTION_HOST on dashboard service..."
    railway variable set \
        "VITE_BASTION_HOST=${BASTION_HOST}:${BASTION_PORT}" \
        --service dashboard 2>/dev/null && \
        log_success "Dashboard updated (will redeploy automatically)" || \
        log_warn "Could not set VITE_BASTION_HOST. Set it manually in Railway dashboard."
else
    log_warn "Railway CLI not available. Set VITE_BASTION_HOST manually."
fi

# ── Step 3: SSH Config ──────────────────────────────────────
log_step "SSH configuration"

SSH_CONFIG="
# ── OpenCode Agent Pool ──────────────────────────────────
Host oc-bastion
    HostName $BASTION_HOST
    Port $BASTION_PORT
    User opencode
    IdentityFile $ABS_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR

Host agent-*
    ProxyJump oc-bastion
    User opencode
    IdentityFile $ABS_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
# ── End OpenCode Agent Pool ──────────────────────────────
"

echo ""
echo "The following will be added to your ~/.ssh/config:"
echo ""
echo -e "${DIM}────────────────────────────────────────${RESET}"
echo "$SSH_CONFIG"
echo -e "${DIM}────────────────────────────────────────${RESET}"
echo ""

read -rp "Add to ~/.ssh/config automatically? (y/n) " REPLY

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    mkdir -p ~/.ssh

    # Check if config already has our block
    if grep -q "# ── OpenCode Agent Pool" ~/.ssh/config 2>/dev/null; then
        # Remove old block and replace
        awk '
            /^# ── OpenCode Agent Pool/{skip=1; next}
            /^# ── End OpenCode Agent Pool/{skip=0; next}
            !skip{print}
        ' ~/.ssh/config > ~/.ssh/config.tmp
        mv ~/.ssh/config.tmp ~/.ssh/config
        log_info "Removed previous OpenCode Agent Pool config"
    fi

    echo "$SSH_CONFIG" >> ~/.ssh/config
    chmod 600 ~/.ssh/config
    log_success "SSH config written to ~/.ssh/config"
else
    echo ""
    log_info "Add the config above to ~/.ssh/config manually."
fi

# ── Step 4: SSH Agent ───────────────────────────────────────
log_step "Adding key to SSH agent"

if ssh-add "$ABS_KEY_PATH" 2>/dev/null; then
    log_success "Key added to SSH agent"
else
    log_warn "Could not add key to SSH agent"
    echo "  You may need to run: ssh-add $ABS_KEY_PATH"
fi

# ── Step 5: Test Connection ─────────────────────────────────
log_step "Testing SSH connection"

echo ""
log_info "Attempting to connect to agent-1..."
echo ""

if ssh -o ConnectTimeout=15 -o BatchMode=yes agent-1 echo "Connection successful" 2>/dev/null; then
    echo ""
    log_success "SSH connection to agent-1 is working!"
else
    echo ""
    log_warn "Connection test failed"
    echo ""
    echo "  This is normal if services are still deploying."
    echo "  Wait a few minutes and try: ssh agent-1"
fi

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
log_success "SSH setup complete!"
echo ""
echo -e "${BOLD}Usage:${RESET}"
echo ""
echo "  ssh agent-1              # Connect to agent 1"
echo "  ssh agent-2              # Connect to agent 2"
echo "  ssh agent-3              # Connect to agent 3"
echo ""
echo -e "${BOLD}Once connected:${RESET}"
echo ""
echo "  cd /workspace"
echo "  git clone git@github.com:your-org/your-repo.git"
echo "  cd your-repo"
echo "  opencode"
echo ""
