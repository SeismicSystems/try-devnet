#!/bin/bash

load_project_env() {
  local root_dir="$1"

  if [ -f "$root_dir/config.sh" ]; then
    source "$root_dir/config.sh"
  fi

  if [ -f "$root_dir/.env" ]; then
    source "$root_dir/.env"
  fi
}

ensure_contract_dependencies() {
  if ! command -v sforge >/dev/null 2>&1; then
    echo "Missing sforge. Install Seismic's Foundry toolchain first." >&2
    echo "Docs: https://docs.seismic.systems/appendix/deployments" >&2
    exit 1
  fi

  if [ ! -d "node_modules/@openzeppelin/contracts" ]; then
    echo "Installing npm contract dependencies..."
    npm install
  fi

  if [ ! -f "lib/forge-std/src/Script.sol" ]; then
    if [ -d "lib/forge-std" ]; then
      echo "lib/forge-std exists but is incomplete. Remove it, then rerun this script." >&2
      exit 1
    fi

    if ! command -v git >/dev/null 2>&1; then
      echo "Missing git, needed to install forge-std." >&2
      exit 1
    fi

    echo "Installing forge-std..."
    mkdir -p lib
    git clone --depth 1 https://github.com/foundry-rs/forge-std lib/forge-std
  fi
}

build_wallet_args() {
  WALLET_ARGS=()

  if [ -n "${PRIVATE_KEY:-}" ]; then
    WALLET_ARGS=(--private-key "$PRIVATE_KEY")
  elif [ -n "${PRIVKEY:-}" ]; then
    WALLET_ARGS=(--private-key "$PRIVKEY")
  elif [ -n "${MNEMONIC:-}" ]; then
    WALLET_ARGS=(--mnemonic "$MNEMONIC")
  else
    echo "Missing wallet credentials. Set MNEMONIC, PRIVATE_KEY, or PRIVKEY in .env." >&2
    exit 1
  fi
}

build_tx_args() {
  TX_ARGS=()

  if [ -n "${GAS_PRICE:-}" ]; then
    TX_ARGS+=(--gas-price "$GAS_PRICE")
  fi

  if [ -n "${PRIORITY_GAS_PRICE:-}" ]; then
    TX_ARGS+=(--priority-gas-price "$PRIORITY_GAS_PRICE")
  fi

  if [ -n "${NONCE:-}" ]; then
    TX_ARGS+=(--nonce "$NONCE")
  fi

  if [ "${LEGACY:-}" = "1" ]; then
    TX_ARGS+=(--legacy)
  fi
}

deploy_contract() {
  local contract_path="$1"
  local output_file="$2"
  shift 2

  if [ -z "${RPC_URL:-}" ]; then
    echo "Missing RPC_URL in .env." >&2
    exit 1
  fi

  build_wallet_args
  build_tx_args

  set +e
  deploy_output=$(sforge create \
    --rpc-url "$RPC_URL" \
    "${WALLET_ARGS[@]}" \
    "${TX_ARGS[@]}" \
    --broadcast \
    "$@" \
    "$contract_path" 2>&1)
  deploy_status=$?
  set -e

  echo "$deploy_output"

  if [ "$deploy_status" -ne 0 ]; then
    if echo "$deploy_output" | grep -qi "replacement transaction underpriced"; then
      cat >&2 <<'EOF'

The RPC rejected this deploy because the account already has a pending transaction
with the same nonce and the replacement gas price is too low.

Fix options:
  1. Wait until the pending transaction is mined, then rerun.
  2. Rerun with a higher GAS_PRICE, for example:
       GAS_PRICE=2000000000 bash script/deploy.sh
  3. If you know the correct next nonce, set both NONCE and GAS_PRICE:
       NONCE=<next_nonce> GAS_PRICE=2000000000 bash script/deploy.sh
  4. Use a fresh funded deployer wallet.
EOF
    fi
    exit "$deploy_status"
  fi

  contract_address=$(echo "$deploy_output" | awk '/Deployed to:/ {print $3}' | tail -n 1)

  if [ -z "$contract_address" ]; then
    echo "Deploy finished but contract address could not be parsed." >&2
    exit 1
  fi

  mkdir -p "$ROOT_DIR/packages/contract/out"
  echo "$contract_address" > "$ROOT_DIR/packages/contract/out/$output_file"

  contract_link=""
  if [ -n "${EXPLORER_URL:-}" ]; then
    contract_link="$EXPLORER_URL/address/$contract_address"
  fi

  cat <<EOF
{
  "contractAddress": "$contract_address",
  "contractLink": "$contract_link"
}
EOF
}
