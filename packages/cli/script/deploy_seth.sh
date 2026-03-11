#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$ROOT_DIR/config.sh"

# Load the MNEMONIC from .env
if [ -f "$ROOT_DIR/.env" ]; then
    source "$ROOT_DIR/.env"
fi

CONTRACT_PATH="src/ShieldedETH.sol:ShieldedETH"

if [ -z "$MNEMONIC" ]; then
  echo "Missing MNEMONIC in .env" >&2
  exit 1
fi

echo "Deploying ShieldedETH (SRC-20) with 0.01 ETH initial liquidity..."

cd "$ROOT_DIR/packages/contract"

# Install dependencies if they do not exist
if [ ! -d "node_modules/@openzeppelin/contracts" ]; then
    echo "Dependencies not found. Installing..."
    npm install
fi

deploy_output=$(sforge create \
  --rpc-url "$RPC_URL" \
  --mnemonic "$MNEMONIC" \
  --broadcast \
  --value 10000000000000000 \
  "$CONTRACT_PATH")

contract_address=$(echo "$deploy_output" | awk '/Deployed to:/ {print $3}')

# Output addressing layout
mkdir -p "$ROOT_DIR/packages/contract/out"
echo "$contract_address" > "$ROOT_DIR/packages/contract/out/deploy_seth.txt"

cat <<EOF
{
  "contractAddress": "$contract_address",
  "contractLink": "$EXPLORER_URL/address/$contract_address"
}
EOF

echo ""
echo ">> Update SETH_CONTRACT_ADDRESS in packages/frontend/app/lib/config.ts"
echo ">> with: $contract_address"
