#!/bin/bash
# Deploy helper for Railway
# Usage: ./scripts/deploy.sh

set -e

echo "OpenCode Agent Pool - Railway Deployment Helper"
echo "================================================"
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "Railway CLI is not installed."
    echo "Install it with: npm install -g @railway/cli"
    echo "Or: brew install railway"
    exit 1
fi

# Check if logged in
if ! railway whoami &> /dev/null; then
    echo "Not logged in to Railway. Running: railway login"
    railway login
fi

echo ""
echo "This script will help you set up the Railway project."
echo ""
echo "Steps:"
echo "  1. Create a new Railway project"
echo "  2. Create services for bastion, dashboard, and 5 agents"
echo "  3. Set environment variables"
echo "  4. Deploy"
echo ""

read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Check for .env file
if [ ! -f .env ]; then
    echo ""
    echo "No .env file found. Creating template..."
    cat > .env << 'EOF'
# SSH public key for accessing agents (run: ./scripts/generate-keys.sh)
SSH_AUTHORIZED_KEYS=

# AWS Bedrock authentication (bearer token)
AWS_BEARER_TOKEN_BEDROCK=
AWS_REGION=us-east-1

# Dashboard password (leave empty to disable auth)
DASHBOARD_PASSWORD=
EOF
    echo "Created .env file. Please fill in the values and run this script again."
    exit 1
fi

source .env

# Validate required vars
if [ -z "$SSH_AUTHORIZED_KEYS" ]; then
    echo "Error: SSH_AUTHORIZED_KEYS not set in .env"
    echo "Run ./scripts/generate-keys.sh first."
    exit 1
fi

if [ -z "$AWS_BEARER_TOKEN_BEDROCK" ]; then
    echo "Error: AWS_BEARER_TOKEN_BEDROCK not set in .env"
    exit 1
fi

echo ""
echo "Environment variables loaded from .env"
echo ""
echo "To deploy, create the following services in Railway's dashboard:"
echo ""
echo "  1. bastion       - Build from ./bastion, TCP port 22 (public)"
echo "  2. dashboard     - Build from ./dashboard, HTTP port 3000 (public)"
echo "  3. agent-1       - Build from ./agent, internal only"
echo "  4. agent-2       - Build from ./agent, internal only"
echo "  5. agent-3       - Build from ./agent, internal only"
echo "  6. agent-4       - Build from ./agent, internal only"
echo "  7. agent-5       - Build from ./agent, internal only"
echo ""
echo "Set environment variables for each service as described in railway-config.md"
echo ""
echo "Then deploy with: railway up"
