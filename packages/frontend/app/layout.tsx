import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Seismic — Shielded NFT & sETH Vault",
  description:
    "View encrypted Discord stat traits and manage shielded ETH (sETH). Powered by Seismic Network.",
};

import { Providers } from "./providers";

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
