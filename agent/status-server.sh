#!/bin/bash
# Lightweight HTTP status server for OpenCode agent
# Responds to GET requests on port 8080 with agent status JSON

PORT=${STATUS_PORT:-8080}
AGENT_ID=${AGENT_ID:-"agent-unknown"}

get_cpu_usage() {
    # Get CPU usage percentage
    top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}' 2>/dev/null || echo "0"
}

get_memory_usage() {
    # Get memory usage in MB
    free -m | awk 'NR==2{print $3}' 2>/dev/null || echo "0"
}

get_uptime() {
    # Get uptime in human readable format
    uptime -p 2>/dev/null | sed 's/up //' || echo "unknown"
}

get_opencode_status() {
    # Check if opencode process is running
    if pgrep -f "opencode" > /dev/null 2>&1; then
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
    # Try to get current opencode session info
    # This queries the local opencode server if running
    local session_title="null"
    local session_duration="null"
    local message_count=0
    
    # Check if opencode server is running on default port
    if curl -s "http://localhost:4096/global/health" > /dev/null 2>&1; then
        local session_data=$(curl -s "http://localhost:4096/session" 2>/dev/null | jq -r '.[0] // empty')
        if [ -n "$session_data" ]; then
            session_title=$(echo "$session_data" | jq -r '.title // "Untitled"')
            # Calculate duration from created_at if available
            local created=$(echo "$session_data" | jq -r '.created_at // empty')
            if [ -n "$created" ]; then
                local now=$(date +%s)
                local start=$(date -d "$created" +%s 2>/dev/null || echo "$now")
                local diff=$((now - start))
                local mins=$((diff / 60))
                if [ $mins -lt 60 ]; then
                    session_duration="${mins}m"
                else
                    local hours=$((mins / 60))
                    local remaining_mins=$((mins % 60))
                    session_duration="${hours}h ${remaining_mins}m"
                fi
            fi
        fi
    fi
    
    echo "{\"title\": \"$session_title\", \"duration\": \"$session_duration\", \"messageCount\": $message_count}"
}

generate_response() {
    local status=$(get_opencode_status)
    local cpu=$(get_cpu_usage)
    local memory=$(get_memory_usage)
    local uptime=$(get_uptime)
    local repo=$(get_current_repo)
    local session=$(get_session_info)
    
    # Determine if busy (actively streaming/generating)
    local final_status="$status"
    if [ "$status" = "active" ] && [ "$cpu" -gt 50 ]; then
        final_status="busy"
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
    while read -r line; do
        request="$line"
        # Read until empty line (end of HTTP headers)
        if [ -z "$(echo "$line" | tr -d '\r\n')" ]; then
            break
        fi
    done
    
    # Extract path from request
    local path=$(echo "$request" | awk '{print $2}')
    
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

# Handle mode for socat/netcat exec
if [ "$1" = "--handle" ]; then
    handle_request
    exit 0
fi
