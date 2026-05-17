import { defineChain } from "viem";

const rpcUrl = process.env.NEXT_PUBLIC_RPC_URL;
const wsUrl = process.env.NEXT_PUBLIC_WS_URL;
const explorerUrl =
    process.env.NEXT_PUBLIC_EXPLORER_URL || "https://seismic-testnet.socialscan.io";

if (!rpcUrl) {
    throw new Error("Missing NEXT_PUBLIC_RPC_URL in frontend environment");
}

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
            http: [rpcUrl],
            ...(wsUrl ? { webSocket: [wsUrl] } : {}),
        },
    },
    blockExplorers: {
        default: {
            name: "SocialScan",
            url: explorerUrl,
        },
    },
});

// Replace with your deployed contract address
export const CONTRACT_ADDRESS =
    "0x143bf3d6f430c1c993e296a424a551eb29b6e4a5" as const;

// Replace with your deployed ShieldedETH contract address
export const SETH_CONTRACT_ADDRESS =
    "0xA13f86F2BB3396ABF45a66527494EA8A793dFcEf" as const;
