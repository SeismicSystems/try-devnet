# Implementasi Wallet Connect yang Lancar Tanpa Error (NaN)

Dokumen ini menjelaskan mengapa integrasi Wallet Connect di *project* kita berjalan sangat lancar, bisa membaca *balance* (saldo) spesifik termasuk ETH/chain token dengan presisi penuh tanpa menghadapi error `NaN`, dan komponen apa saja yang membentuk tumpukan teknologi ini.

## Tumpukan Teknologi (Tech Stack) yang Digunakan

Tidak seperti cara lama yang perlu mengatur *provider* secara manual (`web3.js` atau murni `ethers.js`), di aplikasi *frontend* modern, kita menggunakan serangkaian *library* bawaan ekosistem React Web3 terbaru:

| Library | Fungsi Utama |
| :--- | :--- |
| **`wagmi`** | Kumpulan *React Hooks* untuk jaringan EVM. Menyempurnakan manajemen *state* saat dompet terputus, sinkronisasi *block*, dan permintaan data tanpa me-render ulang (*re-render*) jika tidak perlu. |
| **`viem`** | Modul berukuran sangat kecil penyedia API tingkat rendah yang menggeser *ethers.js*. Keunggulan utamanya ada di ketelitian TypeScript dan penanganan nilai `BigInt` (menghindari error presisi seperti `NaN` atau kehilangan angka desimal). |
| **`@rainbow-me/rainbowkit`** | Menyusun antarmuka visual (UI) *Connect Wallet* yang keren, responsif, modern, dan memberikan kebebasan kustomisasi (*dark/light theme*). |
| **`seismic-react`** | Pembungkus khusus (Wrapper) untuk jaringan atau environment **Seismic** dan fitur dompet *shielded*. |
| **`@tanstack/react-query`** | Di balik layar `wagmi`, modul ini menangani *caching* permintaan asinkron ke RPC. Kalau ada masalah jaringan sesaat, ia akan segera memulihkan kembali antrian tanpa membuat aplikasi *crash*. |

## Mengapa "Agent" Anda Sebelumnya Mendapatkan `NaN`?

1. **Kasus Tipe Data BigInt:** *Balance* mata uang kripto punya presisi tinggi (18 angka desimal). Nilai yang turun dari blockchain biasanya format *hex* besar yang ketika dibaca menggunakan format Javascript bawaan `Number` sangat rentan menjadi kelebihan muatan (*overflow*) atau gagal diterjemahkan sehingga mereturn `NaN`. **Solusi di sini:** `wagmi` dan `viem` secara tegas menangani saldo menggunakan objek Native `BigInt` dan format *string* seperti `formatEther`.
2. **Kondisi React Hydration & Loading:** Tanpa *hooks* yang mumpuni, *state loading* sering diabaikan. Jika antarmuka belum mendapat balikan nilai dari *nodes*, ia memaksa untuk membaca *value* kosong/`undefined` sehingga saat dikalkulasi, kembaliannya adalah `NaN`. React Query (di belakang `wagmi`) secara pintar selalu memberikan status `isLoading: true` hingga datanya benar-benar siap.


---

## Bagaimana Cara Menerapkannya (Langkah-langkah Penulisan)

Jika agent di proyek lain ingin merakit alur koneksi Wallet dari *scratch*, berikut adalah rujukan penerapan standar aplikasi kita menggunakan kerangka Next.js (App Router).

### 1. Inisialisasi Provider di `providers.tsx`

Untuk memberikan akses ke seluruh komponen agar bisa saling "melihat" dompet pengguna, kita pasang perlengkapan React-nya di Root aplikasi (`app/providers.tsx`):

```tsx
"use client";

import { getDefaultConfig, RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { ShieldedWalletProvider } from "seismic-react";
import { seismicTestnet } from "seismic-react/rainbowkit";

// 1. Definisikan Config Wagmi & Jaringan
export const config = getDefaultConfig({
    appName: "Seismic Discord Stat NFT",
    projectId: "YOUR_PROJECT_ID", // WalletConnect Project ID (Bisa didapat di cloud.walletconnect.com)
    chains: [seismicTestnet],     // Definisikan jaringan yang didukung
    ssr: true,                    // Mengatasi error Hydration next.js server-side rendering
});

const client = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={client}>
                {/* 2. Theme Rainbowkit sesuka hati */}
                <RainbowKitProvider
                    theme={darkTheme({
                        accentColor: "#6c63ff",
                        accentColorForeground: "white",
                        borderRadius: "large",
                    })}
                >
                    {/* 3. Pembungkus Spesifik Seismic */}
                    <ShieldedWalletProvider config={config as any}>
                        {children}
                    </ShieldedWalletProvider>
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
}
```

### 2. Membaca Saldo ETH dengan Aman (Tanpa `NaN`)

Untuk membaca saldo yang dimiliki oleh dompet mana pun, aplikasikan Hook `useBalance`. Wagmi akan selalu mengembalikan objek `data` yang mana di dalamnya sudah terdapat saldo yang diformat.

```tsx
"use client";

import { useAccount, useBalance } from 'wagmi';

export function WalletInfo() {
  const { address, isConnected } = useAccount();

  // Ini bagian vital yang menghindari NaN: gunakan useBalance dari wagmi
  const { data: balanceData, isLoading } = useBalance({
    address: address, // Mem-fetch berdasarkan Address Connect
  });

  if (!isConnected) return <div>Silakan hubungkan dompet.</div>;

  return (
    <div>
      <p>Address: {address}</p>
      {isLoading ? (
        <p>Sedang memuat saldo...</p>
      ) : (
        {/* data.formatted adalah string angka valid yang aman ditampilkan ke layar - bukan BigInt mentahan */}
        <p>Saldo: {balanceData?.formatted} {balanceData?.symbol}</p>
      )}
    </div>
  );
}
```

### 3. Menggunakan Tombol Connect Bawaan
Untuk menampilkan tombol *Connect* modern, kamu tidak butuh membangun satu per satu UI-nya, cukup panggil tombol bawaan RainbowKit yang sangat adaptif.

```tsx
import { ConnectButton } from '@rainbow-me/rainbowkit';

export default function Header() {
    return (
        <header>
            <h1>My Web3 App</h1>
            <ConnectButton />
        </header>
    )
}
```

## Kesimpulan

Sistem berjalan jauh lebih mulus karena tidak meraba-raba blockchain *node* secara asinkron tradisional. Dengan menumpuk **Viem** (untuk konversi BigInt tipe yang teliti), **TanStack React-Query** (untuk asinkron statenya), serta kumpulan **Wagmi** + **RainbowKit**, segala konvensi rumit dalam membaca `Contract` maupun `Balance` telah tertangani di luar memori utama UI. Karena itulah balance kamu tidak pernah terlempar jatuh menjadi nilai yang tidak valid (*NaN*).
