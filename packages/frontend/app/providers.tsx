"use client";

import { useMemo, useRef } from "react";
import { getDefaultConfig, RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { ShieldedWalletProvider } from "seismic-react";
import { seismicTestnet } from "seismic-react/rainbowkit";

// Singleton: create config only once across hot reloads
let _config: ReturnType<typeof getDefaultConfig> | null = null;
function getConfig() {
    if (!_config) {
        _config = getDefaultConfig({
            appName: "Seismic Discord Stat NFT",
            projectId: "YOUR_PROJECT_ID",
            chains: [seismicTestnet],
            ssr: true,
        });
    }
    return _config;
}

export const config = getConfig();

export function Providers({ children }: { children: React.ReactNode }) {
    const queryClientRef = useRef<QueryClient | null>(null);
    if (!queryClientRef.current) {
        queryClientRef.current = new QueryClient();
    }

    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={queryClientRef.current}>
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
