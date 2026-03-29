#!/bin/bash
# ─────────────────────────────────────────────────────────────
# OpenCode Agent Pool - One-Command Deploy
# ─────────────────────────────────────────────────────────────
# Does everything: installs CLI, generates keys, creates .env,
# validates config, creates Railway services + bucket, deploys.
#
# Usage: ./deploy.sh [num-agents]
#
# Options:
#   [num-agents]    Number of agent containers (default: 5)
#   --region <code> Bucket region: sjc, iad, ams, sin (default: ams)
#
# Prerequisites:
#   - .env file with RAILWAY_PROJECT_ID and AWS_BEARER_TOKEN_BEDROCK
#     (script will create .env from .env.example if missing and prompt you)
# ─────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/scripts" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY_DIR="$ROOT_DIR/keys"
KEY_PATH="$KEY_DIR/opencode-agent-pool"
ENV_FILE="$ROOT_DIR/.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"

# ── Parse Arguments ──────────────────────────────────────────
NUM_AGENTS=5
BUCKET_REGION_ARG="ams"

while [[ $# -gt 0 ]]; do
    case $1 in
        --region)
            BUCKET_REGION_ARG="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: ./deploy.sh [num-agents] [--region ams|sjc|iad|sin]"
            echo ""
            echo "  num-agents   Number of agent containers (default: 5)"
            echo "  --region     Bucket region (default: ams)"
            echo ""
            echo "Reads RAILWAY_PROJECT_ID and AWS_BEARER_TOKEN_BEDROCK from .env"
            exit 0
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                NUM_AGENTS="$1"
            else
                log_error "Unknown argument: $1"
                echo "Usage: ./deploy.sh [num-agents] [--region ams|sjc|iad|sin]"
                exit 1
            fi
            shift
            ;;
    esac
done

echo ""
echo -e "${BOLD}OpenCode Agent Pool - Deploy${RESET}"
echo "════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────
# PHASE 1: SETUP
# ─────────────────────────────────────────────────────────────

# ── Railway CLI ──────────────────────────────────────────────
log_step "1/10 Checking Railway CLI"
ensure_railway_v4

# ── Railway Auth ─────────────────────────────────────────────
log_step "2/10 Checking Railway authentication"
ensure_railway_auth

# ── SSH Keys ─────────────────────────────────────────────────
log_step "3/10 Checking SSH keys"

if [ -f "$KEY_PATH" ]; then
    log_success "SSH keys exist at $KEY_PATH"
else
    mkdir -p "$KEY_DIR"
    log_info "Generating SSH key pair..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "opencode-agent-pool" -N ""
    log_success "SSH keys generated"
fi

PUB_KEY=$(cat "$KEY_PATH.pub")

# ── Environment File ────────────────────────────────────────
log_step "4/10 Checking .env"

if [ -f "$ENV_FILE" ]; then
    log_info ".env exists"

    # Auto-fill SSH_AUTHORIZED_KEYS if empty or missing
    if grep -q "^SSH_AUTHORIZED_KEYS=$" "$ENV_FILE" 2>/dev/null; then
        log_info "Auto-filling SSH_AUTHORIZED_KEYS"
        awk -v key="$PUB_KEY" '{
            if ($0 ~ /^SSH_AUTHORIZED_KEYS=/) print "SSH_AUTHORIZED_KEYS=\"" key "\"";
            else print $0
        }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    elif ! grep -q "^SSH_AUTHORIZED_KEYS=" "$ENV_FILE" 2>/dev/null; then
        log_info "Adding SSH_AUTHORIZED_KEYS to .env"
        echo "SSH_AUTHORIZED_KEYS=\"$PUB_KEY\"" >> "$ENV_FILE"
    fi
else
    log_info "Creating .env from template..."
    cp "$ENV_EXAMPLE" "$ENV_FILE"

    # Auto-fill SSH_AUTHORIZED_KEYS
    awk -v key="$PUB_KEY" '{
        if ($0 ~ /^SSH_AUTHORIZED_KEYS=/) print "SSH_AUTHORIZED_KEYS=\"" key "\"";
        else print $0
    }' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"

    log_success ".env created with SSH key"
fi

# ── Validate Required Vars ──────────────────────────────────
source "$ENV_FILE"

ABORT=false

if [ -z "${RAILWAY_PROJECT_ID:-}" ]; then
    log_error "RAILWAY_PROJECT_ID is not set in .env"
    echo "  Add:  RAILWAY_PROJECT_ID=your-project-id"
    ABORT=true
fi

if [ -z "${AWS_BEARER_TOKEN_BEDROCK:-}" ]; then
    log_error "AWS_BEARER_TOKEN_BEDROCK is not set in .env"
    echo "  Add:  AWS_BEARER_TOKEN_BEDROCK=your-token"
    ABORT=true
fi

if [ -z "${SSH_AUTHORIZED_KEYS:-}" ]; then
    log_error "SSH_AUTHORIZED_KEYS is empty in .env"
    ABORT=true
