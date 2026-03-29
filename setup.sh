#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Simple Cloud Agents - One-Click Setup
# ─────────────────────────────────────────────────────────────
# Deploys a pool of AI coding agents to Railway.
# Run this once. Everything is handled for you.
#
# Usage: ./setup.sh
# ─────────────────────────────────────────────────────────────

set -euo pipefail

# ── Colors & Formatting ──────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; }
success() { echo -e "${GREEN}  ✓${RESET} $1"; }
step()    { echo -e "\n${BOLD}${CYAN}  [$1]${RESET} $2"; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY_DIR="$ROOT_DIR/keys"
KEY_PATH="$KEY_DIR/simple-cloud-agents"

RAILWAY_API="https://backboard.railway.com/graphql/v2"

# ── Helper: GraphQL query ────────────────────────────────────
gql() {
    local token="$1"
    local query="$2"
    local vars="${3:-{}}"
    curl -s --request POST \
        --url "$RAILWAY_API" \
        --header "Authorization: Bearer $token" \
        --header "Content-Type: application/json" \
        --data "{\"query\":$(echo "$query" | jq -Rs .),\"variables\":$vars}"
}

# ─────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}  Simple Cloud Agents${RESET}"
echo -e "  ${DIM}Deploy AI coding agents to Railway${RESET}"
echo "  ═══════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────
# [1/8] Prerequisites
# ─────────────────────────────────────────────────────────────
step "1/8" "Checking prerequisites"

# Node.js
if ! command -v node &>/dev/null; then
    error "Node.js is required but not installed."
    echo "  Install it from: https://nodejs.org"
    exit 1
fi
success "Node.js $(node --version)"

# jq
if ! command -v jq &>/dev/null; then
    info "Installing jq..."
    if command -v brew &>/dev/null; then
        brew install jq 2>/dev/null
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y -qq jq 2>/dev/null
    else
        error "Cannot auto-install jq. Install manually: https://jqlang.github.io/jq/download/"
        exit 1
    fi
fi
success "jq $(jq --version 2>/dev/null)"

# Railway CLI
if ! command -v railway &>/dev/null; then
    info "Installing Railway CLI..."
    npm install -g @railway/cli 2>/dev/null
elif [ "$(railway --version 2>/dev/null | grep -oE '[0-9]+' | head -1)" -lt 4 ] 2>/dev/null; then
    info "Upgrading Railway CLI to v4..."
    npm install -g @railway/cli 2>/dev/null
fi
success "Railway CLI v$(railway --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"

# ─────────────────────────────────────────────────────────────
# [2/8] Railway Login
# ─────────────────────────────────────────────────────────────
step "2/8" "Railway authentication"

if ! railway whoami &>/dev/null; then
    info "Opening Railway login in your browser..."
    railway login || { error "Login failed."; exit 1; }
fi
success "Logged in as $(railway whoami 2>/dev/null | head -1)"

# ─────────────────────────────────────────────────────────────
# [3/8] Configuration
# ─────────────────────────────────────────────────────────────
step "3/8" "Configuration"

echo ""
echo -e "  ${DIM}AWS Bedrock lets your agents use Claude AI.${RESET}"
echo -e "  ${DIM}If you don't have a token, press Enter to skip.${RESET}"
echo -e "  ${DIM}You can configure your AI provider later inside OpenCode.${RESET}"
echo ""
read -rp "  AWS Bedrock bearer token (optional): " AWS_TOKEN
echo ""

# Number of agents
while true; do
    read -rp "  Number of agents (1-5) [3]: " NUM_AGENTS
    NUM_AGENTS="${NUM_AGENTS:-3}"
    if [[ "$NUM_AGENTS" =~ ^[1-5]$ ]]; then
        break
    fi
    warn "Please enter a number between 1 and 5"
done

# SSH password
echo ""
echo -e "  ${DIM}Set a password for SSH access from any device.${RESET}"
while true; do
    read -rsp "  SSH password: " SSH_PASS
    echo ""
    if [ -n "$SSH_PASS" ]; then
        read -rsp "  Confirm password: " SSH_PASS_CONFIRM
        echo ""
        if [ "$SSH_PASS" = "$SSH_PASS_CONFIRM" ]; then
            break
        fi
        warn "Passwords don't match. Try again."
    else
        warn "Password is required for multi-device access."
    fi
done

# Dashboard password
echo ""
read -rsp "  Dashboard password (optional): " DASH_PASS
echo ""

# Bucket region
echo ""
read -rp "  Bucket region [ams/sjc/iad] (default: ams): " BUCKET_REGION
BUCKET_REGION="${BUCKET_REGION:-ams}"

echo ""
success "Configuration:"
echo "    Agents: $NUM_AGENTS"
echo "    Bedrock: $([ -n "$AWS_TOKEN" ] && echo "configured" || echo "skipped")"
echo "    Bucket region: $BUCKET_REGION"

# ─────────────────────────────────────────────────────────────
# [4/8] Generate SSH Keys
# ─────────────────────────────────────────────────────────────
step "4/8" "Generating SSH keys"

mkdir -p "$KEY_DIR"
if [ -f "$KEY_PATH" ]; then
    success "SSH keys already exist"
else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "simple-cloud-agents" -N "" -q
    success "SSH key pair generated"
fi
PUB_KEY=$(cat "$KEY_PATH.pub")

# ─────────────────────────────────────────────────────────────
# [5/8] Create Railway Project
# ─────────────────────────────────────────────────────────────
step "5/8" "Creating Railway project"

railway init --name simple-cloud-agents 2>/dev/null || true

# Get project and environment IDs
PROJECT_ID=$(railway environment config --json 2>/dev/null | jq -r '.project // empty')
ENV_ID=$(railway environment config --json 2>/dev/null | jq -r '.environment // empty')

if [ -z "$PROJECT_ID" ] || [ -z "$ENV_ID" ]; then
    # Try alternate method
    PROJECT_ID=$(cat "$ROOT_DIR/.railway/config.json" 2>/dev/null | jq -r '.project // empty')
    ENV_ID=$(cat "$ROOT_DIR/.railway/config.json" 2>/dev/null | jq -r '.environment // empty')
fi

if [ -z "$PROJECT_ID" ]; then
    error "Could not get project ID. Make sure 'railway init' completed."
    exit 1
fi

success "Project: $PROJECT_ID"

# ─────────────────────────────────────────────────────────────
# [6/8] Create Infrastructure
# ─────────────────────────────────────────────────────────────
step "6/8" "Creating infrastructure (this takes a minute)"

# ── Bucket ───────────────────────────────────────────────────
info "Creating storage bucket..."
railway bucket create simple-cloud-storage --region "$BUCKET_REGION" --json 2>/dev/null || true

CREDS_JSON=$(railway bucket credentials --bucket simple-cloud-storage --json 2>/dev/null) || {
    error "Failed to get bucket credentials"
    exit 1
}
B_ENDPOINT=$(echo "$CREDS_JSON" | jq -r '.endpoint // empty')
B_ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r '.accessKeyId // empty')
B_SECRET_KEY=$(echo "$CREDS_JSON" | jq -r '.secretAccessKey // empty')
B_BUCKET_NAME=$(echo "$CREDS_JSON" | jq -r '.bucketName // empty')
B_REGION=$(echo "$CREDS_JSON" | jq -r '.region // empty')
success "Bucket: $B_BUCKET_NAME"

