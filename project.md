# 🛡️ Shielded ETH (sETH) - Privacy Layer for ETH

## 📖 Overview
Shielded ETH (sETH) adalah aplikasi dApp berbasis privasi yang dibangun di atas **Seismic Network**. Aplikasi ini memungkinkan pengguna untuk mengubah ETH publik mereka menjadi sETH privat (Shielded). sETH menggunakan standar **SRC-20** dengan tipe data **suint256** (Shielded Integer) yang menjamin saldo dan jumlah transaksi tetap terenkripsi secara on-chain.

## 🚀 Fitur Utama (Route: `/seth`)

### 1. **Deposit (ETH → sETH)**
*   Mengonversi Native ETH menjadi Shielded ETH dengan rasio 1:1.
*   Dana yang masuk dikunci dalam smart contract, dan jumlah sETH yang setara dicetak ke saldo rahasia pengguna.
*   Mendukung fitur persentase (25%, 50%, Max) untuk kemudahan input.

### 2. **Encrypted Balance Display**
*   Saldo sETH **terenkripsi secara on-chain**. Pihak luar tidak bisa mengintip saldo Anda melalui Block Explorer.
*   Fitur **"Sign to Reveal"**: Pengguna harus memberikan tanda tangan digital (via TEE viewing key) untuk mendekripsi dan melihat saldo mereka sendiri di antarmuka web.

### 3. **Shielded Transfer**
*   Memungkinkan pengiriman sETH antar wallet.
*   **Privasi Total**: Jumlah (amount) yang ditransfer sepenuhnya tersembunyi. Explorer hanya akan mencatat bahwa telah terjadi transfer, namun nominalnya tetap rahasia.

### 4. **Redeem (sETH → ETH)**
*   Mekanisme *Two-way Peg*: Mengonversi kembali sETH menjadi Native ETH kapan saja.
*   **Flexible Withdrawal**: Pengguna dapat melakukan redeem ke alamat wallet mana pun, memberikan lapisan privasi tambahan saat menarik dana keluar dari sistem shielded.

## 🛠️ Tech Stack
*   **Framework**: Next.js (App Router)
*   **Blockchain**: Seismic Testnet (Privacy-first L2)
*   **Libraries**: 
    *   `wagmi` & `viem`: Standar industri untuk koneksi blockchain.
    *   `seismic-react` & `seismic-viem`: SDK khusus untuk interaksi dengan shielded state dan TEE (Trusted Execution Environment) milik Seismic.
    *   `RainbowKit`: Antarmuka koneksi dompet yang modern.
*   **Contract Interface**: SRC-20 (Shielded Resource Contract) Standard.

## 📂 Lokasi Kode Utama
*   **Frontend UI & Logic**: `packages/frontend/app/seth/page.tsx`
*   **Contract ABI**: `packages/frontend/app/lib/seth-abi.ts`
*   **Network Config**: `packages/frontend/app/lib/config.ts`

---
*Project ini menunjukkan implementasi nyata dari privasi on-chain menggunakan Jaringan Seismic.*
