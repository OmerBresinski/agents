#!/bin/bash
# ─────────────────────────────────────────────────────────────
# OpenCode Agent Pool - Step 1 of 3: Setup
# ─────────────────────────────────────────────────────────────
# One-time setup: installs/upgrades Railway CLI, generates SSH
# keys, and creates .env file with auto-filled values.
#
# Usage: ./scripts/setup.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

ROOT_DIR="$(project_root)"
KEY_DIR="$ROOT_DIR/keys"
KEY_PATH="$KEY_DIR/opencode-agent-pool"
ENV_FILE="$ROOT_DIR/.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"

echo ""
echo -e "${BOLD}OpenCode Agent Pool - Setup${RESET}"
echo "════════════════════════════════════════"
echo ""

# ── Step 1: Railway CLI ─────────────────────────────────────
log_step "Checking Railway CLI"
ensure_railway_v4

# ── Step 2: Railway Authentication ──────────────────────────
log_step "Checking Railway authentication"
ensure_railway_auth

# ── Step 3: SSH Keys ────────────────────────────────────────
log_step "Checking SSH keys"

if [ -f "$KEY_PATH" ]; then
    log_success "SSH keys already exist at $KEY_PATH"
else
    mkdir -p "$KEY_DIR"
    log_info "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "opencode-agent-pool" -N ""
    log_success "SSH keys generated"
    echo "  Private key: $KEY_PATH"
    echo "  Public key:  $KEY_PATH.pub"
fi

PUB_KEY=$(cat "$KEY_PATH.pub")

# ── Step 4: Environment File ───────────────────────────────
log_step "Checking environment file"

if [ -f "$ENV_FILE" ]; then
    log_info ".env already exists at $ENV_FILE"

    # Check if SSH_AUTHORIZED_KEYS is set
    if grep -q "^SSH_AUTHORIZED_KEYS=$" "$ENV_FILE" 2>/dev/null; then
        log_info "Auto-filling SSH_AUTHORIZED_KEYS in existing .env"
        # Use a temp file approach for portability (works on both macOS and Linux)
        awk -v key="$PUB_KEY" '{
            if ($0 ~ /^SSH_AUTHORIZED_KEYS=/) print "SSH_AUTHORIZED_KEYS=" key;
            else print $0
        }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    fi
else
    log_info "Creating .env from .env.example..."
    cp "$ENV_EXAMPLE" "$ENV_FILE"

    # Auto-fill SSH_AUTHORIZED_KEYS
    awk -v key="$PUB_KEY" '{
        if ($0 ~ /^SSH_AUTHORIZED_KEYS=/) print "SSH_AUTHORIZED_KEYS=" key;
        else print $0
    }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"

    log_success ".env created with SSH key auto-filled"
fi

# ── Step 5: Validate ────────────────────────────────────────
log_step "Validating configuration"

source "$ENV_FILE"

if [ -n "${RAILWAY_PROJECT_ID:-}" ]; then
    log_success "RAILWAY_PROJECT_ID is set: $RAILWAY_PROJECT_ID"
else
    log_warn "RAILWAY_PROJECT_ID is not set"
    echo ""
    echo -e "  ${DIM}Edit $ENV_FILE and add your Railway project ID:${RESET}"
    echo -e "  ${DIM}  RAILWAY_PROJECT_ID=your-project-id-here${RESET}"
fi

if [ -n "${SSH_AUTHORIZED_KEYS:-}" ]; then
    log_success "SSH_AUTHORIZED_KEYS is set"
else
    log_warn "SSH_AUTHORIZED_KEYS is empty"
fi

if [ -n "${AWS_BEARER_TOKEN_BEDROCK:-}" ]; then
    log_success "AWS_BEARER_TOKEN_BEDROCK is set"
else
    log_warn "AWS_BEARER_TOKEN_BEDROCK is not set"
    echo ""
    echo -e "  ${DIM}Edit $ENV_FILE and add your AWS Bedrock bearer token:${RESET}"
    echo -e "  ${DIM}  AWS_BEARER_TOKEN_BEDROCK=your-token-here${RESET}"
fi

# ── Summary ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
log_success "Setup complete!"
echo ""
echo "Next steps:"
echo ""

MISSING=()
if [ -z "${RAILWAY_PROJECT_ID:-}" ]; then
    MISSING+=("RAILWAY_PROJECT_ID")
fi
if [ -z "${AWS_BEARER_TOKEN_BEDROCK:-}" ]; then
    MISSING+=("AWS_BEARER_TOKEN_BEDROCK")
fi

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "  1. Edit .env and set: ${MISSING[*]}"
    echo "  2. Run: ./scripts/deploy.sh [num-agents]"
else
    echo "  1. Run: ./scripts/deploy.sh [num-agents]"
fi

echo ""
