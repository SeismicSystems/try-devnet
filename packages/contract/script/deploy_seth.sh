#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$SCRIPT_DIR/deploy_common.sh"
load_project_env "$ROOT_DIR"

cd "$ROOT_DIR/packages/contract"
ensure_contract_dependencies

echo "Deploying ShieldedETH (SRC-20) with 0.01 ETH initial liquidity..."
deploy_contract \
  "src/ShieldedETH.sol:ShieldedETH" \
  "deploy_seth.txt" \
  --value 10000000000000000
