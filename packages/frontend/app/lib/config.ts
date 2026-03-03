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
    "0x92ee987ef74248a8b1e9e61d9339bd085f653ae9" as const;
