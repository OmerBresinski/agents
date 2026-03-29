#!/bin/bash
# Lightweight HTTP status server for OpenCode agent
# Responds to GET requests on port 9090 with agent status JSON

# Ensure full PATH is available (socat exec has minimal env)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

PORT=${STATUS_PORT:-9090}
AGENT_ID=${AGENT_ID:-"agent-unknown"}

get_cpu_usage() {
    # Get CPU usage percentage
    # Use /proc/stat snapshot (not perfect but lightweight)
    local idle total
    read -r _ user nice system idle iowait irq softirq _ < /proc/stat 2>/dev/null
    total=$((user + nice + system + idle + iowait + irq + softirq))
    if [ "$total" -gt 0 ] 2>/dev/null; then
        echo $(( 100 * (total - idle) / total ))
    else
        echo "0"
    fi
}

get_memory_usage() {
    # Get container memory usage in MB via cgroup (not host /proc/meminfo)
    local usage_bytes
    usage_bytes=$(cat /sys/fs/cgroup/memory.current 2>/dev/null || \
                  cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null || \
                  echo "0")
    echo $((usage_bytes / 1048576))
}

get_uptime() {
    # Get container uptime from PID 1 elapsed time
    local seconds
    seconds=$(ps -o etimes= -p 1 2>/dev/null | tr -d ' ')

    if [ -n "$seconds" ] && [ "$seconds" -gt 0 ] 2>/dev/null; then
        local days=$((seconds / 86400))
        local hours=$(( (seconds % 86400) / 3600 ))
        local mins=$(( (seconds % 3600) / 60 ))

        if [ "$days" -gt 0 ]; then
            echo "${days}d ${hours}h ${mins}m"
        elif [ "$hours" -gt 0 ]; then
            echo "${hours}h ${mins}m"
        else
            echo "${mins}m"
        fi
    else
        echo "unknown"
    fi
}

get_opencode_status() {
    # Check if opencode process is running by looking for the binary
    if pgrep -f "bin/.opencode" > /dev/null 2>&1; then
        echo "active"
    else
        echo "idle"
    fi
}

