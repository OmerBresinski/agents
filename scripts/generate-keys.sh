#!/bin/bash
# Generate SSH key pair for accessing the OpenCode agent pool
# Usage: ./scripts/generate-keys.sh

set -e

KEY_DIR="$(dirname "$0")/../keys"
mkdir -p "$KEY_DIR"

KEY_PATH="$KEY_DIR/opencode-agent-pool"

if [ -f "$KEY_PATH" ]; then
    echo "SSH key already exists at $KEY_PATH"
    echo "To regenerate, delete the existing key first:"
    echo "  rm $KEY_PATH $KEY_PATH.pub"
    exit 1
fi

echo "Generating SSH key pair for OpenCode Agent Pool..."
ssh-keygen -t ed25519 -f "$KEY_PATH" -C "opencode-agent-pool" -N ""

echo ""
echo "Keys generated successfully!"
echo ""
echo "Private key: $KEY_PATH"
echo "Public key:  $KEY_PATH.pub"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo "Next steps:"
echo ""
echo "1. Set the public key as SSH_AUTHORIZED_KEYS in your .env file:"
echo ""
echo "   SSH_AUTHORIZED_KEYS=\"$(cat "$KEY_PATH.pub")\""
echo ""
echo "2. Add the private key to your SSH agent:"
echo ""
echo "   ssh-add $KEY_PATH"
echo ""
echo "3. Or add it to your ~/.ssh/config:"
echo ""
echo "   Host bastion"
echo "       HostName <your-bastion-host>"
echo "       User opencode"
echo "       IdentityFile $(realpath "$KEY_PATH")"
echo ""
echo "   Host agent-*"
echo "       ProxyJump bastion"
echo "       User opencode"
echo "       IdentityFile $(realpath "$KEY_PATH")"
echo ""
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "⚠ Keep the private key safe! Do not commit it to git."
