#!/bin/bash

# DEVNET ONLY
# Do NOT use this wallet generation in production

dev_wallet() {
    if ! command -v cast >/dev/null 2>&1; then
        echo "Error: cast not found. Install Foundry first." >&2
        exit 1
    fi

    local keypair_json
    keypair_json=$(cast wallet new --json)

    # cast returns ARRAY, not object
    DEV_WALLET_ADDRESS=$(echo "$keypair_json" | jq -r '.[0].address')
    # Try both privateKey (camelCase) and private_key (snake_case)
    DEV_WALLET_PRIVKEY=$(echo "$keypair_json" | jq -r '.[0].privateKey // .[0].private_key')

    if [ -z "$DEV_WALLET_ADDRESS" ] || [ "$DEV_WALLET_ADDRESS" = "null" ]; then
        echo "Error: Failed to extract wallet address." >&2
        echo "Debug: cast output: $keypair_json" >&2
        exit 1
    fi

    if [ -z "$DEV_WALLET_PRIVKEY" ] || [ "$DEV_WALLET_PRIVKEY" = "null" ]; then
        echo "Error: Failed to extract private key." >&2
        echo "Debug: cast output: $keypair_json" >&2
        exit 1
    fi
}
