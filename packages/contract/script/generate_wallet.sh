#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$ROOT_DIR/config.sh"
source "$ROOT_DIR/packages/common/wallet.sh"

dev_wallet

cat <<EOF
{
  "walletAddress": "$DEV_WALLET_ADDRESS",
  "privateKey": "$DEV_WALLET_PRIVKEY",
  "faucet": "$FAUCET_URL"
}
EOF
