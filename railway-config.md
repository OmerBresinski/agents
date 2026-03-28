# Railway OpenCode Agent Pool
# This file documents the Railway project structure.
# Each service should be created in the Railway dashboard or via CLI.

# ┌──────────────────────────────────────────────────────────────┐
# │  Service Configuration Guide for Railway                      │
# │                                                                │
# │  Create each service in Railway with the following settings:   │
# └──────────────────────────────────────────────────────────────┘

# ── Bastion Service ──────────────────────────────────────────────
# Source:       railway-opencode/bastion
# Dockerfile:   bastion/Dockerfile
# Port:         22 (TCP)
# Public:       Yes (TCP proxy for SSH)
# Env vars:
#   SSH_AUTHORIZED_KEYS   = <your public SSH key>
#   AGENT_1_HOST          = agent-1.railway.internal
#   AGENT_2_HOST          = agent-2.railway.internal
#   AGENT_3_HOST          = agent-3.railway.internal
#   AGENT_4_HOST          = agent-4.railway.internal
#   AGENT_5_HOST          = agent-5.railway.internal

# ── Dashboard Service ────────────────────────────────────────────
# Source:       railway-opencode/dashboard
# Dockerfile:   dashboard/Dockerfile
# Port:         3000 (HTTP)
# Public:       Yes (HTTPS)
# Env vars:
#   PORT                  = 3000
#   AGENT_1_HOST          = agent-1.railway.internal
#   AGENT_2_HOST          = agent-2.railway.internal
#   AGENT_3_HOST          = agent-3.railway.internal
#   AGENT_4_HOST          = agent-4.railway.internal
#   AGENT_5_HOST          = agent-5.railway.internal
#   AGENT_STATUS_PORT     = 8080
#   DASHBOARD_USER        = admin
#   DASHBOARD_PASSWORD    = <your dashboard password>

# ── Agent Services (repeat for agent-1 through agent-5) ─────────
# Source:       railway-opencode/agent
# Dockerfile:   agent/Dockerfile
# Port:         22 (TCP, internal), 8080 (HTTP, internal)
# Public:       No (internal only)
# Volume:       /workspace (persistent)
# Env vars:
#   AGENT_ID              = agent-N
#   SSH_AUTHORIZED_KEYS   = <your public SSH key>
#   AWS_BEARER_TOKEN_BEDROCK = <your bedrock bearer token>
#   AWS_REGION            = us-east-1