# ── Services ─────────────────────────────────────────────────
info "Creating services..."
railway add --service bastion 2>/dev/null || true
success "bastion"

railway add --service dashboard 2>/dev/null || true
success "dashboard"

for i in $(seq 1 "$NUM_AGENTS"); do
    railway add --service "agent-$i" 2>/dev/null || true
    success "agent-$i"
done

# ── Build Config ─────────────────────────────────────────────
info "Configuring builds..."

# Get service IDs for GraphQL operations later
SERVICES_JSON=$(railway environment config --json 2>/dev/null)

railway environment edit --service-config bastion build.builder DOCKERFILE 2>/dev/null || true
railway environment edit --service-config bastion source.rootDirectory "/bastion" 2>/dev/null || true
railway environment edit --service-config dashboard build.builder DOCKERFILE 2>/dev/null || true
railway environment edit --service-config dashboard source.rootDirectory "/dashboard" 2>/dev/null || true

for i in $(seq 1 "$NUM_AGENTS"); do
    railway environment edit --service-config "agent-$i" build.builder DOCKERFILE 2>/dev/null || true
    railway environment edit --service-config "agent-$i" source.rootDirectory "/agent" 2>/dev/null || true
done
success "Build configs set"

# ── Shared Variables ─────────────────────────────────────────
info "Setting shared variables..."

