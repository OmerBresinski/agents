# OpenCode Agent Pool on Railway

A fully remote agentic setup for running pre-provisioned OpenCode instances on Railway.app with SSH access, AWS Bedrock integration, and a real-time status dashboard.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                           Railway.app                                │
│                                                                      │
│  ┌──────────────┐    ┌──────────────────┐                            │
│  │   Bastion     │    │   Dashboard      │◄── HTTPS (browser)        │
│  │  (SSH Jump)   │    │  (React + API)   │                           │
│  └──────┬───────┘    └────────┬─────────┘                            │
│         │ SSH                 │ HTTP (status poll)                    │
│         ▼                     ▼                                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                    │
│  │  Agent 1    │ │  Agent 2    │ │  Agent N    │                    │
│  │  OpenCode   │ │  OpenCode   │ │  OpenCode   │                    │
│  │  + SSH      │ │  + SSH      │ │  + SSH      │                    │
│  │  + Bedrock  │ │  + Bedrock  │ │  + Bedrock  │                    │
│  └─────────────┘ └─────────────┘ └─────────────┘                    │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

| Service | Description | Public |
|---------|-------------|--------|
| **bastion** | SSH jump host for routing connections to agents | Yes (TCP/22) |
| **dashboard** | React status UI + API aggregator | Yes (HTTPS) |
| **agent-1..5** | Isolated OpenCode containers with SSH + Bedrock | No (internal) |

## Quick Start

### 1. Generate SSH Keys

```bash
./scripts/generate-keys.sh
```

### 2. Create Environment File

```bash
cp .env.example .env
# Edit .env with your values
```

Required variables:
- `SSH_AUTHORIZED_KEYS` - Your SSH public key
- `AWS_BEARER_TOKEN_BEDROCK` - Bearer token for AWS Bedrock
- `AWS_REGION` - AWS region (default: `us-east-1`)

### 3. Test Locally

```bash
docker compose up --build
```

- Dashboard: http://localhost:3000
- SSH: `ssh -J localhost:2222 agent-1` (with `-o User=opencode`)

### 4. Deploy to Railway

See [railway-config.md](./railway-config.md) for detailed Railway setup instructions.

Create these services in Railway:
1. **bastion** - from `./bastion`, TCP port 22 (public)
2. **dashboard** - from `./dashboard`, HTTP port 3000 (public)
3. **agent-1** through **agent-5** - from `./agent`, internal only

Set environment variables on each service per the config guide.

## Usage

### Connect to an Agent

```bash
# Direct connection via bastion
ssh -J bastion-xxx.up.railway.app agent-1

# With SSH config (recommended)
ssh agent-1
```

### SSH Config Setup

Add to `~/.ssh/config`:

```
Host bastion
    HostName bastion-xxx.up.railway.app
    User opencode
    IdentityFile ~/.ssh/opencode-agent-pool

Host agent-*
    ProxyJump bastion
    User opencode
    IdentityFile ~/.ssh/opencode-agent-pool
```

### Working with a Repo

Once connected to an agent:

```bash
cd /workspace
git clone git@github.com:your-org/your-repo.git
cd your-repo
opencode
```

### Dashboard

The dashboard at `https://dashboard-xxx.up.railway.app` shows:
- **Pool status** - idle/active/busy/total counts
- **Agent cards** - per-agent status, repo, session, CPU/memory
- **SSH commands** - one-click copy for connecting
- **Session history** - recent completed sessions
- **Quick start guide** - first-time setup instructions

## Configuration

### OpenCode Model

Edit `agent/opencode.json` to change the default model:

```json
{
  "provider": {
    "bedrock": {
      "aws_region": "us-east-1"
    }
  },
  "model": "amazon-bedrock/anthropic.claude-sonnet-4-20250514-v1:0"
}
```

### Dashboard Auth

Set `DASHBOARD_PASSWORD` to protect the dashboard with HTTP Basic Auth:

```bash
DASHBOARD_PASSWORD=your-secret-password
DASHBOARD_USER=admin  # optional, defaults to "admin"
```

### Scaling

To add more agents, duplicate an agent service in Railway with a new `AGENT_ID` and update:
- The bastion's `AGENT_N_HOST` env var
- The dashboard's `AGENT_N_HOST` env var
- The docker-compose.yml (for local testing)

## Project Structure

```
railway-opencode/
├── agent/                  # OpenCode agent container
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── sshd_config
│   ├── opencode.json       # Bedrock config
│   └── status-server.sh    # Status endpoint (:8080)
├── bastion/                # SSH jump host
│   ├── Dockerfile
│   ├── entrypoint.sh
│   ├── sshd_config
│   └── ssh_config
├── dashboard/              # React + shadcn/ui dashboard
│   ├── Dockerfile
│   ├── src/
│   │   ├── components/     # UI components
│   │   ├── hooks/          # React Query hooks
│   │   └── types/          # TypeScript types
│   └── server/             # API aggregation server
├── scripts/
│   ├── generate-keys.sh
│   └── deploy.sh
├── docker-compose.yml      # Local testing
├── .env.example
└── railway-config.md       # Railway setup guide
```
