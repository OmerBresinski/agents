#!/bin/bash
# ─────────────────────────────────────────────────────────────
# OpenCode Agent Pool - Step 2 of 3: Deploy
# ─────────────────────────────────────────────────────────────
# Creates all Railway services, bucket, sets env vars, and
# deploys everything.
#
# Usage: ./scripts/deploy.sh --project <project-id> [num-agents]
#
# Options:
#   --project <id>  Railway project ID (required)
#   [num-agents]    Number of agent containers (default: 5)
#   --region <code> Bucket region: sjc, iad, ams, sin (default: ams)
# ─────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/helpers.sh"

ROOT_DIR="$(project_root)"
ENV_FILE="$ROOT_DIR/.env"

# ── Parse Arguments ──────────────────────────────────────────
PROJECT_ID=""
NUM_AGENTS=5
BUCKET_REGION_ARG="ams"

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_ID="$2"
            shift 2
            ;;
        --region)
            BUCKET_REGION_ARG="$2"
            shift 2
            ;;
        *)
            if [[ "$1" =~ ^[0-9]+$ ]]; then
                NUM_AGENTS="$1"
            else
                log_error "Unknown argument: $1"
                echo "Usage: ./scripts/deploy.sh --project <project-id> [num-agents]"
                exit 1
            fi
            shift
            ;;
    esac
done

echo ""
echo -e "${BOLD}OpenCode Agent Pool - Deploy${RESET}"
echo "════════════════════════════════════════"
echo ""

# ── Validate ─────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
    log_error ".env file not found. Run ./scripts/setup.sh first."
    exit 1
fi

source "$ENV_FILE"

# Fall back to RAILWAY_PROJECT_ID from .env if --project not passed
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="${RAILWAY_PROJECT_ID:-}"
fi

require_env "PROJECT_ID (use --project <id> or set RAILWAY_PROJECT_ID in .env)" "$PROJECT_ID"
require_env "SSH_AUTHORIZED_KEYS" "${SSH_AUTHORIZED_KEYS:-}"
require_env "AWS_BEARER_TOKEN_BEDROCK" "${AWS_BEARER_TOKEN_BEDROCK:-}"

require_command "railway" "Run ./scripts/setup.sh to install it"
require_command "jq" "Install with: brew install jq (macOS) or apt install jq (Linux)"

log_info "Project ID: $PROJECT_ID"
log_info "Agents: $NUM_AGENTS"
log_info "Bucket region: $BUCKET_REGION_ARG"
echo ""

# ── Step 1: Link to Railway Project ─────────────────────────
log_step "Linking to Railway project"
railway link --project "$PROJECT_ID" 2>/dev/null || {
    log_error "Failed to link to project $PROJECT_ID"
    log_error "Make sure the project exists and you have access to it."
    exit 1
}
log_success "Linked to project"

# ── Step 2: Create Bucket ───────────────────────────────────
log_step "Creating storage bucket"

# Check if bucket already exists
if railway bucket list --json 2>/dev/null | jq -e '.[] | select(.name == "opencode-storage")' &>/dev/null; then
    log_info "Bucket 'opencode-storage' already exists, skipping creation"
else
    railway bucket create opencode-storage --region "$BUCKET_REGION_ARG" --json 2>/dev/null || {
        log_warn "Bucket creation returned an error (may already exist)"
    }
    log_success "Bucket created"
fi

# Fetch bucket credentials
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
    log_error "Bucket credentials are incomplete"
    echo "  Raw response: $CREDS_JSON"
    exit 1
fi

log_success "Bucket credentials retrieved"
echo "  Endpoint: $B_ENDPOINT"
echo "  Bucket:   $B_BUCKET_NAME"
echo "  Region:   $B_REGION"

# ── Step 3: Create Services ─────────────────────────────────
log_step "Creating services"

create_service() {
    local name="$1"
    if railway service status --all --json 2>/dev/null | jq -e ".[] | select(.name == \"$name\")" &>/dev/null; then
        log_info "Service '$name' already exists, skipping"
    else
        railway add --service "$name" 2>/dev/null || {
            log_warn "Service '$name' may already exist"
        }
        log_success "Created service: $name"
    fi
}

create_service "bastion"
create_service "dashboard"

for i in $(seq 1 "$NUM_AGENTS"); do
    create_service "agent-$i"
done

# ── Step 4: Configure Build Settings ────────────────────────
log_step "Configuring build settings"

log_info "Configuring bastion..."
railway environment edit --service-config bastion build.builder DOCKERFILE 2>/dev/null || true
railway environment edit --service-config bastion source.rootDirectory "/bastion" 2>/dev/null || true

log_info "Configuring dashboard..."
railway environment edit --service-config dashboard build.builder DOCKERFILE 2>/dev/null || true
railway environment edit --service-config dashboard source.rootDirectory "/dashboard" 2>/dev/null || true

for i in $(seq 1 "$NUM_AGENTS"); do
    log_info "Configuring agent-$i..."
    railway environment edit --service-config "agent-$i" build.builder DOCKERFILE 2>/dev/null || true
    railway environment edit --service-config "agent-$i" source.rootDirectory "/agent" 2>/dev/null || true