# Build shared vars JSON
SHARED_VARS="{\"sharedVariables\":{"
SHARED_VARS+="\"SSH_AUTHORIZED_KEYS\":{\"value\":\"$PUB_KEY\"},"
SHARED_VARS+="\"SSH_PASSWORD\":{\"value\":\"$SSH_PASS\"},"
SHARED_VARS+="\"BUCKET_ENDPOINT\":{\"value\":\"$B_ENDPOINT\"},"
SHARED_VARS+="\"BUCKET_ACCESS_KEY_ID\":{\"value\":\"$B_ACCESS_KEY\"},"
SHARED_VARS+="\"BUCKET_SECRET_ACCESS_KEY\":{\"value\":\"$B_SECRET_KEY\"},"
SHARED_VARS+="\"BUCKET_NAME\":{\"value\":\"$B_BUCKET_NAME\"},"
SHARED_VARS+="\"BUCKET_REGION\":{\"value\":\"$B_REGION\"}"

if [ -n "$AWS_TOKEN" ]; then
    SHARED_VARS+=",\"AWS_BEARER_TOKEN_BEDROCK\":{\"value\":\"$AWS_TOKEN\"}"
    SHARED_VARS+=",\"AWS_REGION\":{\"value\":\"us-east-1\"}"
fi

SHARED_VARS+="}}"
echo "$SHARED_VARS" | railway environment edit --json 2>/dev/null || true
success "Shared variables"

# ── Per-Service Variables ────────────────────────────────────
info "Setting service variables..."

# Bastion
BASTION_VARS=(
    'SSH_AUTHORIZED_KEYS=${{shared.SSH_AUTHORIZED_KEYS}}'
    'SSH_PASSWORD=${{shared.SSH_PASSWORD}}'
)
for i in $(seq 1 "$NUM_AGENTS"); do
    BASTION_VARS+=("AGENT_${i}_HOST=\${{agent-${i}.RAILWAY_PRIVATE_DOMAIN}}")
done
railway variable set "${BASTION_VARS[@]}" --service bastion --skip-deploys 2>/dev/null
success "Bastion variables"

# Dashboard
DASH_VARS=(
    "PORT=3000"
    "AGENT_STATUS_PORT=9090"
    "DASHBOARD_PASSWORD=${DASH_PASS:-}"
    'BUCKET_ENDPOINT=${{shared.BUCKET_ENDPOINT}}'
    'BUCKET_ACCESS_KEY_ID=${{shared.BUCKET_ACCESS_KEY_ID}}'
    'BUCKET_SECRET_ACCESS_KEY=${{shared.BUCKET_SECRET_ACCESS_KEY}}'
    'BUCKET_NAME=${{shared.BUCKET_NAME}}'
    'BUCKET_REGION=${{shared.BUCKET_REGION}}'
)
for i in $(seq 1 "$NUM_AGENTS"); do
    DASH_VARS+=("AGENT_${i}_HOST=\${{agent-${i}.RAILWAY_PRIVATE_DOMAIN}}")
done
railway variable set "${DASH_VARS[@]}" --service dashboard --skip-deploys 2>/dev/null
success "Dashboard variables"

# Agents
for i in $(seq 1 "$NUM_AGENTS"); do
    AGENT_VARS=(
        "AGENT_ID=agent-$i"
        'SSH_AUTHORIZED_KEYS=${{shared.SSH_AUTHORIZED_KEYS}}'
        'SSH_PASSWORD=${{shared.SSH_PASSWORD}}'
        'BUCKET_ENDPOINT=${{shared.BUCKET_ENDPOINT}}'
        'BUCKET_ACCESS_KEY_ID=${{shared.BUCKET_ACCESS_KEY_ID}}'
        'BUCKET_SECRET_ACCESS_KEY=${{shared.BUCKET_SECRET_ACCESS_KEY}}'
        'BUCKET_NAME=${{shared.BUCKET_NAME}}'
        'BUCKET_REGION=${{shared.BUCKET_REGION}}'
    )
    if [ -n "$AWS_TOKEN" ]; then
        AGENT_VARS+=(
            'AWS_BEARER_TOKEN_BEDROCK=${{shared.AWS_BEARER_TOKEN_BEDROCK}}'
            'AWS_REGION=${{shared.AWS_REGION}}'
        )
    fi
    railway variable set "${AGENT_VARS[@]}" --service "agent-$i" --skip-deploys 2>/dev/null
    success "Agent-$i variables"