get_current_repo() {
    # Try to find current working directory with a git repo
    local repo=""
    
    # Check if any opencode process is running and get its cwd
    local pid=$(pgrep -f "opencode" | head -1)
    if [ -n "$pid" ]; then
        local cwd=$(readlink -f /proc/$pid/cwd 2>/dev/null)
        if [ -d "$cwd/.git" ]; then
            repo=$(git -C "$cwd" config --get remote.origin.url 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/\.git$//')
        fi
    fi
    
    # Fallback: check /workspace subdirectories
    if [ -z "$repo" ]; then
        for dir in /workspace/*/; do
            if [ -d "${dir}.git" ]; then
                repo=$(git -C "$dir" config --get remote.origin.url 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/\.git$//' | head -1)
                break
            fi
        done
    fi
    
    echo "${repo:-null}"
}

get_session_info() {
    # Get session info using the opencode CLI (no HTTP API needed)
    # Caches results and only re-exports when the session changes.
    # Uses a fingerprint (session_id + updated_time) to detect changes.

    local CACHE_FILE="/tmp/.opencode-session-cache.json"
    local FINGERPRINT_FILE="/tmp/.opencode-session-fingerprint"
    local DEFAULT_RESPONSE='{
    "title": null,
    "duration": null,
    "messageCount": 0,
    "tokens": { "input": 0, "output": 0, "reasoning": 0 },
    "cost": 0,
    "models": []
}'

    # If opencode is not running, return empty (no cache)
    if ! pgrep -f "bin/.opencode" > /dev/null 2>&1; then
        rm -f "$CACHE_FILE"
        echo "$DEFAULT_RESPONSE"
        return
    fi

    # Get the most recent session ID and its updated timestamp
    local session_line
    session_line=$(sudo -u opencode opencode session list -n 1 2>/dev/null | grep "^ses_" | head -1)
    local session_id=$(echo "$session_line" | awk '{print $1}')

    if [ -z "$session_id" ]; then
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
        else
            echo "$DEFAULT_RESPONSE"
        fi
        return
    fi

    # Build a fingerprint from session_id + the full line (includes updated time)
    local fingerprint="${session_line}"
    local old_fingerprint=""
    [ -f "$FINGERPRINT_FILE" ] && old_fingerprint=$(cat "$FINGERPRINT_FILE")

    # If fingerprint hasn't changed and cache exists with non-zero cost, return cache
    if [ "$fingerprint" = "$old_fingerprint" ] && [ -f "$CACHE_FILE" ]; then
        local cached_cost
        cached_cost=$(jq -r '.cost // 0' "$CACHE_FILE" 2>/dev/null)
        if [ "$cached_cost" != "0" ] && [ -n "$cached_cost" ]; then
            cat "$CACHE_FILE"
            return
        fi
        # Cache has cost 0, re-export to try getting real data
    fi

    # Export the session data directly to file (no pipes to avoid buffer truncation)
    local EXPORT_FILE="/tmp/.opencode-export-$(date +%s%N).json"
    sudo -u opencode opencode export "$session_id" > "$EXPORT_FILE" 2>/dev/null

    # Strip the "Exporting session:" line if present (it's the first line, before JSON)
    if head -1 "$EXPORT_FILE" 2>/dev/null | grep -q "^Exporting"; then
        tail -n +2 "$EXPORT_FILE" > "${EXPORT_FILE}.tmp" && mv "${EXPORT_FILE}.tmp" "$EXPORT_FILE"
    fi

    if [ ! -s "$EXPORT_FILE" ] || ! jq empty "$EXPORT_FILE" 2>/dev/null; then
        echo "export failed: size=$(wc -c < "$EXPORT_FILE" 2>/dev/null), head=$(head -c 100 "$EXPORT_FILE" 2>/dev/null)" >> /tmp/.opencode-debug.log
        rm -f "$EXPORT_FILE"
        # Export failed -- return cache if available
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
        else
            echo "$DEFAULT_RESPONSE"
        fi
        return
    fi

    # Parse the export data from file
    local session_title session_duration message_count tokens_input tokens_output tokens_reasoning total_cost models_json

    session_title=$(jq -r '.info.title // "Untitled"' "$EXPORT_FILE")

    # Calculate duration from time.created (milliseconds)
    local created_ms
    created_ms=$(jq -r '.info.time.created // empty' "$EXPORT_FILE")
    if [ -n "$created_ms" ]; then
        local now_ms=$(($(date +%s) * 1000))
        local diff_ms=$((now_ms - created_ms))
        local mins=$((diff_ms / 60000))
        if [ $mins -lt 60 ]; then
            session_duration="${mins}m"
        else
            local hours=$((mins / 60))
            local remaining_mins=$((mins % 60))
            session_duration="${hours}h ${remaining_mins}m"
        fi
    else
        session_duration="null"
    fi

    # Aggregate from messages (count ALL messages, not just assistant)
    local aggregated
    aggregated=$(jq '
        {
            messageCount: (.messages | length),
            tokens: {
                input: ([.messages[].info | select(.role == "assistant") | .tokens.input // 0] | add // 0),
                output: ([.messages[].info | select(.role == "assistant") | .tokens.output // 0] | add // 0),
                reasoning: ([.messages[].info | select(.role == "assistant") | .tokens.reasoning // 0] | add // 0)
            },
            cost: ([.messages[].info | select(.role == "assistant") | .cost // 0] | add // 0),
            models: (
                [.messages[].info | select(.role == "assistant")] |
                group_by(.modelID // "unknown") |
                map({
                    id: (.[0].modelID // "unknown"),
                    provider: (.[0].providerID // "unknown"),
                    messages: length
                }) |
                sort_by(-.messages)
            )
        }
    ' "$EXPORT_FILE" 2>/dev/null)

    rm -f "$EXPORT_FILE"

    if [ -n "$aggregated" ] && [ "$aggregated" != "null" ]; then
        message_count=$(echo "$aggregated" | jq -r '.messageCount // 0')
        tokens_input=$(echo "$aggregated" | jq -r '.tokens.input // 0')
        tokens_output=$(echo "$aggregated" | jq -r '.tokens.output // 0')
        tokens_reasoning=$(echo "$aggregated" | jq -r '.tokens.reasoning // 0')
        total_cost=$(echo "$aggregated" | jq -r '.cost // 0')
        models_json=$(echo "$aggregated" | jq -c '.models // []')
    else
        message_count=0
        tokens_input=0
        tokens_output=0
        tokens_reasoning=0
        total_cost=0
        models_json="[]"
    fi

    # Build the result JSON
    local result
    result=$(cat << EOF
{
    "title": $([ "$session_title" = "null" ] && echo "null" || echo "\"$session_title\""),
    "duration": $([ "$session_duration" = "null" ] && echo "null" || echo "\"$session_duration\""),
    "messageCount": $message_count,
    "tokens": {
        "input": $tokens_input,
        "output": $tokens_output,
        "reasoning": $tokens_reasoning
    },
    "cost": $total_cost,
    "models": $models_json
}
EOF
)

    # Cache the result and fingerprint
    echo "$result" > "$CACHE_FILE"
    echo "$fingerprint" > "$FINGERPRINT_FILE"
    echo "$result"
}

generate_response() {
    local status=$(get_opencode_status)
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local uptime=$(get_uptime)
    local repo=$(get_current_repo)
    local session=$(get_session_info)
    
    # Determine final status:
    # - idle: opencode not running
    # - active: opencode running with a session
    # - busy: opencode running and actively generating (high CPU)
    local final_status="$status"
    if [ "$status" = "active" ]; then
        # Check if there's an actual session title
        local has_session=$(echo "$session" | jq -r '.title // empty' 2>/dev/null)
        if [ -z "$has_session" ] || [ "$has_session" = "null" ]; then
            final_status="active"
        elif [ "$cpu" -gt 30 ]; then
            final_status="busy"
        fi
    fi
    
    cat << EOF
{
  "id": "$AGENT_ID",
  "status": "$final_status",
  "repo": $([ "$repo" = "null" ] && echo "null" || echo "\"$repo\""),
  "session": $session,
  "resources": {
    "cpu": $cpu,
    "memory": $memory
  },
  "uptime": "$uptime"
}
EOF
}

# Simple HTTP server using bash and netcat
handle_request() {
    local request=""
    local first_line=""
    while IFS= read -r line; do
        # Strip carriage return
        line="${line%%$'\r'}"
        # Capture the first line (e.g., "GET /status HTTP/1.1")
        if [ -z "$first_line" ]; then
            first_line="$line"
        fi
        # Empty line = end of HTTP headers
        if [ -z "$line" ]; then
            break
        fi
    done
    
    # Extract path from first line of request
    local path=$(echo "$first_line" | awk '{print $2}')
    
    local response=""
    local content_type="application/json"
    local status_code="200 OK"
    
    case "$path" in
        "/status"|"/"|"/health")
            response=$(generate_response)
            ;;
        *)
            status_code="404 Not Found"
            response='{"error": "Not found"}'
            ;;
    esac
    
    local content_length=${#response}
    
    printf "HTTP/1.1 %s\r\n" "$status_code"
    printf "Content-Type: %s\r\n" "$content_type"
    printf "Content-Length: %d\r\n" "$content_length"
    printf "Access-Control-Allow-Origin: *\r\n"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "$response"
}

# Handle mode for socat/netcat exec -- must be before server startup
if [ "$1" = "--handle" ]; then
    handle_request
    exit 0
fi

echo "Status server starting on port $PORT..."

# Check if socat is available, otherwise use netcat
if command -v socat &> /dev/null; then
    socat TCP-LISTEN:$PORT,reuseaddr,fork EXEC:"$0 --handle"
elif command -v nc &> /dev/null; then
    while true; do
        echo "" | nc -l -p $PORT -c "$0 --handle" 2>/dev/null || \
        nc -l -p $PORT -e "$0 --handle" 2>/dev/null || \
        { echo "netcat doesn't support -c or -e, using bash"; break; }
    done
else
    # Fallback: use bash with /dev/tcp (requires bash compiled with net support)
    echo "Warning: Neither socat nor compatible netcat found. Status server may not work."
    while true; do
        { handle_request; } < /dev/tcp/0.0.0.0/$PORT > /dev/tcp/0.0.0.0/$PORT 2>/dev/null || sleep 5
    done
fi