fi

if [ "$ABORT" = true ]; then
    echo ""
    log_error "Fix the above issues in $ENV_FILE and re-run ./deploy.sh"
    exit 1
fi

PROJECT_ID="$RAILWAY_PROJECT_ID"

require_command "jq" "Install with: brew install jq (macOS) or apt install jq (Linux)"

log_success "Config validated"
echo "  Project:  $PROJECT_ID"
echo "  Agents:   $NUM_AGENTS"
echo "  Region:   $BUCKET_REGION_ARG"

# ─────────────────────────────────────────────────────────────
# PHASE 2: DEPLOY
# ─────────────────────────────────────────────────────────────

# ── Link to Project ──────────────────────────────────────────
log_step "5/10 Linking to Railway project"
railway link --project "$PROJECT_ID" 2>/dev/null || {
    log_error "Failed to link to project $PROJECT_ID"
    log_error "Make sure the project exists and you have access."
    exit 1
}
log_success "Linked to project"

# ── Create Bucket ────────────────────────────────────────────
log_step "6/10 Creating storage bucket"

if railway bucket list --json 2>/dev/null | jq -e '.[] | select(.name == "opencode-storage")' &>/dev/null; then
    log_info "Bucket 'opencode-storage' already exists"
else
    railway bucket create opencode-storage --region "$BUCKET_REGION_ARG" --json 2>/dev/null || {
        log_warn "Bucket creation returned an error (may already exist)"
    }
    log_success "Bucket created"
fi

log_info "Fetching bucket credentials..."
CREDS_JSON=$(railway bucket credentials --bucket opencode-storage --json 2>/dev/null) || {
    log_error "Failed to fetch bucket credentials"
    exit 1
}

B_ENDPOINT=$(echo "$CREDS_JSON" | jq -r '.endpoint // empty')
B_ACCESS_KEY=$(echo "$CREDS_JSON" | jq -r '.accessKeyId // empty')
B_SECRET_KEY=$(echo "$CREDS_JSON" | jq -r '.secretAccessKey // empty')
B_BUCKET_NAME=$(echo "$CREDS_JSON" | jq -r '.bucketName // empty')
B_REGION=$(echo "$CREDS_JSON" | jq -r '.region // empty')

if [ -z "$B_ENDPOINT" ] || [ -z "$B_ACCESS_KEY" ]; then
    log_error "Bucket credentials incomplete"
    echo "  Response: $CREDS_JSON"
    exit 1
fi

log_success "Bucket ready: $B_BUCKET_NAME ($B_REGION)"

# ── Create Services ──────────────────────────────────────────
log_step "7/10 Creating services"

create_service() {
    local name="$1"
    if railway service status --all --json 2>/dev/null | jq -e ".[] | select(.name == \"$name\")" &>/dev/null; then
        log_info "$name (exists)"
    else
        railway add --service "$name" 2>/dev/null || log_warn "$name may already exist"
        log_success "$name"
    fi
}

create_service "bastion"
create_service "dashboard"
for i in $(seq 1 "$NUM_AGENTS"); do
    create_service "agent-$i"
done

# ── Configure Builds ─────────────────────────────────────────
log_step "8/10 Configuring services"

log_info "Setting build config..."
railway environment edit --service-config bastion build.builder DOCKERFILE 2>/dev/null || true
railway environment edit --service-config bastion source.rootDirectory "/bastion" 2>/dev/null || true
railway environment edit --service-config dashboard build.builder DOCKERFILE 2>/dev/null || true
railway environment edit --service-config dashboard source.rootDirectory "/dashboard" 2>/dev/null || true

for i in $(seq 1 "$NUM_AGENTS"); do
    railway environment edit --service-config "agent-$i" build.builder DOCKERFILE 2>/dev/null || true
    railway environment edit --service-config "agent-$i" source.rootDirectory "/agent" 2>/dev/null || true
done

# Set shared environment variables (accessible by all services)
log_info "Setting shared variables..."

SHARED_JSON=$(cat <<ENDJSON
{
  "sharedVariables": {
    "SSH_AUTHORIZED_KEYS": {"value": "$SSH_AUTHORIZED_KEYS"},
    "AWS_BEARER_TOKEN_BEDROCK": {"value": "$AWS_BEARER_TOKEN_BEDROCK"},
    "AWS_REGION": {"value": "${AWS_REGION:-us-east-1}"},
    "BUCKET_ENDPOINT": {"value": "$B_ENDPOINT"},
    "BUCKET_ACCESS_KEY_ID": {"value": "$B_ACCESS_KEY"},
    "BUCKET_SECRET_ACCESS_KEY": {"value": "$B_SECRET_KEY"},
    "BUCKET_NAME": {"value": "$B_BUCKET_NAME"},
    "BUCKET_REGION": {"value": "$B_REGION"}
  }
}
ENDJSON
)
echo "$SHARED_JSON" | railway environment edit --json 2>/dev/null || log_warn "Shared variables may need manual setup"
log_success "Shared variables set"

