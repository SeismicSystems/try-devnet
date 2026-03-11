"use client";

import { useState, useCallback } from "react";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { useReadContract, usePublicClient, useBalance } from "wagmi";
import {
    useShieldedWallet,
} from "seismic-react";
import { signedReadContract } from "seismic-viem";
import { SHIELDED_ETH_ABI } from "../lib/seth-abi";
import { SETH_CONTRACT_ADDRESS } from "../lib/config";
import { parseEther, formatEther } from "viem";

export default function SethPage() {
    const { address } = useShieldedWallet();
    const publicClient = usePublicClient();

    // ── ETH Balance for Deposit ──────────────────────────────
    const { data: ethBalanceData } = useBalance({
        address: address as `0x${string}` | undefined,
    });
    const ethBalance = ethBalanceData?.value || BigInt(0);

    const handlePercentage = (balance: bigint | null, percentage: number, setter: (val: string) => void, isEth: boolean = false) => {
        if (!balance || balance === BigInt(0)) return;
        let amount = (balance * BigInt(percentage)) / BigInt(100);

        // Exclude a small gas buffer for "Max" ETH deposit
        if (isEth && percentage === 100) {
            const gasBuffer = parseEther("0.005"); // reserve 0.005 ETH for gas
            if (amount > gasBuffer) {
                amount -= gasBuffer;
            } else {
                amount = BigInt(0);
            }
        }

        // Optional: truncate down so we don't spam long decimals, but formatEther is generally fine.
        setter(formatEther(amount));
    };

    // ── State ──────────────────────────────────────────────────
    const [depositAmount, setDepositAmount] = useState("");
    const [transferTo, setTransferTo] = useState("");
    const [transferAmount, setTransferAmount] = useState("");
    const [redeemTo, setRedeemTo] = useState("");
    const [redeemAmount, setRedeemAmount] = useState("");
    const [activeTab, setActiveTab] = useState<"deposit" | "transfer" | "redeem">(
        "deposit"
    );
    const [txStatus, setTxStatus] = useState<{
        type: "success" | "error" | "pending";
        message: React.ReactNode;
    } | null>(null);

    // ── Public Reads ───────────────────────────────────────────
    const { data: totalSupply, refetch: refetchSupply } = useReadContract({
        abi: SHIELDED_ETH_ABI,
        address: SETH_CONTRACT_ADDRESS,
        functionName: "totalSupply",
    });

    const { data: contractBal, refetch: refetchContractBal } = useReadContract({
        abi: SHIELDED_ETH_ABI,
        address: SETH_CONTRACT_ADDRESS,
        functionName: "contractBalance",
    });

    // ── Signed Read: User Balance (shielded) ───────────────────
    const { walletClient } = useShieldedWallet();

    const [userBalance, setUserBalance] = useState<bigint | null>(null);
    const [balanceError, setBalanceError] = useState<string | null>(null);
    const [isReadingBalance, setIsReadingBalance] = useState(false);

    const handleReadBalance = useCallback(async () => {
        if (!walletClient) return;
        setIsReadingBalance(true);
        setBalanceError(null);
        try {
            const result = await signedReadContract(walletClient, {
                abi: SHIELDED_ETH_ABI,
                address: SETH_CONTRACT_ADDRESS,
                functionName: "balanceOf",
                // Crucial: override simulated gas. Default is 30M, causing node check to require ~0.036 ETH.
                // 500,000 gas brings the req down to ~0.0006 ETH.
                gas: BigInt(500000),
            } as any);
            setUserBalance(result as bigint);
        } catch (err: unknown) {
            console.error("Read balance error:", err);
            setBalanceError(
                err instanceof Error ? err.message : "Failed to read balance"
            );
        } finally {
            setIsReadingBalance(false);
        }
    }, [walletClient]);

    // ── Shielded Writes (via walletClient directly) ────────────
    const [isDepositing, setIsDepositing] = useState(false);
    const [isTransferring, setIsTransferring] = useState(false);
    const [isRedeeming, setIsRedeeming] = useState(false);

    // ── Handlers ───────────────────────────────────────────────
    const handleDeposit = async () => {
        if (!depositAmount || parseFloat(depositAmount) <= 0 || !walletClient) return;
        setTxStatus({ type: "pending", message: "Sending deposit transaction..." });
        setIsDepositing(true);

        try {
            const hash = await walletClient.writeContract({
                address: SETH_CONTRACT_ADDRESS,
                abi: SHIELDED_ETH_ABI,
                functionName: "deposit",
                value: parseEther(depositAmount),
            });

            if (publicClient) {
                setTxStatus({
                    type: "pending",
                    message: (
                        <>
                            Tx submitted. Waiting for confirmation:{" "}
                            <a href={`https://seismic-testnet.socialscan.io/tx/${hash}`} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline', color: 'inherit' }}>
                                {hash.slice(0, 10)}...
                            </a>
                        </>
                    )
                });
                await publicClient.waitForTransactionReceipt({ hash });
            }

            setTxStatus({
                type: "success",
                message: (
                    <>
                        Deposited {depositAmount} ETH → sETH. Tx:{" "}
                        <a href={`https://seismic-testnet.socialscan.io/tx/${hash}`} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline', color: 'inherit' }}>
                            {hash.slice(0, 10)}...
                        </a>
                    </>
                )
            });
            setDepositAmount("");
            refetchSupply();
            refetchContractBal();
            if (userBalance !== null) handleReadBalance();
        } catch (err: unknown) {
            console.error("Deposit error:", err);
            setTxStatus({
                type: "error",
                message: err instanceof Error ? err.message : "Deposit failed",
            });
        } finally {
            setIsDepositing(false);
        }
    };

    const handleTransfer = async () => {
        if (!transferTo || !transferAmount || parseFloat(transferAmount) <= 0 || !walletClient)
            return;
        setTxStatus({
            type: "pending",
            message: "Sending shielded transfer...",
        });
        setIsTransferring(true);

        try {
            const hash = await walletClient.writeContract({
                address: SETH_CONTRACT_ADDRESS,
                abi: SHIELDED_ETH_ABI,
                functionName: "transfer",
                args: [transferTo as `0x${string}`, parseEther(transferAmount)],
            });

            if (publicClient) {
                setTxStatus({
                    type: "pending",
                    message: (
                        <>
                            Tx submitted. Waiting for confirmation:{" "}
                            <a href={`https://seismic-testnet.socialscan.io/tx/${hash}`} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline', color: 'inherit' }}>
                                {hash.slice(0, 10)}...
                            </a>
                        </>
                    )
                });
                await publicClient.waitForTransactionReceipt({ hash });
            }

            setTxStatus({
                type: "success",
                message: (
                    <>
                        Transferred {transferAmount} sETH. Tx:{" "}
                        <a href={`https://seismic-testnet.socialscan.io/tx/${hash}`} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline', color: 'inherit' }}>
                            {hash.slice(0, 10)}...
                        </a>
                    </>
                )
            });
            setTransferTo("");
            setTransferAmount("");
            if (userBalance !== null) handleReadBalance();
        } catch (err: unknown) {
            console.error("Transfer error:", err);
            setTxStatus({
                type: "error",
                message: err instanceof Error ? err.message : "Transfer failed",
            });
        } finally {
            setIsTransferring(false);
        }
    };

    const handleRedeem = async () => {
        if (!redeemTo || !redeemAmount || parseFloat(redeemAmount) <= 0 || !walletClient) return;
        setTxStatus({ type: "pending", message: "Redeeming sETH → ETH..." });
        setIsRedeeming(true);

        try {
            const hash = await walletClient.writeContract({
                address: SETH_CONTRACT_ADDRESS,
                abi: SHIELDED_ETH_ABI,
                functionName: "redeem",
                args: [redeemTo as `0x${string}`, parseEther(redeemAmount)],
            });

            if (publicClient) {
                setTxStatus({
                    type: "pending",
                    message: (
                        <>
                            Tx submitted. Waiting for confirmation:{" "}
                            <a href={`https://seismic-testnet.socialscan.io/tx/${hash}`} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline', color: 'inherit' }}>
                                {hash.slice(0, 10)}...
                            </a>
                        </>
                    )
                });
                await publicClient.waitForTransactionReceipt({ hash });
            }

            setTxStatus({
                type: "success",
                message: (
                    <>
                        Redeemed {redeemAmount} sETH → ETH. Tx:{" "}
                        <a href={`https://seismic-testnet.socialscan.io/tx/${hash}`} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline', color: 'inherit' }}>
                            {hash.slice(0, 10)}...
                        </a>
                    </>
                )
            });
            setRedeemTo("");
            setRedeemAmount("");
            refetchSupply();
            refetchContractBal();
            if (userBalance !== null) handleReadBalance();
        } catch (err: unknown) {
            console.error("Redeem error:", err);
            setTxStatus({
                type: "error",
                message: err instanceof Error ? err.message : "Redeem failed",
            });
        } finally {
            setIsRedeeming(false);
        }
    };

    return (
        <div className="app-container">
            {/* Header */}
            <header className="header">
                <div className="header__content">
                    <div className="header__badge">Seismic Testnet</div>
                    <h1 className="header__title">Shielded ETH (sETH)</h1>
                    <p className="header__subtitle">
                        Deposit ETH to receive privacy-preserving sETH tokens. Transfer
                        privately and redeem anytime to get your ETH back.
                    </p>
                </div>
                <div className="header__actions">
                    <ConnectButton />
                </div>
            </header>

            {/* Protocol Stats */}
            <section className="seth-stats">
                <div className="seth-stats__item">
                    <span className="seth-stats__label">Total Supply</span>
                    <span className="seth-stats__value">
                        {totalSupply !== undefined
                            ? formatEther(totalSupply as bigint)
                            : "—"}{" "}
                        sETH
                    </span>
                </div>
                <div className="seth-stats__item">
                    <span className="seth-stats__label">Contract Balance</span>
                    <span className="seth-stats__value">
                        {contractBal !== undefined
                            ? formatEther(contractBal as bigint)
                            : "—"}{" "}
                        ETH
                    </span>
                </div>
            </section>

            {/* User Balance */}
            {address && (
                <section className="connect-panel">
                    <h2 className="connect-panel__title">Your sETH Balance</h2>
                    <div className="seth-balance-row">
                        <div className="seth-balance-display">
                            {userBalance !== null ? (
                                <>
                                    <span className="seth-balance-amount">
                                        {formatEther(userBalance)}
                                    </span>
                                    <span className="seth-balance-unit">sETH</span>
                                </>
                            ) : (
                                <span className="seth-balance-hidden">
                                    Balance encrypted — sign to reveal
                                </span>
                            )}
                        </div>
                        <button
                            className="btn-primary"
                            onClick={handleReadBalance}
                            disabled={isReadingBalance}
                        >
                            {isReadingBalance ? (
                                <>
                                    <span className="spinner" /> Reading
                                </>
                            ) : userBalance !== null ? (
                                "Refresh Balance"
                            ) : (
                                "Sign to Reveal"
                            )}
                        </button>
                    </div>
                    {balanceError && (
                        <div className="status-bar status-bar--error">✕ {balanceError}</div>
                    )}
                </section>
            )}

            {/* Interaction Panel */}
            {address ? (
                <section className="connect-panel">
                    {/* Tab Navigation */}
                    <div className="seth-tabs">
                        <button
                            className={`seth-tab ${activeTab === "deposit" ? "seth-tab--active" : ""
                                }`}
                            onClick={() => {
                                setActiveTab("deposit");
                                setTxStatus(null);
                            }}
                        >
                            Deposit
                        </button>
                        <button
                            className={`seth-tab ${activeTab === "transfer" ? "seth-tab--active" : ""
                                }`}
                            onClick={() => {
                                setActiveTab("transfer");
                                setTxStatus(null);
                            }}
                        >
                            Transfer
                        </button>
                        <button
                            className={`seth-tab ${activeTab === "redeem" ? "seth-tab--active" : ""
                                }`}
                            onClick={() => {
                                setActiveTab("redeem");
                                setTxStatus(null);
                            }}
                        >
                            Redeem
                        </button>
                    </div>

                    {/* Deposit Tab */}
                    {activeTab === "deposit" && (
                        <div className="seth-form">
                            <div className="seth-form__description">
                                Deposit ETH and receive an equal amount of shielded sETH tokens.
                                Your balance will be encrypted on-chain.
                            </div>
                            <div className="input-group">
                                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "8px" }}>
                                    <label className="input-group__label" style={{ marginBottom: 0 }}>Amount (ETH)</label>
                                    <div style={{ display: "flex", gap: "8px" }}>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(ethBalance, 25, setDepositAmount)}>25%</button>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(ethBalance, 50, setDepositAmount)}>50%</button>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(ethBalance, 100, setDepositAmount, true)}>Max</button>
                                    </div>
                                </div>
                                <input
                                    className="input-group__input"
                                    type="number"
                                    step="0.001"
                                    min="0"
                                    placeholder="0.01"
                                    value={depositAmount}
                                    onChange={(e) => setDepositAmount(e.target.value)}
                                />
                            </div>
                            <button
                                className="btn-primary btn-full"
                                onClick={handleDeposit}
                                disabled={
                                    isDepositing ||
                                    !depositAmount ||
                                    parseFloat(depositAmount) <= 0
                                }
                            >
                                {isDepositing ? (
                                    <>
                                        <span className="spinner" /> Depositing...
                                    </>
                                ) : (
                                    "Deposit ETH → sETH"
                                )}
                            </button>
                        </div>
                    )}

                    {/* Transfer Tab */}
                    {activeTab === "transfer" && (
                        <div className="seth-form">
                            <div className="seth-form__description">
                                Transfer sETH to another wallet. The amount is shielded — no one
                                can see how much was transferred on-chain.
                            </div>
                            <div className="input-group">
                                <label className="input-group__label">Recipient Address</label>
                                <input
                                    className="input-group__input"
                                    type="text"
                                    placeholder="0x..."
                                    value={transferTo}
                                    onChange={(e) => setTransferTo(e.target.value)}
                                />
                            </div>
                            <div className="input-group">
                                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "8px" }}>
                                    <label className="input-group__label" style={{ marginBottom: 0 }}>Amount (sETH)</label>
                                    <div style={{ display: "flex", gap: "8px" }}>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(userBalance, 25, setTransferAmount)}>25%</button>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(userBalance, 50, setTransferAmount)}>50%</button>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(userBalance, 100, setTransferAmount)}>Max</button>
                                    </div>
                                </div>
                                <input
                                    className="input-group__input"
                                    type="number"
                                    step="0.001"
                                    min="0"
                                    placeholder="0.01"
                                    value={transferAmount}
                                    onChange={(e) => setTransferAmount(e.target.value)}
                                />
                            </div>
                            <button
                                className="btn-primary btn-full"
                                onClick={handleTransfer}
                                disabled={
                                    isTransferring ||
                                    !transferTo ||
                                    !transferAmount ||
                                    parseFloat(transferAmount) <= 0
                                }
                            >
                                {isTransferring ? (
                                    <>
                                        <span className="spinner" /> Transferring...
                                    </>
                                ) : (
                                    "Transfer sETH (Shielded)"
                                )}
                            </button>
                        </div>
                    )}

                    {/* Redeem Tab */}
                    {activeTab === "redeem" && (
                        <div className="seth-form">
                            <div className="seth-form__description">
                                Burn your sETH and receive ETH at any address. You can redeem to
                                a different wallet.
                            </div>
                            <div className="input-group">
                                <label className="input-group__label">
                                    Receive ETH At Address
                                </label>
                                <input
                                    className="input-group__input"
                                    type="text"
                                    placeholder="0x... (can be a different wallet)"
                                    value={redeemTo}
                                    onChange={(e) => setRedeemTo(e.target.value)}
                                />
                                {address && (
                                    <button
                                        className="btn-secondary btn-small"
                                        onClick={() => setRedeemTo(address)}
                                    >
                                        Use My Wallet
                                    </button>
                                )}
                            </div>
                            <div className="input-group">
                                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "8px" }}>
                                    <label className="input-group__label" style={{ marginBottom: 0 }}>Amount (sETH)</label>
                                    <div style={{ display: "flex", gap: "8px" }}>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(userBalance, 25, setRedeemAmount)}>25%</button>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(userBalance, 50, setRedeemAmount)}>50%</button>
                                        <button className="btn-secondary btn-small" onClick={() => handlePercentage(userBalance, 100, setRedeemAmount)}>Max</button>
                                    </div>
                                </div>
                                <input
                                    className="input-group__input"
                                    type="number"
                                    step="0.001"
                                    min="0"
                                    placeholder="0.01"
                                    value={redeemAmount}
                                    onChange={(e) => setRedeemAmount(e.target.value)}
                                />
                            </div>
                            <button
                                className="btn-primary btn-full"
                                onClick={handleRedeem}
                                disabled={
                                    isRedeeming ||
                                    !redeemTo ||
                                    !redeemAmount ||
                                    parseFloat(redeemAmount) <= 0
                                }
                            >
                                {isRedeeming ? (
                                    <>
                                        <span className="spinner" /> Redeeming...
                                    </>
                                ) : (
                                    "Redeem sETH → ETH"
                                )}
                            </button>
                        </div>
                    )}

                    {/* Transaction Status */}
                    {txStatus && (
                        <div
                            className={`status-bar status-bar--${txStatus.type === "pending" ? "pending" : txStatus.type}`}
                        >
                            {txStatus.type === "success" && "✓ "}
                            {txStatus.type === "error" && "✕ "}
                            {txStatus.type === "pending" && (
                                <span className="spinner" />
                            )}
                            {txStatus.message}
                        </div>
                    )}
                </section>
            ) : (
                <section className="connect-panel">
                    <h2 className="connect-panel__title">Get Started</h2>
                    <div
                        style={{
                            textAlign: "center",
                            padding: "20px 0",
                            color: "var(--text-secondary)",
                        }}
                    >
                        Connect your wallet to deposit, transfer, and redeem sETH.
                    </div>
                </section>
            )}

            {/* How It Works */}
            <section className="nft-card">
                <div className="nft-card__body">
                    <div className="nft-card__section-title">How It Works</div>
                    <div className="trait-grid">
                        <div className="trait-item">
                            <div className="trait-item__label">1. Deposit</div>
                            <div className="trait-item__value seth-how-text">
                                Send ETH → get sETH
                            </div>
                        </div>
                        <div className="trait-item">
                            <div className="trait-item__label">2. Balance</div>
                            <div className="trait-item__value seth-how-text">
                                Encrypted on-chain
                            </div>
                        </div>
                        <div className="trait-item">
                            <div className="trait-item__label">3. Transfer</div>
                            <div className="trait-item__value seth-how-text">
                                Private amounts
                            </div>
                        </div>
                        <div className="trait-item">
                            <div className="trait-item__label">4. Redeem</div>
                            <div className="trait-item__value seth-how-text">
                                sETH → ETH back
                            </div>
                        </div>
                    </div>
                    <div className="encrypted-badge">
                        All balances stored encrypted (suint256) on Seismic — only you can
                        see your balance
                    </div>
                </div>
            </section>

            {/* Footer */}
            <footer className="footer">
                <p className="footer__text">
                    <a href="/" className="footer__link">
                        ← Discord Stat NFT
                    </a>
                    {" · "}
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
