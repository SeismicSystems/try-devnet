# Seismic Deployer Toolkit

Ready-to-use tooling to compile and deploy Solidity contracts to the Seismic Testnet from the project root.

The network is configured via `.env`. The default template uses the Seismic Testnet:

- Chain ID: `5124`
- RPC: set in `RPC_URL` and `NEXT_PUBLIC_RPC_URL`
- Explorer: `https://seismic-testnet.socialscan.io`
- Faucet: `https://faucet.seismictest.net/`

## 1. Install Seismic Toolchain

On your VPS or local machine, install the Seismic toolchain:

```bash
curl https://sh.rustup.rs -sSf | sh
source ~/.bashrc

curl -L \
  -H "Accept: application/vnd.github.v3.raw" \
  "https://api.github.com/repos/SeismicSystems/seismic-foundry/contents/sfoundryup/install?ref=seismic" | bash
source ~/.bashrc

sfoundryup
source ~/.bashrc
```

Verify the installation:

```bash
sforge --version
ssolc --version
```

## 2. Project Setup

Clone the repository and navigate to the project root:

```bash
git clone https://github.com/rizkygm23/try-devnet
cd try-devnet
```

Create an `.env` file from the template:

```bash
cp .env.example .env
nano .env
```

The `.env` file at the root is used by both the deployment scripts and the frontend. The frontend reads public `NEXT_PUBLIC_*` variables from this same file.

Provide your wallet credentials:

```bash
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

Or use a mnemonic phrase:

```bash
MNEMONIC="your twelve or twenty four words"
```

Ensure the RPC URL is correctly set in `.env`:

```bash
RPC_URL=https://testnet-1.seismictest.net/rpc
NEXT_PUBLIC_RPC_URL=https://testnet-1.seismictest.net/rpc
NEXT_PUBLIC_WS_URL=wss://testnet-1.seismictest.net/ws
```

Fund your deployer wallet using the faucet:

```bash
https://faucet.seismictest.net/
```

## 3. Deploying From the Project Root

Deploy the default NFT contract:

```bash
bash deploy.sh nft
```

Deploy the ShieldedETH (sETH) contract with an initial liquidity of `0.01 ETH`:

```bash
bash deploy.sh seth
```

Deploy the included simple Counter example:

```bash
bash deploy.sh --Counter.sol
```

Deploy any custom contract located in `packages/contract/src`:

```bash
bash deploy.sh --MyContract.sol
```

The command above looks for `packages/contract/src/MyContract.sol` and deploys the `MyContract` contract.

The `.sol` extension can be omitted:

```bash
bash deploy.sh --MyContract
```

If the file contains exactly one deployable `contract`, the script auto-detects the contract name. For example, this deploys the `SeismicDiscordStat` contract from `SeismicNFT.sol`:

```bash
bash deploy.sh --SeismicNFT
```

If the file name and the contract name differ:

```bash
bash deploy.sh --file MyFile.sol --contract-name MyContract
```

Standard Foundry-style targeting is also supported:

```bash
bash deploy.sh src/MyContract.sol:MyContract
```

Deploy a contract with constructor arguments:

```bash
bash deploy.sh --MyContract.sol -- --constructor-args arg1 arg2
```

Deploy with native value:

```bash
bash deploy.sh --PayableContract.sol --value 10000000000000000
```

Workflow for adding and deploying a new contract:

```bash
nano packages/contract/src/MyToken.sol
bash deploy.sh --MyToken.sol
```

Included `Counter.sol` example:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Counter {
    suint256 private number;

    function setNumber(suint256 newNumber) external {
        number = newNumber;
    }

    function increment() external {
        number = number + suint256(1);
    }

    function getNumber() external view returns (uint256) {
        return uint256(number);
    }
}
```

## 4. Contract Address Outputs

Upon successful deployment, the contract address is saved in:

```bash
packages/contract/out/<ContractName>.txt
```

Built-in shortcuts:

```bash
cat packages/contract/out/deploy.txt
cat packages/contract/out/deploy_seth.txt
```

Update the frontend configuration if necessary:

```ts
// packages/frontend/app/lib/config.ts
export const CONTRACT_ADDRESS = "0x..." as const;
export const SETH_CONTRACT_ADDRESS = "0x..." as const;
```

## 5. Command Options

View all available options:

```bash
bash deploy.sh --help
```

Frequently used options:

```bash
bash deploy.sh nft --legacy --gas-price 10000000000
bash deploy.sh nft --nonce 12 --legacy --gas-price 10000000000
bash deploy.sh seth --output my-seth.txt
bash deploy.sh --Counter.sol
bash deploy.sh --SeismicNFT
bash deploy.sh --My.sol --rpc-url "$RPC_URL"
bash deploy.sh --file MyFile.sol --contract-name MyContract
```

Legacy deployment scripts can still be used, acting as wrappers:

```bash
bash packages/contract/script/deploy.sh
bash packages/contract/script/deploy_seth.sh
```

## 6. Troubleshooting

`replacement transaction underpriced`

The deployer wallet has a pending transaction with the same nonce. Increase the gas price:

```bash
bash deploy.sh nft --legacy --gas-price 10000000000
```

If you know the exact nonce:

```bash
bash deploy.sh nft --legacy --nonce <next_nonce> --gas-price 10000000000
```

Alternative solutions: Wait for the pending transaction to be mined, or switch to a new funded deployer wallet.

`Missing sforge`

The Seismic toolchain is not installed, or your shell environment hasn't been reloaded:

```bash
sfoundryup
source ~/.bashrc
```

`Missing wallet credentials`

Add your credentials to the `.env` file using one of the following:

```bash
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
MNEMONIC="your twelve or twenty four words"
```

`Missing RPC_URL in .env`

Set the deployment RPC in `.env`:

```bash
RPC_URL=https://testnet-1.seismictest.net/rpc
```

For the frontend, also set the public environment variables:

```bash
NEXT_PUBLIC_RPC_URL=https://testnet-1.seismictest.net/rpc
NEXT_PUBLIC_WS_URL=wss://testnet-1.seismictest.net/ws
```

`forge-std` or `@openzeppelin` not found

Rerun the deployment command. The script will automatically install missing dependencies. If the `lib/forge-std` directory exists but is corrupted:

```bash
rm -rf packages/contract/lib/forge-std
bash deploy.sh nft
```

## References

- Seismic Installation: https://docs.seismic.systems/getting-started/installation
- Seismic Testnet: https://docs.seismic.systems/networks/testnet