done

log_success "Build settings configured"

# ── Step 5: Set Environment Variables ────────────────────────
log_step "Setting environment variables"

# Build AGENT_N_HOST variable arguments
AGENT_HOST_ARGS=()
for i in $(seq 1 "$NUM_AGENTS"); do
    AGENT_HOST_ARGS+=("AGENT_${i}_HOST=agent-${i}.railway.internal")
done

# Bastion
log_info "Setting bastion variables..."
railway variable set \
    "SSH_AUTHORIZED_KEYS=$SSH_AUTHORIZED_KEYS" \
    "${AGENT_HOST_ARGS[@]}" \
    --service bastion --skip-deploys 2>/dev/null
log_success "Bastion variables set"

# Dashboard
log_info "Setting dashboard variables..."
railway variable set \
    "PORT=3000" \
    "AGENT_STATUS_PORT=8080" \
    "DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD:-}" \
    "BUCKET_ENDPOINT=$B_ENDPOINT" \
    "BUCKET_ACCESS_KEY_ID=$B_ACCESS_KEY" \
    "BUCKET_SECRET_ACCESS_KEY=$B_SECRET_KEY" \
    "BUCKET_NAME=$B_BUCKET_NAME" \
    "BUCKET_REGION=$B_REGION" \
    "${AGENT_HOST_ARGS[@]}" \
    --service dashboard --skip-deploys 2>/dev/null
log_success "Dashboard variables set"

# Agents
for i in $(seq 1 "$NUM_AGENTS"); do
    log_info "Setting agent-$i variables..."
    railway variable set \
        "AGENT_ID=agent-$i" \
        "SSH_AUTHORIZED_KEYS=$SSH_AUTHORIZED_KEYS" \
        "AWS_BEARER_TOKEN_BEDROCK=$AWS_BEARER_TOKEN_BEDROCK" \
        "AWS_REGION=${AWS_REGION:-us-east-1}" \
        "BUCKET_ENDPOINT=$B_ENDPOINT" \
        "BUCKET_ACCESS_KEY_ID=$B_ACCESS_KEY" \
        "BUCKET_SECRET_ACCESS_KEY=$B_SECRET_KEY" \
        "BUCKET_NAME=$B_BUCKET_NAME" \
        "BUCKET_REGION=$B_REGION" \
        --service "agent-$i" --skip-deploys 2>/dev/null
    log_success "Agent-$i variables set"
done

# ── Step 6: Add Volumes ─────────────────────────────────────
log_step "Adding persistent volumes to agents"

for i in $(seq 1 "$NUM_AGENTS"); do
    log_info "Adding volume to agent-$i..."
    railway volume add --mount-path /workspace --service "agent-$i" 2>/dev/null || {
        log_info "Volume for agent-$i may already exist"
    }
done

log_success "Volumes configured"

# ── Step 7: Generate Dashboard Domain ────────────────────────
log_step "Generating dashboard domain"

DASHBOARD_DOMAIN=$(railway domain --service dashboard --json 2>/dev/null | jq -r '.domain // .url // empty' 2>/dev/null) || true

if [ -n "$DASHBOARD_DOMAIN" ]; then
    log_success "Dashboard domain: https://$DASHBOARD_DOMAIN"
else
    log_warn "Could not generate dashboard domain automatically"
    echo "  You can generate one manually: railway domain --service dashboard"
fi

# ── Step 8: Deploy All Services ──────────────────────────────
log_step "Deploying all services"

log_info "Deploying bastion..."
railway up --service bastion --detach 2>/dev/null || log_warn "Bastion deploy may need manual trigger"

log_info "Deploying dashboard..."
railway up --service dashboard --detach 2>/dev/null || log_warn "Dashboard deploy may need manual trigger"

for i in $(seq 1 "$NUM_AGENTS"); do
    log_info "Deploying agent-$i..."
    railway up --service "agent-$i" --detach 2>/dev/null || log_warn "Agent-$i deploy may need manual trigger"
done

log_success "All deployments initiated"

# ── Summary ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
log_success "Deployment complete!"
echo ""
echo -e "${BOLD}Services:${RESET}"
echo "  Bastion:     bastion (TCP proxy needed)"
echo "  Dashboard:   ${DASHBOARD_DOMAIN:-<generate with: railway domain --service dashboard>}"
echo "  Agents:      agent-1 through agent-$NUM_AGENTS"
echo "  Bucket:      $B_BUCKET_NAME ($B_REGION)"
echo ""
echo -e "${BOLD}${YELLOW}MANUAL STEP REQUIRED (one-time):${RESET}"
echo ""
echo "  1. Open Railway dashboard:"
echo "     https://railway.com/project/$PROJECT_ID"
echo ""
echo "  2. Click on the 'bastion' service"
echo "  3. Go to Settings > Networking > TCP Proxy"
echo "  4. Enter port: 22"
echo "  5. Copy the generated hostname and port"
echo ""
echo -e "${BOLD}Then run:${RESET}"
echo "  ./scripts/ssh-setup.sh"
echo ""
