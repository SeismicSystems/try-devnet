import { defineChain } from "viem";

export const seismicTestnet = defineChain({
    id: 5124,
    name: "Seismic Testnet",
    nativeCurrency: {
        name: "Ether",
        symbol: "ETH",
        decimals: 18,
    },
    rpcUrls: {
        default: {
            http: ["https://gcp-2.seismictest.net/rpc"],
            webSocket: ["wss://gcp-2.seismictest.net/ws"],
        },
    },
    blockExplorers: {
        default: {
            name: "SocialScan",
            url: "https://seismic-testnet.socialscan.io",
        },
    },
});

// Replace with your deployed contract address
export const CONTRACT_ADDRESS =
    "0x143bf3d6f430c1c993e296a424a551eb29b6e4a5" as const;

// Replace with your deployed ShieldedETH contract address
export const SETH_CONTRACT_ADDRESS =
    "0x0000000000000000000000000000000000000000" as const;
