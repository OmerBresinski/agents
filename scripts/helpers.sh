#!/bin/bash
# Shared utility functions for OpenCode Agent Pool scripts
# Source this file: source "$(dirname "$0")/helpers.sh"

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Logging ──────────────────────────────────────────────────
log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

log_step() {
    echo -e "\n${BOLD}${CYAN}>> $1${RESET}"
}

# ── Validation ───────────────────────────────────────────────

# Check if a command is available
# Usage: require_command "railway" "Install with: npm i -g @railway/cli"
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "'$cmd' is not installed."
        if [ -n "$install_hint" ]; then
            echo "  $install_hint"
        fi
        exit 1
    fi
}

# Check if an environment variable / value is set
# Usage: require_env "PROJECT_ID" "$PROJECT_ID"
require_env() {
    local name="$1"
    local value="$2"
    if [ -z "$value" ]; then
        log_error "$name is required but not set."
        exit 1
    fi
}

# ── Railway CLI helpers ──────────────────────────────────────

# Get the major version of the Railway CLI (returns integer or 0)
railway_cli_version() {
    local version
    version=$(railway --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ -z "$version" ]; then
        version=$(railway version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    echo "${version%%.*}"
}

# Ensure Railway CLI is v4+
ensure_railway_v4() {
    if ! command -v railway &>/dev/null; then
        log_info "Railway CLI not found. Installing..."
        npm install -g @railway/cli || {
            log_error "Failed to install Railway CLI. Try: npm i -g @railway/cli"
            exit 1
        }
    fi

    local major
    major=$(railway_cli_version)
    if [ "$major" -lt 4 ] 2>/dev/null; then
        log_info "Railway CLI is v${major}.x, upgrading to v4..."
        railway upgrade 2>/dev/null || npm install -g @railway/cli || {
            log_error "Failed to upgrade Railway CLI."
            exit 1
        }
        # Verify
        major=$(railway_cli_version)
        if [ "$major" -lt 4 ] 2>/dev/null; then
            log_error "Railway CLI upgrade failed. Still on v${major}."
            log_error "Try manually: npm install -g @railway/cli"
            exit 1
        fi
    fi

    log_success "Railway CLI v$(railway --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
}

# Ensure Railway is authenticated
ensure_railway_auth() {
    if ! railway whoami &>/dev/null; then
        log_info "Not logged in to Railway. Opening login..."
        railway login || {
            log_error "Railway login failed."
            exit 1
        }
    fi
    log_success "Railway authenticated"
}

# ── Project paths ────────────────────────────────────────────

# Get the root directory of the railway-opencode project
project_root() {
    echo "$(cd "$(dirname "$0")/.." && pwd)"
}