# Set per-service variables (only service-specific values)
log_info "Setting per-service variables..."

AGENT_HOST_ARGS=()
for i in $(seq 1 "$NUM_AGENTS"); do
    AGENT_HOST_ARGS+=("AGENT_${i}_HOST=\${{agent-${i}.RAILWAY_PRIVATE_DOMAIN}}")
done

# Bastion: only needs agent host routing + shared var references
railway variable set \
    'SSH_AUTHORIZED_KEYS=${{shared.SSH_AUTHORIZED_KEYS}}' \
    "${AGENT_HOST_ARGS[@]}" \
    --service bastion --skip-deploys 2>/dev/null
log_success "Bastion configured"

# Dashboard: port, agent hosts, dashboard-specific settings + shared var references
railway variable set \
    "PORT=3000" \
    "AGENT_STATUS_PORT=8080" \
    "DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD:-}" \
    'BUCKET_ENDPOINT=${{shared.BUCKET_ENDPOINT}}' \
    'BUCKET_ACCESS_KEY_ID=${{shared.BUCKET_ACCESS_KEY_ID}}' \
    'BUCKET_SECRET_ACCESS_KEY=${{shared.BUCKET_SECRET_ACCESS_KEY}}' \
    'BUCKET_NAME=${{shared.BUCKET_NAME}}' \
    'BUCKET_REGION=${{shared.BUCKET_REGION}}' \
    "${AGENT_HOST_ARGS[@]}" \
    --service dashboard --skip-deploys 2>/dev/null
log_success "Dashboard configured"

# Agents: only AGENT_ID is unique, everything else references shared vars
for i in $(seq 1 "$NUM_AGENTS"); do
    railway variable set \
        "AGENT_ID=agent-$i" \
        'SSH_AUTHORIZED_KEYS=${{shared.SSH_AUTHORIZED_KEYS}}' \
        'AWS_BEARER_TOKEN_BEDROCK=${{shared.AWS_BEARER_TOKEN_BEDROCK}}' \
        'AWS_REGION=${{shared.AWS_REGION}}' \
        'BUCKET_ENDPOINT=${{shared.BUCKET_ENDPOINT}}' \
        'BUCKET_ACCESS_KEY_ID=${{shared.BUCKET_ACCESS_KEY_ID}}' \
        'BUCKET_SECRET_ACCESS_KEY=${{shared.BUCKET_SECRET_ACCESS_KEY}}' \
        'BUCKET_NAME=${{shared.BUCKET_NAME}}' \
        'BUCKET_REGION=${{shared.BUCKET_REGION}}' \
        --service "agent-$i" --skip-deploys 2>/dev/null
    log_success "Agent-$i configured"
done

# Volumes
log_info "Adding persistent volumes..."
for i in $(seq 1 "$NUM_AGENTS"); do
    railway service link "agent-$i" 2>/dev/null && \
    railway volume add --mount-path /workspace 2>/dev/null || true
done
log_success "Volumes attached"

# ── Generate Domain ──────────────────────────────────────────
log_step "9/10 Generating dashboard domain"

DASHBOARD_DOMAIN=$(railway domain --service dashboard --json 2>/dev/null | jq -r '.domain // .url // empty' 2>/dev/null) || true

if [ -n "$DASHBOARD_DOMAIN" ]; then
    log_success "https://$DASHBOARD_DOMAIN"
else
    log_warn "Run manually: railway domain --service dashboard"
fi

# ── Deploy ───────────────────────────────────────────────────
log_step "10/10 Deploying all services"

railway up --service bastion --detach 2>/dev/null || log_warn "Bastion may need manual deploy"
railway up --service dashboard --detach 2>/dev/null || log_warn "Dashboard may need manual deploy"
for i in $(seq 1 "$NUM_AGENTS"); do
    railway up --service "agent-$i" --detach 2>/dev/null || log_warn "Agent-$i may need manual deploy"
done

log_success "All deployments initiated"

# ─────────────────────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════"
log_success "Deployment complete!"
echo ""
echo -e "${BOLD}Services:${RESET}"
echo "  Dashboard:   ${DASHBOARD_DOMAIN:+https://$DASHBOARD_DOMAIN}"
echo "  Bastion:     bastion (needs TCP proxy)"
echo "  Agents:      agent-1 through agent-$NUM_AGENTS"
echo "  Bucket:      $B_BUCKET_NAME ($B_REGION)"
echo ""
echo -e "${BOLD}${YELLOW}ONE MANUAL STEP (one-time):${RESET}"
echo ""
echo "  1. Open: https://railway.com/project/$PROJECT_ID"
echo "  2. Click 'bastion' > Settings > Networking > TCP Proxy"
echo "  3. Enter port: 22"
echo "  4. Copy the hostname + port"
echo "  5. Run: ./scripts/ssh-setup.sh"
echo ""
