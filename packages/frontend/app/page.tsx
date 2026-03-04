"use client";

import { useState, useEffect, useRef } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useReadContract, usePublicClient } from "wagmi";
import { useShieldedWallet, useSignedReadContract } from "seismic-react";
import { SEISMIC_DISCORD_STAT_ABI } from "./lib/abi";
import { CONTRACT_ADDRESS } from "./lib/config";

const ROLE_NAMES: Record<number, string> = {
  1: "Magnitude 1",
  2: "Magnitude 2",
  3: "Magnitude 3",
  4: "Magnitude 4",
  5: "Magnitude 5",
  6: "Magnitude 6",
  7: "Magnitude 7",
  8: "Magnitude 8",
  9: "Magnitude 9",

};

export default function Home() {
  const { address } = useShieldedWallet();
  const publicClient = usePublicClient();

  const [tokenId, setTokenId] = useState("0");
  const [isFindingNFT, setIsFindingNFT] = useState(false);

  useEffect(() => {
    if (!address || !publicClient) {
      setTokenId("0");
      return;
    }

    let isMounted = true;
    const findHighestToken = async () => {
      setIsFindingNFT(true);
      let highestOwned = 0;

      try {
        // Find highest Token ID owned by the user
        // We evaluate a fixed window (e.g. 1-20) instead of breaking on error (since some tokens might be burned resulting in gaps)
        for (let i = 1; i <= 20; i++) {
          try {
            const owner = await publicClient.readContract({
              address: CONTRACT_ADDRESS,
              abi: SEISMIC_DISCORD_STAT_ABI,
              functionName: "ownerOf",
              args: [BigInt(i)],
            });
            if (owner === address) {
              highestOwned = i;
            }
          } catch (err) {
            // Revert usually means the token doesn't exist yet or is burned, 
            // but we shouldn't break because there might be a higher token index further ahead
            continue;
          }
        }
      } catch (err) {
        console.error("Error searching for token:", err);
      }

      if (isMounted) {
        setTokenId(highestOwned.toString());
        setIsFindingNFT(false);
      }
    };

    findHighestToken();

    return () => { isMounted = false; };
  }, [address, publicClient]);

  const hasToken = tokenId !== "0";

  // Public read for owner directly using wagmi
  const { data: owner } = useReadContract({
    abi: SEISMIC_DISCORD_STAT_ABI,
    address: CONTRACT_ADDRESS,
    functionName: "ownerOf",
    args: hasToken ? [BigInt(tokenId)] : undefined,
    query: { enabled: hasToken }
  });

  const { data: tokenURI } = useReadContract({
    abi: SEISMIC_DISCORD_STAT_ABI,
    address: CONTRACT_ADDRESS,
    functionName: "tokenURI",
    args: hasToken ? [BigInt(tokenId)] : undefined,
    query: { enabled: hasToken }
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
    args: hasToken ? [BigInt(tokenId)] : undefined,
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
    error?: boolean;
  } | null>(null);

  useEffect(() => {
    if (!tokenURI) {
      setMetadata(null);
      return;
    }
    const fetchMetadata = async () => {
      try {
        let uri = tokenURI as string;
        if (uri.startsWith("ipfs://")) {
          uri = uri.replace("ipfs://", "https://ipfs.io/ipfs/");
        }
        const res = await fetch(uri);
        const data = await res.json();
        setMetadata(data);
      } catch (e) {
        console.error("Failed to fetch metadata:", e);
        setMetadata({ error: true });
      }
    };
    fetchMetadata();
  }, [tokenURI]);

  const videoRef = useRef<HTMLVideoElement>(null);

  const handleVideoEnded = () => {
    if (videoRef.current) {
      videoRef.current.playbackRate = -1;
      videoRef.current.play();
    }
  };

  const handleTimeUpdate = () => {
    if (videoRef.current) {
      const v = videoRef.current;
      if (v.playbackRate < 0 && v.currentTime <= 0.05) {
        v.playbackRate = 1;
        v.play();
      }
    }
  };

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
      <header className="header">
        <div className="header__content">
          <div className="header__badge">Seismic Testnet</div>
          <h1 className="header__title">Discord Stat NFT</h1>
          <p className="header__subtitle">
            View your encrypted Discord activity traits. Only the NFT owner can
            decrypt and reveal the shielded on-chain data.
          </p>
        </div>
        <div className="header__actions">
          <ConnectButton />
        </div>
      </header>

      {/* Connect Panel */}
      <section className="connect-panel">
        <h2 className="connect-panel__title">Authentication</h2>

        {!address ? (
          <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--text-secondary)' }}>
            Please connect your wallet to decrypt NFT traits.
          </div>
        ) : isFindingNFT ? (
          <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--text-secondary)' }}>
            <span className="spinner" /> Scanning your wallet for Discord Stat NFTs...
          </div>
        ) : !hasToken ? (
          <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--text-secondary)' }}>
            It looks like you don't own a Discord Stat NFT on this wallet.
          </div>
        ) : (
          <div className="input-row">
            <div className="input-group" style={{ marginBottom: 0, flexDirection: "row", alignItems: "center", gap: "12px", border: "1px solid var(--border-color)", padding: "10px 15px" }}>
              <span style={{ color: "var(--text-secondary)" }}>Detected Token ID:</span>
              <strong style={{ fontSize: "1.1rem" }}>#{tokenId}</strong>
            </div>
            <button
              className="btn-primary"
              onClick={handleDecrypt}
              disabled={isDecrypting}
            >
              {isDecrypting ? (
                <>
                  <span className="spinner" /> Decrypting
                </>
              ) : (
                "Sign to Decrypt"
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

          <div className="nft-card__media">
            {metadata ? (
              metadata.error ? (
                <div style={{ width: "100%", aspectRatio: "16/9", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)", backgroundColor: "var(--bg-primary)" }}>
                  Failed to load media
                </div>
              ) : metadata.animation_url ? (
                <video
                  ref={videoRef}
                  src={metadata.animation_url.startsWith("ipfs://") ? metadata.animation_url.replace("ipfs://", "https://ipfs.io/ipfs/") : metadata.animation_url}
                  autoPlay
                  muted
                  playsInline
                  onEnded={handleVideoEnded}
                  onTimeUpdate={handleTimeUpdate}
                  style={{ width: "100%", height: "100%", objectFit: "cover", display: "block" }}
                />
              ) : metadata.image ? (
                <img
                  src={metadata.image.startsWith("ipfs://") ? metadata.image.replace("ipfs://", "https://ipfs.io/ipfs/") : metadata.image}
                  alt="NFT Media"
                />
              ) : (
                <div style={{ width: "100%", aspectRatio: "16/9", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)", backgroundColor: "var(--bg-primary)" }}>
                  No media available
                </div>
              )
            ) : (
              <div style={{ width: "100%", aspectRatio: "16/9", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--text-secondary)", backgroundColor: "var(--bg-primary)" }}>
                Retrieving media...
              </div>
            )}
          </div>

          <div className="nft-card__body">
            <div className="nft-card__section-title">
              Decrypted Shielded Traits
            </div>
            <div className="trait-grid">
              <div className="trait-item">
                <div className="trait-item__label">Art Submissions</div>
                <div className="trait-item__value">
                  {stats.art.toString()}
                </div>
              </div>
              <div className="trait-item">
                <div className="trait-item__label">Tweets</div>
                <div className="trait-item__value">
                  {stats.tweet.toString()}
                </div>
              </div>
              <div className="trait-item">
                <div className="trait-item__label">Chat Messages</div>
                <div className="trait-item__value">
                  {stats.chat.toString()}
                </div>
              </div>
              <div className="trait-item">
                <div className="trait-item__label">Highest Role</div>
                <div className="trait-item__value">
                  {ROLE_NAMES[Number(stats.role)] || `Level ${stats.role.toString()}`}
                </div>
              </div>
            </div>
            <div className="encrypted-badge">
              All traits are stored encrypted (suint256) on Seismic
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