done

# ── Volumes ──────────────────────────────────────────────────
info "Adding volumes..."
for i in $(seq 1 "$NUM_AGENTS"); do
    railway service link "agent-$i" 2>/dev/null && \
    railway volume add --mount-path /workspace 2>/dev/null || true
done
success "Volumes attached"

# ── Dashboard Domain ─────────────────────────────────────────
info "Generating dashboard URL..."
railway service link dashboard 2>/dev/null
DASHBOARD_DOMAIN=$(railway domain --json 2>/dev/null | jq -r '.domain // .url // empty' 2>/dev/null) || true
success "Dashboard: https://${DASHBOARD_DOMAIN:-pending}"

# ─────────────────────────────────────────────────────────────
# [7/8] Deploy & TCP Proxy
# ─────────────────────────────────────────────────────────────
step "7/8" "Deploying (this takes ~3 minutes)"

# Deploy all services
for svc in bastion dashboard $(seq -f "agent-%.0f" 1 "$NUM_AGENTS"); do
    railway service link "$svc" 2>/dev/null && railway up --detach 2>/dev/null || true
    success "$svc queued"
done

# Wait for bastion to come online
info "Waiting for bastion to deploy..."
for attempt in $(seq 1 30); do
    sleep 10
    BASTION_STATUS=$(railway service status --all --json 2>/dev/null | jq -r '.[] | select(.name == "bastion") | .status' 2>/dev/null)
    if [ "$BASTION_STATUS" = "SUCCESS" ]; then
        success "Bastion is online"
        break
    fi
    if [ "$attempt" -eq 30 ]; then
        warn "Bastion is still deploying. Continuing anyway..."
    fi
done

# TCP Proxy - manual step (not available in public API)
echo ""
echo -e "  ${BOLD}${YELLOW}Almost there! One manual step needed:${RESET}"
echo ""
echo -e "    1. Open: ${CYAN}https://railway.com/project/$PROJECT_ID${RESET}"
echo "    2. Click the 'bastion' service"
echo "    3. Go to Settings → Networking"
echo "    4. Under 'Public Networking', click TCP Proxy"
echo "    5. Enter port: 22"
echo ""
read -rp "  Press Enter when done... "

# Fetch TCP proxy info
info "Detecting TCP proxy..."

# Get bastion service ID from the project services
BASTION_SERVICE_ID=""
ALL_SERVICES=$(railway service status --all --json 2>/dev/null)
if [ -n "$ALL_SERVICES" ]; then
    BASTION_SERVICE_ID=$(echo "$ALL_SERVICES" | jq -r '.[] | select(.name == "bastion") | .id // empty' 2>/dev/null)
fi

# Try via the Railway CLI
railway service link bastion 2>/dev/null
TCP_INFO=""

# Poll for TCP proxy to appear
for attempt in $(seq 1 6); do
    # Try to get it from the Railway API
    if [ -n "$BASTION_SERVICE_ID" ] && [ -n "$ENV_ID" ]; then
        RAILWAY_TOKEN=$(cat ~/.railway/config.json 2>/dev/null | jq -r '.user.token // .token // empty' || echo "")
        if [ -n "$RAILWAY_TOKEN" ]; then
            TCP_RESULT=$(gql "$RAILWAY_TOKEN" 'query($sid: String!, $eid: String!) { tcpProxies(serviceId: $sid, environmentId: $eid) { domain proxyPort } }' "{\"sid\":\"$BASTION_SERVICE_ID\",\"eid\":\"$ENV_ID\"}" 2>/dev/null)
            TCP_DOMAIN=$(echo "$TCP_RESULT" | jq -r '.data.tcpProxies[0].domain // empty' 2>/dev/null)
            TCP_PORT=$(echo "$TCP_RESULT" | jq -r '.data.tcpProxies[0].proxyPort // empty' 2>/dev/null)
            if [ -n "$TCP_DOMAIN" ] && [ -n "$TCP_PORT" ]; then
                TCP_INFO="$TCP_DOMAIN:$TCP_PORT"
                break
            fi
        fi
    fi
    sleep 5
