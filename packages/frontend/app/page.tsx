"use client";

import { useState, useEffect } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useReadContract } from "wagmi";
import { useShieldedWallet, useSignedReadContract } from "seismic-react";
import { SEISMIC_DISCORD_STAT_ABI } from "./lib/abi";
import { CONTRACT_ADDRESS } from "./lib/config";

const ROLE_NAMES: Record<number, string> = {
  1: "Member",
  2: "Active",
  3: "Contributor",
  4: "Moderator",
  5: "Admin",
  6: "Owner",
};

export default function Home() {
  const [tokenId, setTokenId] = useState("1");
  const { address } = useShieldedWallet();

  // Public read for owner directly using wagmi
  const { data: owner } = useReadContract({
    abi: SEISMIC_DISCORD_STAT_ABI,
    address: CONTRACT_ADDRESS,
    functionName: "ownerOf",
    args: [BigInt(tokenId || 1)],
  });

  const { data: tokenURI } = useReadContract({
    abi: SEISMIC_DISCORD_STAT_ABI,
    address: CONTRACT_ADDRESS,
    functionName: "tokenURI",
    args: [BigInt(tokenId || 1)],
  });

  // Signed read for stats using seismic-react
  const {
    read: decryptStats,
    isLoading: isDecrypting,
    error: decryptError
  } = useSignedReadContract({
    abi: SEISMIC_DISCORD_STAT_ABI,
    address: CONTRACT_ADDRESS,
    functionName: "getStats",
    args: [BigInt(tokenId || 1)],
  });

  const [stats, setStats] = useState<{
    art: bigint;
    tweet: bigint;
    chat: bigint;
    role: bigint;
  } | null>(null);

  const [decryptStatus, setDecryptStatus] = useState<{
    type: "success" | "error";
    message: string;
  } | null>(null);

  const [metadata, setMetadata] = useState<{
    image?: string;
    animation_url?: string;
  } | null>(null);

  useEffect(() => {
    if (!tokenURI) {
      setMetadata(null);
      return;
    }
    const fetchMetadata = async () => {
      try {
        const res = await fetch(tokenURI as string);
        const data = await res.json();
        setMetadata(data);
      } catch (e) {
        console.error("Failed to fetch metadata:", e);
      }
    };
    fetchMetadata();
  }, [tokenURI]);

  const handleDecrypt = async () => {
    setStats(null);
    setDecryptStatus(null);

    try {
      const result = await decryptStats();
      const [art, tweet, chat, role] = result as [bigint, bigint, bigint, bigint];
      setStats({ art, tweet, chat, role });
      setDecryptStatus({
        type: "success",
        message: "Traits decrypted successfully! You are the verified owner."
      });
    } catch (err: unknown) {
      console.error("Decryption error:", err);
      const errorMessage = err instanceof Error ? err.message : "Unknown error";
      if (errorMessage.includes("Not the owner") || errorMessage.includes("reverted")) {
        setDecryptStatus({
          type: "error",
          message: "Access denied. Your wallet is not the owner of this NFT.",
        });
      } else {
        setDecryptStatus({
          type: "error",
          message: `Error decryption failed. Details: ${errorMessage}`,
        });
      }
    }
  };

  return (
    <div className="app-container">
      {/* Header */}
      <header className="header" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ alignSelf: 'flex-end', marginBottom: '20px' }}>
          <ConnectButton />
        </div>
        <div className="header__badge">Seismic Testnet</div>
        <h1 className="header__title">Discord Stat NFT</h1>
        <p className="header__subtitle">
          View your encrypted Discord activity traits. Only the NFT owner can
          decrypt and reveal the shielded on-chain data.
        </p>
      </header>

      {/* Connect Panel */}
      <section className="connect-panel">
        <h2 className="connect-panel__title">🔐 Authenticate & Decrypt</h2>

        {!address ? (
          <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--text-secondary)' }}>
            Please connect your wallet to decrypt NFT traits.
          </div>
        ) : (
          <div className="input-row">
            <div className="input-group" style={{ marginBottom: 0 }}>
              <label htmlFor="tokenId">Token ID</label>
              <input
                id="tokenId"
                type="number"
                className="input-field"
                placeholder="1"
                value={tokenId}
                onChange={(e) => setTokenId(e.target.value)}
                min="1"
              />
            </div>
            <button
              className="btn-primary"
              onClick={handleDecrypt}
              disabled={isDecrypting}
            >
              {isDecrypting ? (
                <>
                  <span className="spinner" /> Decrypting via Wallet...
                </>
              ) : (
                "🔓 Sign to Decrypt"
              )}
            </button>
          </div>
        )}

        {decryptStatus && (
          <div className={`status-bar status-bar--${decryptStatus.type}`}>
            {decryptStatus.type === "success" && "✓ "}
            {decryptStatus.type === "error" && "✕ "}
            {decryptStatus.message}
          </div>
        )}
      </section>

      {/* NFT Card */}
      {stats && (
        <section className="nft-card">
          <div className="nft-card__header">
            <div className="nft-card__token-id">Token #{tokenId}</div>
            <div className="nft-card__name">Seismic Discord Stat</div>
            <div className="nft-card__owner">
              Owner: {owner ? (owner as string).slice(0, 6) : "0x..."}...{owner ? (owner as string).slice(-4) : "..."}
            </div>
          </div>

          <div className="nft-card__media" style={{ margin: "20px auto", maxWidth: "400px", borderRadius: "8px", overflow: "hidden", border: "1px solid var(--border-color)", backgroundColor: "var(--card-bg)" }}>
            {metadata?.animation_url ? (
              <video
                src={metadata.animation_url}
                autoPlay
                loop
                muted
                playsInline
                controls
                style={{ width: "100%", display: "block", aspectRatio: "1/1", objectFit: "cover" }}
                poster={metadata.image}
              />
            ) : metadata?.image ? (
              <img
                src={metadata.image}
                alt="NFT Media"
                style={{ width: "100%", display: "block", aspectRatio: "1/1", objectFit: "cover" }}
              />
            ) : (
              <div style={{ width: "100%", aspectRatio: "1/1", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)", backgroundColor: "var(--bg-secondary)" }}>
                No Media Available
              </div>
            )}
          </div>

          <div className="nft-card__body">
            <div className="nft-card__section-title">
              Decrypted Shielded Traits
            </div>
            <div className="trait-grid">
              <div className="trait-item">
                <div className="trait-item__icon">🎨</div>
                <div className="trait-item__label">Art Submissions</div>
                <div className="trait-item__value">
                  {stats.art.toString()}
                </div>
              </div>
              <div className="trait-item">
                <div className="trait-item__icon">🐦</div>
                <div className="trait-item__label">Tweets</div>
                <div className="trait-item__value">
                  {stats.tweet.toString()}
                </div>
              </div>
              <div className="trait-item">
                <div className="trait-item__icon">💬</div>
                <div className="trait-item__label">Chat Messages</div>
                <div className="trait-item__value">
                  {stats.chat.toString()}
                </div>
              </div>
              <div className="trait-item">
                <div className="trait-item__icon">👑</div>
                <div className="trait-item__label">Highest Role</div>
                <div className="trait-item__value">
                  {ROLE_NAMES[Number(stats.role)] || `Level ${stats.role.toString()}`}
                </div>
              </div>
            </div>
            <div className="encrypted-badge">
              🔒 All traits are stored encrypted (suint256) on Seismic
            </div>
          </div>
        </section>
      )}

      {/* Footer */}
      <footer className="footer">
        <p className="footer__text">
          Powered by{" "}
          <a
            href="https://seismic.systems"
            className="footer__link"
            target="_blank"
            rel="noopener noreferrer"
          >
            Seismic Network
          </a>{" "}
          — Privacy-first blockchain
        </p>
      </footer>
    </div>
  );
}
