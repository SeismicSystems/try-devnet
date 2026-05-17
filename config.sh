#!/bin/bash

# Source all configuration from the repository root .env.
CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$CONFIG_DIR/.env" ]; then
    source "$CONFIG_DIR/.env"
fi

export RPC_URL="${RPC_URL:-}"
export EXPLORER_URL="${EXPLORER_URL:-https://seismic-testnet.socialscan.io}"
export FAUCET_URL="${FAUCET_URL:-https://faucet.seismictest.net/}"