done

if [ -z "$TCP_INFO" ]; then
    echo ""
    read -rp "  Enter the TCP proxy hostname (e.g., shuttle.proxy.rlwy.net): " TCP_DOMAIN
    read -rp "  Enter the TCP proxy port (e.g., 15140): " TCP_PORT
    TCP_INFO="$TCP_DOMAIN:$TCP_PORT"
fi

TCP_HOST=$(echo "$TCP_INFO" | cut -d: -f1)
TCP_PORT=$(echo "$TCP_INFO" | cut -d: -f2)
success "TCP proxy: $TCP_HOST:$TCP_PORT"

# Set VITE_BASTION_HOST on dashboard
railway variable set "VITE_BASTION_HOST=$TCP_HOST:$TCP_PORT" --service dashboard 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
# [8/8] Configure SSH
# ─────────────────────────────────────────────────────────────
step "8/8" "Configuring SSH"

ABS_KEY_PATH=$(cd "$(dirname "$KEY_PATH")" && pwd)/$(basename "$KEY_PATH")

# Build SSH config
SSH_CONFIG="
# ── Simple Cloud Agents ──────────────────────────────────
Host sca-bastion
    HostName $TCP_HOST
    Port $TCP_PORT
    User opencode
    IdentityFile $ABS_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
"

for i in $(seq 1 "$NUM_AGENTS"); do
    # Port forwarding: agent N gets ports N{3000}, N{4000}, N{5173}, N{8080}
    SSH_CONFIG+="
Host agent-$i
    ProxyJump sca-bastion
    User opencode
    IdentityFile $ABS_KEY_PATH
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    LocalForward ${i}3000 localhost:3000
    LocalForward ${i}4000 localhost:4000
    LocalForward ${i}5173 localhost:5173
    LocalForward ${i}8080 localhost:8080
"
done

SSH_CONFIG+="# ── End Simple Cloud Agents ──────────────────────────────
"

# Write SSH config
mkdir -p ~/.ssh

# Remove old config block if it exists
if grep -q "# ── Simple Cloud Agents" ~/.ssh/config 2>/dev/null; then
    awk '
        /^# ── Simple Cloud Agents/{skip=1; next}
        /^# ── End Simple Cloud Agents/{skip=0; next}
        !skip{print}
    ' ~/.ssh/config > ~/.ssh/config.tmp
    mv ~/.ssh/config.tmp ~/.ssh/config
fi

echo "$SSH_CONFIG" >> ~/.ssh/config
chmod 600 ~/.ssh/config
success "SSH config written to ~/.ssh/config"

# Add key to SSH agent
ssh-add "$ABS_KEY_PATH" 2>/dev/null || true
success "Key added to SSH agent"

# ─────────────────────────────────────────────────────────────
# Done!
# ─────────────────────────────────────────────────────────────
echo ""
echo "  ═══════════════════════════════════════"
echo -e "  ${GREEN}${BOLD}Setup complete!${RESET}"
echo ""

if [ -n "$DASHBOARD_DOMAIN" ]; then
    echo -e "  ${BOLD}Dashboard:${RESET}  https://$DASHBOARD_DOMAIN"
    if [ -n "$DASH_PASS" ]; then
        echo -e "  ${BOLD}Password:${RESET}   $DASH_PASS"
    fi
    echo ""
fi

echo -e "  ${BOLD}Connect from this device (SSH key):${RESET}"
for i in $(seq 1 "$NUM_AGENTS"); do
    echo "    ssh agent-$i"
done

echo ""
echo -e "  ${BOLD}Connect from any device (password):${RESET}"
echo "    ssh -o ProxyCommand=\"ssh -W %h:%p -p $TCP_PORT opencode@$TCP_HOST\" opencode@agent-1"
echo ""

echo -e "  ${BOLD}Port forwarding (automatic):${RESET}"
for i in $(seq 1 "$NUM_AGENTS"); do
    echo "    Agent $i: localhost:${i}5173 (Vite), localhost:${i}3000 (React)"
done

echo ""
echo -e "  ${BOLD}Once connected:${RESET}"
echo "    cd /workspace"
echo "    opencode"
echo ""
echo "  ═══════════════════════════════════════"
echo ""
