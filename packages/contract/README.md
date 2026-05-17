# Deploy an encrypted contract in <1m

> Assumes you've completed the installation steps in the [developer testnet guide](https://docs.seismic.systems/appendix/deployments).

Create `.env` in the repository root:

```bash
RPC_URL=https://gcp-1.seismictest.net/rpc
EXPLORER_URL=https://seismic-testnet.socialscan.io
MNEMONIC="your twelve or twenty four words"
# or:
# PRIVATE_KEY=0x...
```

Run this from `packages/contract/`:

```
bash script/deploy.sh
```

Deploy the sETH contract:

```
bash script/deploy_seth.sh
```

If the RPC returns `replacement transaction underpriced`, the deployer wallet
already has a pending transaction for the same nonce. Wait for it to mine, use a
fresh funded wallet, or rerun with a higher gas price:

```bash
GAS_PRICE=2000000000 bash script/deploy.sh
```

Done!
