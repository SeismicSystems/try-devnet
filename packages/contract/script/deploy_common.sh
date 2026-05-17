#!/bin/bash

usage() {
  cat <<'EOF'
Seismic deploy helper

Usage:
  bash deploy.sh [target] [options] [-- <extra sforge create args>]

Targets:
  nft                         Deploy src/SeismicNFT.sol:SeismicDiscordStat
  seth                        Deploy src/ShieldedETH.sol:ShieldedETH with 0.01 ETH value
  <File.sol>                  Deploy src/File.sol:File
  --<File.sol>                Same as <File.sol>
  <path.sol:ContractName>     Deploy any contract under packages/contract

Options:
  --contract <target>         Same as positional target
  --file <file.sol>           Deploy a Solidity file from packages/contract/src
  --contract-name <name>      Contract name when it differs from the file name
  --output <file>             Output file in packages/contract/out
  --value <wei>               ETH value sent to constructor
  --gas-price <wei>           Legacy or max fee gas price
  --priority-gas-price <wei>  Priority gas price
  --nonce <nonce>             Use a specific account nonce
  --legacy                    Send a legacy transaction
  --rpc-url <url>             Override RPC_URL
  --private-key <key>         Override PRIVATE_KEY
  --mnemonic <mnemonic>       Override MNEMONIC
  --no-install                Skip dependency installation
  -h, --help                  Show this help

Environment:
  RPC_URL, EXPLORER_URL, PRIVATE_KEY, PRIVKEY, MNEMONIC, GAS_PRICE,
  PRIORITY_GAS_PRICE, NONCE, LEGACY

Examples:
  bash deploy.sh nft
  bash deploy.sh seth
  bash deploy.sh --MyToken.sol
  bash deploy.sh --file MyToken.sol
  bash deploy.sh --file MyFile.sol --contract-name MyContract
  bash deploy.sh src/MyToken.sol:MyToken
  bash deploy.sh nft --legacy --gas-price 10000000000
  bash deploy.sh src/Vault.sol:Vault -- --constructor-args 123
EOF
}

load_project_env() {
  local root_dir="$1"

  if [ -f "$root_dir/config.sh" ]; then
    source "$root_dir/config.sh"
  fi

  if [ -f "$root_dir/.env" ]; then
    source "$root_dir/.env"
  fi
}

resolve_sol_file_target() {
  local sol_file="$1"
  local file_name
  local contract_name
  local contract_file

  file_name="${sol_file##*/}"
  contract_name="${DEPLOY_CONTRACT_NAME_OVERRIDE:-${file_name%.sol}}"

  if [ "$sol_file" = "$file_name" ]; then
    contract_file="src/$sol_file"
  else
    contract_file="$sol_file"
  fi

  DEPLOY_CONTRACT_PATH="$contract_file:$contract_name"
  DEPLOY_OUTPUT_FILE="$contract_name.txt"
  DEPLOY_LABEL="$contract_name"
}

resolve_target() {
  local target="$1"

  case "$target" in
    ""|nft|discord|seismic-nft)
      DEPLOY_CONTRACT_PATH="src/SeismicNFT.sol:SeismicDiscordStat"
      DEPLOY_OUTPUT_FILE="deploy.txt"
      DEPLOY_LABEL="SeismicDiscordStat"
      ;;
    seth|shielded-eth|shieldedeth)
      DEPLOY_CONTRACT_PATH="src/ShieldedETH.sol:ShieldedETH"
      DEPLOY_OUTPUT_FILE="deploy_seth.txt"
      DEPLOY_LABEL="ShieldedETH"
      if [ -z "${DEPLOY_VALUE:-}" ]; then
        DEPLOY_VALUE="10000000000000000"
      fi
      ;;
    *:*)
      DEPLOY_CONTRACT_PATH="$target"
      DEPLOY_OUTPUT_FILE="$(echo "$target" | awk -F: '{print $2}').txt"
      DEPLOY_LABEL="$(echo "$target" | awk -F: '{print $2}')"
      ;;
    *.sol)
      resolve_sol_file_target "$target"
      ;;
    *)
      echo "Unknown deploy target: $target" >&2
      echo "Use 'nft', 'seth', '<File.sol>', or '<path.sol:ContractName>'." >&2
      exit 1
      ;;
  esac
}

