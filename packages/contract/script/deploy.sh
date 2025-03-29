#!/bin/bash

set -e

source ../../config.sh
source ../common/print.sh
source ../common/wallet.sh

CONTRACT_PATH="src/Counter.sol:Counter"
DEPLOY_FILE="out/deploy.txt"

check_dependencies() {
    echo -e "${BLUE}Checking system dependencies...${NC}"

    missing_libs=()

    for lib in "GLIBC_2.34" "GLIBC_2.32" "GLIBC_2.33" "CXXABI_1.3.13" "GLIBCXX_3.4.29"; do
        if ! strings /lib/x86_64-linux-gnu/libc.so.6 | grep -q "$lib" && \
           ! strings /usr/lib/x86_64-linux-gnu/libstdc++.so.6 | grep -q "$lib"; then
            missing_libs+=("$lib")
        fi
    done

    if [ ${#missing_libs[@]} -ne 0 ]; then
        echo -e "${RED}Missing or outdated dependencies detected:${NC}"
        for lib in "${missing_libs[@]}"; do
            echo -e "${RED}- $lib${NC}"
        done
        echo -e "${RED}Please update your system libraries before proceeding.${NC}"
        exit 1
    else
        echo -e "${GREEN}All dependencies are satisfied.${NC}"
    fi
}

prelude() {
    echo -e "${BLUE}Deploy an encrypted contract in <1m.${NC}"
    echo -e "It's a Counter contract that only reveals the counter once it's >=5."
    echo -ne "Press Enter to continue..."
    read -r
}

check_dependencies
prelude

dev_wallet
address=$DEV_WALLET_ADDRESS
privkey=$DEV_WALLET_PRIVKEY

print_step "4" "Deploying contract"
deploy_output=$(sforge create \
    --rpc-url "$RPC_URL" \
    --private-key "$privkey" \
    --broadcast \
    "$CONTRACT_PATH" \
    --constructor-args 5)
print_success "Success."

print_step "5" "Summarizing deployment"
contract_address=$(echo "$deploy_output" | grep "Deployed to:" | awk '{print $3}')
tx_hash=$(echo "$deploy_output" | grep "Transaction hash:" | awk '{print $3}')
echo "$contract_address" >"$DEPLOY_FILE"
echo -e "Contract Address: ${GREEN}$contract_address${NC}"
echo -e "Contract Link: ${GREEN}$EXPLORER_URL/address/$contract_address${NC}"

echo -e "\n"
print_success "Success. You just deployed your first contract on Seismic!"
