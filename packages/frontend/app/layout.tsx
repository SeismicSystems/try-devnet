import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Seismic Discord Stat — Shielded NFT Viewer",
  description:
    "View your encrypted Discord stat traits. Only NFT owners can decrypt and see their shielded on-chain data.",
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