parse_deploy_args() {
  DEPLOY_TARGET=""
  DEPLOY_CONTRACT_NAME_OVERRIDE=""
  DEPLOY_OUTPUT_FILE=""
  DEPLOY_OUTPUT_OVERRIDE=""
  DEPLOY_VALUE="${VALUE:-}"
  DEPLOY_EXTRA_ARGS=()
  SKIP_INSTALL="${SKIP_INSTALL:-0}"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        usage
        exit 0
        ;;
      --contract|--target)
        if [ "$#" -lt 2 ]; then
          echo "$1 requires a value." >&2
          exit 1
        fi
        DEPLOY_TARGET="$2"
        shift 2
        ;;
      --file)
        if [ "$#" -lt 2 ]; then
          echo "--file requires a value." >&2
          exit 1
        fi
        DEPLOY_TARGET="$2"
        shift 2
        ;;
      --contract-name|--name)
        if [ "$#" -lt 2 ]; then
          echo "$1 requires a value." >&2
          exit 1
        fi
        DEPLOY_CONTRACT_NAME_OVERRIDE="$2"
        shift 2
        ;;
      --output)
        if [ "$#" -lt 2 ]; then
          echo "--output requires a value." >&2
          exit 1
        fi
        DEPLOY_OUTPUT_OVERRIDE="$2"
        shift 2
        ;;
      --value)
        if [ "$#" -lt 2 ]; then
          echo "--value requires a value." >&2
          exit 1
        fi
        DEPLOY_VALUE="$2"
        shift 2
        ;;
      --gas-price)
        if [ "$#" -lt 2 ]; then
          echo "--gas-price requires a value." >&2
          exit 1
        fi
        GAS_PRICE="$2"
        shift 2
        ;;
      --priority-gas-price)
        if [ "$#" -lt 2 ]; then
          echo "--priority-gas-price requires a value." >&2
          exit 1
        fi
        PRIORITY_GAS_PRICE="$2"
        shift 2
        ;;
      --nonce)
        if [ "$#" -lt 2 ]; then
          echo "--nonce requires a value." >&2
          exit 1
        fi
        NONCE="$2"
        shift 2
        ;;
      --legacy)
        LEGACY=1
        shift
        ;;
      --rpc-url)
        if [ "$#" -lt 2 ]; then
          echo "--rpc-url requires a value." >&2
          exit 1
        fi
        RPC_URL="$2"
        shift 2
        ;;
      --private-key)
        if [ "$#" -lt 2 ]; then
          echo "--private-key requires a value." >&2
          exit 1
        fi
        PRIVATE_KEY="$2"
        shift 2
        ;;
      --mnemonic)
        if [ "$#" -lt 2 ]; then
          echo "--mnemonic requires a value." >&2
          exit 1
        fi
        MNEMONIC="$2"
        shift 2
        ;;
      --no-install)
        SKIP_INSTALL=1
        shift
        ;;
      --*.sol)
        if [ -n "$DEPLOY_TARGET" ]; then
          echo "Only one deploy target can be provided." >&2
          exit 1
        fi
        DEPLOY_TARGET="${1#--}"
        shift
        ;;
      --)
        shift
        while [ "$#" -gt 0 ]; do
          DEPLOY_EXTRA_ARGS+=("$1")
          shift
        done
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        if [ -n "$DEPLOY_TARGET" ]; then
          echo "Only one deploy target can be provided." >&2
          exit 1
        fi
        DEPLOY_TARGET="$1"
        shift
        ;;
    esac
  done

  resolve_target "$DEPLOY_TARGET"
  if [ -n "$DEPLOY_OUTPUT_OVERRIDE" ]; then
    DEPLOY_OUTPUT_FILE="$DEPLOY_OUTPUT_OVERRIDE"
  fi
}

ensure_contract_dependencies() {
  if ! command -v sforge >/dev/null 2>&1; then
    echo "Missing sforge. Install Seismic's Foundry toolchain first." >&2
    echo "Docs: https://docs.seismic.systems/appendix/deployments" >&2
    exit 1
  fi

  if [ "${SKIP_INSTALL:-0}" = "1" ]; then
    return
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

  if [ -n "${DEPLOY_VALUE:-}" ]; then
    TX_ARGS+=(--value "$DEPLOY_VALUE")
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

  echo "Target: $contract_path"
  echo "RPC: $RPC_URL"
  if [ -n "${DEPLOY_VALUE:-}" ]; then
    echo "Value: $DEPLOY_VALUE wei"
  fi

  set +e
  deploy_output=$(sforge create \
    --rpc-url "$RPC_URL" \
    "${WALLET_ARGS[@]}" \
    "${TX_ARGS[@]}" \
    --broadcast \
    "$contract_path" \
    "$@" 2>&1)
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
  2. Rerun with a higher gas price:
       bash deploy.sh nft --legacy --gas-price 10000000000
  3. If you know the correct next nonce, set both nonce and gas price:
       bash deploy.sh nft --legacy --nonce <next_nonce> --gas-price 10000000000
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
  "contractLink": "$contract_link",
  "outputFile": "packages/contract/out/$output_file"
}
EOF
}

run_deploy_cli() {
  parse_deploy_args "$@"

  cd "$ROOT_DIR/packages/contract"
  ensure_contract_dependencies

  contract_source="${DEPLOY_CONTRACT_PATH%%:*}"
  if [ ! -f "$contract_source" ]; then
    echo "Contract file not found: packages/contract/$contract_source" >&2
    exit 1
  fi

  echo "Deploying $DEPLOY_LABEL..."
  deploy_contract "$DEPLOY_CONTRACT_PATH" "$DEPLOY_OUTPUT_FILE" "${DEPLOY_EXTRA_ARGS[@]}"
}
