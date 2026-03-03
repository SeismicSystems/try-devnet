"use client";

import { getDefaultConfig, RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { ShieldedWalletProvider } from "seismic-react";
import { seismicTestnet } from "seismic-react/rainbowkit";

export const config = getDefaultConfig({
    appName: "Seismic Discord Stat NFT",
    projectId: "YOUR_PROJECT_ID", // It's fine for local testing
    chains: [seismicTestnet],
    ssr: true,
});

const client = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={client}>
                <RainbowKitProvider
                    theme={darkTheme({
                        accentColor: "#6c63ff",
                        accentColorForeground: "white",
                        borderRadius: "large",
                    })}
                >
                    <ShieldedWalletProvider config={config as any}>
                        {children}
                    </ShieldedWalletProvider>
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
}
