#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$ROOT_DIR/config.sh"

# Load the MNEMONIC from .env
if [ -f "$ROOT_DIR/.env" ]; then
    source "$ROOT_DIR/.env"
fi

CONTRACT_PATH="src/SeismicNFT.sol:SeismicNFT"

if [ -z "$MNEMONIC" ]; then
  echo "Missing MNEMONIC in .env" >&2
  exit 1
fi

echo "Deploying SeismicNFT with Mnemonic..."

deploy_output=$(cd "$ROOT_DIR/packages/contract" && sforge create \
  --rpc-url "$RPC_URL" \
  --mnemonic "$MNEMONIC" \
  --broadcast \
  "$CONTRACT_PATH")

contract_address=$(echo "$deploy_output" | awk '/Deployed to:/ {print $3}')

# Output addressing layout
mkdir -p "$ROOT_DIR/packages/contract/out"
echo "$contract_address" > "$ROOT_DIR/packages/contract/out/deploy.txt"

cat <<EOF
{
  "contractAddress": "$contract_address",
  "contractLink": "$EXPLORER_URL/address/$contract_address"
}
EOF
