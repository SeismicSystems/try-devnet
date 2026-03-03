# Panduan Integrasi Mint NFT pada Aplikasi Frontend (Seismic)

Dokumen ini adalah panduan lengkap *step-by-step* untuk agen AI yang ingin mengintegrasikan fitur minting `SeismicDiscordStat` NFT ke dalam website lain berbasis React/Next.js menggunakan protokol **Seismic**.

## Prasyarat Penggunaan
1. **Contract Address**: Pastikan kamu menggunakan Address Smart Contract NFT yang sudah di-deploy pada Seismic Devnet/Testnet. Saat ini berada di:
   `0xed925B16561d3E619dc3433Ea6e47A760d2EC657`
2. **Open Minting (Siapa Saja Boleh Mint)**: Fungsi `mint` pada smart contract **tidak** memiliki modifier `onlyOwner`. Setiap wallet yang terkoneksi bisa memanggil `mint`. Namun, **setiap address hanya boleh memiliki 1 NFT**. Jika user mint untuk kedua kalinya, NFT lama akan otomatis di-*burn* dan NFT baru akan di-mint.
3. **Pinata Credentials**: Kamu memerlukan kredensial dari layanan IPFS [Pinata](https://pinata.cloud/) untuk mengunggah gambar dan metadata (`pinataApiKey`, `pinataSecretApiKey`, atau `JWT`). Fitur mint membutuhkan sebuah argumen berupa string URL Metadata (URI).
4. **Instalasi Dependencies**: Jika proyek frontend belum menginstall librari untuk Seismic dan Web3, jalankan perintah ini:
   ```bash
   npm install viem wagmi @rainbow-me/rainbowkit @tanstack/react-query seismic-react axios form-data
   ```

---

## Langkah 1: Kredensial Environment (.env)

Buat file `.env.local` di folder *root* proyek website agar kredensial IPFS aman dan pastikan Next.js / framework memuat env vars ini. Jika mint dilakukan di *Client Side*, kamu harus melakukan upload via *API Route* atau mengekspos API key. Disarankan mengekspos route NEXT_PUBLIC API key **hanya untuk mode development**. Praktik terbaik adalah mengunggah via Backend Server / Route Handler.

```env
# .env.local
NEXT_PUBLIC_PINATA_API_KEY="API_KEY_PINATA_KAMU"
NEXT_PUBLIC_PINATA_SECRET_API_KEY="SECRET_API_KEY_PINATA_KAMU"
# Atau bisa gunakan JWT
# PINATA_JWT="ey..." 
```

---

## Langkah 2: Konfigurasi Provider dan Network

Aplikasi frontend harus dikonfigurasi dengan Wagmi, RainbowKit, dan dibungkus dengan `ShieldedWalletProvider` milik Seismic agar secara otomatis mengenkripsi parameter berupa `suint256`.

Buat atau perbarui file `providers.tsx`:

```tsx
"use client";

import { getDefaultConfig, RainbowKitProvider, darkTheme } from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { WagmiProvider } from "wagmi";
import { ShieldedWalletProvider } from "seismic-react";
import { seismicTestnet } from "seismic-react/rainbowkit";
import "@rainbow-me/rainbowkit/styles.css";

const config = getDefaultConfig({
    appName: "Website DApp Kamu",
    projectId: "YOUR_PROJECT_ID", // Masukkan ID project WalletConnect kamu jika ada
    chains: [seismicTestnet],
    ssr: true,
});

const client = new QueryClient();

export function Providers({ children }: { children: React.ReactNode }) {
    return (
        <WagmiProvider config={config}>
            <QueryClientProvider client={client}>
                <RainbowKitProvider theme={darkTheme()}>
                    {/* ShieldedWalletProvider PENTING: Untuk mengenkripsi tipe suint256 */}
                    <ShieldedWalletProvider config={config as any}>
                        {children}
                    </ShieldedWalletProvider>
                </RainbowKitProvider>
            </QueryClientProvider>
        </WagmiProvider>
    );
}
```

---

## Langkah 3: Siapkan ABI Contract

Salin bagian fungsi `mint` dari ABI ke sebuah berkas konstanta (misal `lib/abi.ts`):

```typescript
// lib/abi.ts
export const SEISMIC_DISCORD_STAT_ABI = [
  {
    inputs: [
      { name: "uri", type: "string" },
      { name: "art", type: "suint256" },
      { name: "tweet", type: "suint256" },
      { name: "chat", type: "suint256" },
      { name: "role", type: "suint256" },
    ],
    name: "mint",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  // ... fungsi ownerOf, tokenURI, getStats lainnya
] as const;
```

---

## Langkah 4: Fungsi Upload ke Pinata

Kita butuh *helper function* untuk mengunggah Metadata JSON ke Pinata. Ini dilakukan sebelum fungsi eksekusi *Smart Contract* berjalan. 

```typescript
// lib/pinata.ts
import axios from 'axios';

export const uploadMetadataToIPFS = async (metadataInfo: object) => {
    const url = `https://api.pinata.cloud/pinning/pinJSONToIPFS`;

    try {
        const response = await axios.post(
            url,
            metadataInfo,
            {
                headers: {
                    'Content-Type': 'application/json',
                    pinata_api_key: process.env.NEXT_PUBLIC_PINATA_API_KEY,
                    pinata_secret_api_key: process.env.NEXT_PUBLIC_PINATA_SECRET_API_KEY,
                },
            }
        );

        return `https://gateway.pinata.cloud/ipfs/${response.data.IpfsHash}`;
    } catch (error) {
        console.error("Error uploading metadata ke Pinata:", error);
        throw error;
    }
};
```
_Catatan: Penggunaan `NEXT_PUBLIC` berarti kredensialmu akan terekspos ke klien. Jika sedang di Production / Production-ready, disarankan menaruh fungsi pemanggilan ini dalam API Route Next.js lalu kamu dapat menembak endpoint lokal seperti `/api/upload` tanpa Prefix `NEXT_PUBLIC` di file `.env`._

---

## Langkah 5: Komponen MintForm dengan `useShieldedWriteContract`

Hal yang paling esensial dalam Seismic: Karena argumen fungsi mint (`art`, `tweet`, `chat`, `role`) adalah **`suint256` (Shielded Value)**, kita _tidak boleh_ menggunakan `useWriteContract` standar dari `wagmi`. 

Sebagai gantinya, gunakan `useShieldedWriteContract` yang di-export dari `seismic-react`.

Buat sebuah komponen React untuk UI Mint (`components/MintForm.tsx` atau sejenisnya):

```tsx
"use client";

