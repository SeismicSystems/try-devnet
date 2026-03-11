// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Shielded ETH (sETH) — SRC-20 Token
/// @notice Deposit ETH to mint sETH tokens (1:1). Transfer sETH privately.
///         Redeem sETH to burn tokens and get ETH back.
///         Follows SRC-20 standard (Seismic's privacy-preserving ERC-20).
contract ShieldedETH {
    // ── Token Metadata ───────────────────────────────────────────
    string public constant name = "Shielded ETH";
    string public constant symbol = "sETH";
    uint8 public constant decimals = 18;

    // ── Shielded Balances (encrypted on-chain) ───────────────────
    mapping(address => suint256) private _balances;
    mapping(address => mapping(address => suint256)) private _allowances;

    // ── Public total supply tracker ──────────────────────────────
    uint256 private _totalSupply;

    // ── Events (SRC-20 standard) ─────────────────────────────────
    event Transfer(address indexed from, address indexed to, suint256 amount);
    event Approval(address indexed owner, address indexed spender, suint256 amount);
    event Deposit(address indexed from, uint256 amount);
    event Redeem(address indexed from, address indexed to, uint256 amount);

    // ── Constructor: accept initial ETH liquidity ────────────────
    constructor() payable {
        if (msg.value > 0) {
            _balances[msg.sender] = suint256(msg.value);
            _totalSupply = msg.value;
            emit Deposit(msg.sender, msg.value);
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  SRC-20 Standard Functions
    // ══════════════════════════════════════════════════════════════

    /// @notice Get total sETH supply (public, not shielded).
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Get your own sETH balance (SRC-20: no address arg, uses msg.sender).
    ///         Must use signed read — proves identity.
    function balanceOf() external view returns (uint256) {
        return uint256(_balances[msg.sender]);
    }

    /// @notice Transfer sETH to another address.
    ///         Amount is shielded (suint256) — encrypted on-chain.
    /// @param to     Recipient address.
    /// @param amount Amount of sETH to transfer (shielded).
    /// @return success Always true if no revert.
    function transfer(address to, suint256 amount) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(to != msg.sender, "Cannot transfer to yourself");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[to] = _balances[to] + amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Approve a spender to transfer sETH on your behalf.
    /// @param spender Address to approve.
    /// @param amount  Shielded allowance amount.
    /// @return success Always true if no revert.
    function approve(address spender, suint256 amount) external returns (bool) {
        require(spender != address(0), "Approve to zero address");

        _allowances[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfer sETH from an approved account.
    /// @param from   Address to transfer from.
    /// @param to     Recipient address.
    /// @param amount Shielded amount to transfer.
    /// @return success Always true if no revert.
    function transferFrom(address from, address to, suint256 amount) external returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");

        _balances[from] = _balances[from] - amount;
        _balances[to] = _balances[to] + amount;
        _allowances[from][msg.sender] = _allowances[from][msg.sender] - amount;

        emit Transfer(from, to, amount);
        return true;
    }

    /// @notice Check your allowance for a spender (signed read).
    /// @param spender Address of the spender.
    function allowance(address spender) external view returns (uint256) {
        return uint256(_allowances[msg.sender][spender]);
    }

    // ══════════════════════════════════════════════════════════════
    //  Deposit & Redeem (ETH ↔ sETH)
    // ══════════════════════════════════════════════════════════════

    /// @notice Deposit ETH and mint sETH tokens 1:1.
    ///         sETH tokens are minted to the depositor's address.
    function deposit() external payable {
        require(msg.value > 0, "Must deposit > 0 ETH");

        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;

        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, suint256(msg.value));
    }

    /// @notice Burn sETH tokens and receive ETH at the specified address.
    ///         Can redeem to a different wallet.
    /// @param to     Address to receive the ETH.
    /// @param amount Amount of sETH to burn (shielded).
    function redeem(address payable to, suint256 amount) external {
        require(to != address(0), "Cannot redeem to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;

        uint256 plainAmount = uint256(amount);
        _totalSupply -= plainAmount;

        (bool success, ) = to.call{value: plainAmount}("");
        require(success, "ETH transfer failed");

        emit Transfer(msg.sender, address(0), amount);
        emit Redeem(msg.sender, to, plainAmount);
    }

    // ── Public Reads ─────────────────────────────────────────────

    /// @notice Get the ETH held by this contract.
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Receive ETH directly → auto-mint sETH ───────────────────
    receive() external payable {
        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, suint256(msg.value));
    }
}
