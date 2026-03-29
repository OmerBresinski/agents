#!/bin/bash
# Workspace sync script for OpenCode agents
# Syncs /workspace to/from a Railway Bucket (S3-compatible) using s5cmd
#
# Usage:
#   workspace-sync restore   # Pull workspace from bucket on startup
#   workspace-sync watch     # Background daemon: sync every 5 minutes
#   workspace-sync upload    # One-shot immediate sync to bucket

set -euo pipefail

WORKSPACE="/workspace"
AGENT_ID="${AGENT_ID:-agent-unknown}"
SYNC_INTERVAL="${SYNC_INTERVAL:-300}"  # 5 minutes
LAST_SYNC_FILE="/tmp/.workspace-last-sync"

# ── S3 configuration ────────────────────────────────────────
# s5cmd reads credentials from environment variables:
#   S3_ENDPOINT_URL  (mapped from BUCKET_ENDPOINT)
#   AWS_ACCESS_KEY_ID
#   AWS_SECRET_ACCESS_KEY

setup_s3_env() {
    # Map BUCKET_* vars to what s5cmd expects
    export S3_ENDPOINT_URL="${BUCKET_ENDPOINT:-}"
    export AWS_ACCESS_KEY_ID="${BUCKET_ACCESS_KEY_ID:-}"
    export AWS_SECRET_ACCESS_KEY="${BUCKET_SECRET_ACCESS_KEY:-}"
    export AWS_DEFAULT_REGION="${BUCKET_REGION:-ams}"
}

# Check if bucket credentials are configured
bucket_configured() {
    if [ -z "${BUCKET_ENDPOINT:-}" ] || [ -z "${BUCKET_ACCESS_KEY_ID:-}" ] || \
       [ -z "${BUCKET_SECRET_ACCESS_KEY:-}" ] || [ -z "${BUCKET_NAME:-}" ]; then
        return 1
    fi
    return 0
}

# S3 path for this agent's workspace
s3_path() {
    echo "s3://${BUCKET_NAME}/workspaces/${AGENT_ID}/"
}

# ── Exclusion patterns ───────────────────────────────────────
# Large regenerable directories excluded from sync
# s5cmd uses glob patterns - use ** for recursive matching
S5CMD_EXCLUDE=(
    --exclude "**/node_modules/**"
    --exclude "**/.git/objects/**"
    --exclude "**/__pycache__/**"
    --exclude "**/.venv/**"
    --exclude "**/venv/**"
    --exclude "**/target/**"
    --exclude "**/.next/**"
    --exclude "**/dist/**"
    --exclude "**/.turbo/**"
    --exclude "**/.cache/**"
    --exclude "**/*.pyc"
    --exclude "**/lost+found/**"
)

# ── Commands ─────────────────────────────────────────────────

# Restore workspace from bucket (called on container startup)
cmd_restore() {
    if ! bucket_configured; then
        echo "[workspace-sync] No bucket configured, skipping restore"
        return 0
    fi

    setup_s3_env

    # Check if workspace already has content (volume persisted)
    local file_count
    file_count=$(find "$WORKSPACE" -maxdepth 1 -not -name '.' -not -name '.last-sync' | wc -l)

    if [ "$file_count" -gt 0 ]; then
        echo "[workspace-sync] Workspace has existing content ($file_count items), skipping restore"
        return 0
    fi

    echo "[workspace-sync] Workspace is empty, restoring from bucket..."
    local s3path
    s3path=$(s3_path)

    # Check if there's anything in the bucket for this agent
    if s5cmd --endpoint-url "$S3_ENDPOINT_URL" ls "$s3path" &>/dev/null; then
        s5cmd --endpoint-url "$S3_ENDPOINT_URL" sync "${S5CMD_EXCLUDE[@]}" "$s3path" "$WORKSPACE/"
        echo "[workspace-sync] Restore complete"

        # Fix ownership (s5cmd may create files as root)
        chown -R opencode:opencode "$WORKSPACE" 2>/dev/null || true
    else
        echo "[workspace-sync] No backup found in bucket for $AGENT_ID"
    fi
}

# Upload workspace to bucket (one-shot)
cmd_upload() {
    if ! bucket_configured; then
        echo "[workspace-sync] No bucket configured, skipping upload"
        return 0
    fi

    setup_s3_env

    # Check if workspace has content worth syncing
    local file_count
    file_count=$(find "$WORKSPACE" -maxdepth 1 -not -name '.' -not -name '.last-sync' | wc -l)

    if [ "$file_count" -eq 0 ]; then
        echo "[workspace-sync] Workspace is empty, nothing to upload"
        return 0
    fi

    local s3path
    s3path=$(s3_path)

    echo "[workspace-sync] Syncing workspace to bucket..."
    s5cmd --endpoint-url "$S3_ENDPOINT_URL" sync \
        "${S5CMD_EXCLUDE[@]}" \
        --delete \
        "$WORKSPACE/" "$s3path"

    # Write sync timestamp
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$LAST_SYNC_FILE"
    echo "[workspace-sync] Upload complete at $(cat "$LAST_SYNC_FILE")"
}

# Watch mode: periodic background sync
cmd_watch() {
    if ! bucket_configured; then
        echo "[workspace-sync] No bucket configured, watch mode disabled"
        # Sleep forever so the process doesn't exit (prevents entrypoint restart loops)
        exec sleep infinity
    fi

    setup_s3_env

    echo "[workspace-sync] Watch mode started (interval: ${SYNC_INTERVAL}s)"

    while true; do
        sleep "$SYNC_INTERVAL"

        # Check if workspace has content
        local file_count
        file_count=$(find "$WORKSPACE" -maxdepth 1 -not -name '.' -not -name '.last-sync' 2>/dev/null | wc -l)

        if [ "$file_count" -eq 0 ]; then
            continue
        fi

        local s3path
        s3path=$(s3_path)

        # Run sync, don't exit on failure
        if s5cmd --endpoint-url "$S3_ENDPOINT_URL" sync \
            "${S5CMD_EXCLUDE[@]}" \
            --delete \
            "$WORKSPACE/" "$s3path" 2>/dev/null; then
            date -u +"%Y-%m-%dT%H:%M:%SZ" > "$LAST_SYNC_FILE"
        else
            echo "[workspace-sync] Sync failed (will retry in ${SYNC_INTERVAL}s)"
        fi
    done
}

# ── Main ─────────────────────────────────────────────────────

case "${1:-}" in
    restore)
        cmd_restore
        ;;
    upload)
        cmd_upload
        ;;
    watch)
        cmd_watch
        ;;
    *)
        echo "Usage: workspace-sync {restore|upload|watch}"
        echo ""
        echo "  restore  Pull workspace from bucket (startup)"
        echo "  upload   One-shot sync to bucket"
        echo "  watch    Background daemon (syncs every ${SYNC_INTERVAL}s)"
        exit 1
        ;;
esac