import { useState } from "react";
import { useShieldedWriteContract } from "seismic-react";
import { SEISMIC_DISCORD_STAT_ABI } from "../lib/abi";
import { uploadMetadataToIPFS } from "../lib/pinata";

export const CONTRACT_ADDRESS = "0xed925B16561d3E619dc3433Ea6e47A760d2EC657";

export default function MintForm() {
  const [stats, setStats] = useState({ art: 0, tweet: 0, chat: 0, role: 1 });
  
  // Status Upload Pinata
  const [isUploading, setIsUploading] = useState(false);

  // Panggil hook Seismic
  const { writeContract, isLoading, error, hash } = useShieldedWriteContract({
    address: CONTRACT_ADDRESS,
    abi: SEISMIC_DISCORD_STAT_ABI,
    functionName: "mint",
  });

  const handleMint = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      setIsUploading(true);
      
      // 1. Persiapkan struktur metadata ERC721
      const metadataTemplate = {
         name: "Seismic Discord Stat",
         description: "Encrypted Shielded NFT representing a user's Discord statistics on Seismic Network",
         // Kamu juga bisa mengunggah image/video ke IPFS dan menempatkan URL nya ke mari
         // image: "ipfs://Qm..." 
      };

      // 2. Unggah Metadata ke Pinata
      const tokenURI = await uploadMetadataToIPFS(metadataTemplate);
      setIsUploading(false);

      // 3. Eksekusi fungsi Smart Contract
      //    Tidak perlu parameter `to` — contract otomatis mint ke msg.sender.
      //    Jika user sudah punya NFT sebelumnya, contract akan burn otomatis.
      await writeContract({
        address: CONTRACT_ADDRESS,
        abi: SEISMIC_DISCORD_STAT_ABI,
        functionName: "mint",
        args: [
          tokenURI,             // URI yang baru saja dibuat
          BigInt(stats.art),    // Argumen suint256 akan otomatis dienkripsi sebelum broadcast
          BigInt(stats.tweet),
          BigInt(stats.chat),
          BigInt(stats.role)
        ],
      });
      // Proses mint jalan. Nilai state suint256 telah dienkripsi on-chain!
      // Jika user sudah punya NFT lama, NFT lama sudah otomatis di-burn.

    } catch (err) {
      setIsUploading(false);
      console.error("Gagal melakukan mint", err);
    }
  };

  const isMinting = isLoading || isUploading;

  return (
    <div className="mint-container">
      <h2>Mint NFT dengan Data Rahasia</h2>
      <p style={{ fontSize: "0.9em", color: "#888" }}>
        NFT akan di-mint ke wallet kamu yang sedang terkoneksi.
        Jika kamu sudah memiliki NFT, NFT lama akan otomatis di-burn.
      </p>
      <form onSubmit={handleMint}>
          <div>
            <label>Art Count:</label>
            <input type="number" value={stats.art} onChange={e => setStats({...stats, art: parseInt(e.target.value)})} />
          </div>
          <div>
            <label>Tweet Count:</label>
            <input type="number" value={stats.tweet} onChange={e => setStats({...stats, tweet: parseInt(e.target.value)})} />
          </div>
          <div>
            <label>Chat Count:</label>
            <input type="number" value={stats.chat} onChange={e => setStats({...stats, chat: parseInt(e.target.value)})} />
          </div>
          <div>
            <label>Highest Role:</label>
            <input type="number" value={stats.role} onChange={e => setStats({...stats, role: parseInt(e.target.value)})} min="1" max="6" />
          </div>
          
          <button type="submit" disabled={isMinting}>
            {isMinting ? "Processing Transaction..." : "Mint Shielded NFT"}
          </button>
      </form>

      {hash && <p>Transaction Hash: {hash}</p>}
      {error && <p style={{ color: "red" }}>Error: {error.message}</p>}
    </div>
  );
}
```

---

## Poin Penting untuk AI Agent
- **Setup Pinata**: Wajib mengunggah berkas JSON metadata ke _decentralized storage_ Pinata agar _Token URI_ tidak diset sembarangan, pastikan agen paham bahwa kredensial Pinata (API Key + Secret) dimasukkan ke variabel lingkungan.
- **Contract Address Terverifikasi**: Alamat `0xed925B16561d3E619dc3433Ea6e47A760d2EC657` adalah instance `SeismicDiscordStat` yang resmi pada direktori saat ini. **Catatan: Setelah perubahan contract, kamu perlu re-deploy dan update alamat ini.**
- **Katakan Tidak pada `useWriteContract`**: Ketika ABI mengandung tipe data `suint256` dsb, JANGAN PERNAH gunakan `wagmi` standar langsung karena akan _revert_ di level chain. Selalu impor `useShieldedWriteContract` dari `seismic-react`.
- **Parsing Data**: Meskipun parameter di contract berbunyi `suint256`, dari kacamata antarmuka Typescript kamu cukup passing tipe `BigInt` reguler. `seismic-react` / `seismic-viem` akan membaca tipe tersebut dari ABI dan mengaplikasikan enkripsinya diam-diam menggunakan **ShieldedWalletProvider** sebelum menembakkannya ke RPC node.
- **Open Minting & Auto-Burn**: Siapa saja boleh mint. Tidak ada batasan `onlyOwner`. Namun setiap address hanya boleh punya 1 NFT. Jika user mint lagi, NFT lama otomatis di-burn. Tidak perlu ada parameter `to` pada `args` — contract menggunakan `msg.sender` secara langsung.
- **Tidak Ada Parameter `to`**: Signature fungsi `mint` sudah **tidak** memiliki parameter `address to`. NFT selalu di-mint ke `msg.sender` (wallet yang sedang terkoneksi).
