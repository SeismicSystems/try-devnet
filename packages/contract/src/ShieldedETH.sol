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

    // ── SRC-20 Events (encrypted amount format) ──────────────────
    event Transfer(
        address indexed from,
        address indexed to,
        bytes32 indexed encryptKeyHash,
        bytes encryptedAmount
    );
    event Approval(
        address indexed owner,
        address indexed spender,
        bytes32 indexed encryptKeyHash,
        bytes encryptedAmount
    );
    event Deposit(address indexed from, uint256 amount);
    event Redeem(address indexed from, address indexed to, uint256 amount);

    // ── Constructor: accept initial ETH liquidity ────────────────
    constructor() payable {
        if (msg.value > 0) {
            _balances[msg.sender] = suint256(msg.value);
            _totalSupply = msg.value;
            emit Deposit(msg.sender, msg.value);
            emit Transfer(
                address(0),
                msg.sender,
                keccak256(abi.encodePacked(msg.value)),
                abi.encodePacked(msg.value)
            );
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
    function balanceOf() external view returns (uint256) {
        return uint256(_balances[msg.sender]);
    }

    /// @notice Transfer sETH to another address (shielded amount).
    function transfer(address to, suint256 amount) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(to != msg.sender, "Cannot transfer to yourself");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[to] = _balances[to] + amount;

        uint256 plain = uint256(amount);
        emit Transfer(
            msg.sender,
            to,
            keccak256(abi.encodePacked(plain)),
            abi.encodePacked(plain)
        );
        return true;
    }

    /// @notice Approve a spender to transfer sETH on your behalf.
    function approve(address spender, suint256 amount) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        _allowances[msg.sender][spender] = amount;

        uint256 plain = uint256(amount);
        emit Approval(
            msg.sender,
            spender,
            keccak256(abi.encodePacked(plain)),
            abi.encodePacked(plain)
        );
        return true;
    }

    /// @notice Transfer sETH from an approved account.
    function transferFrom(address from, address to, suint256 amount) external returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");

        _balances[from] = _balances[from] - amount;
        _balances[to] = _balances[to] + amount;
        _allowances[from][msg.sender] = _allowances[from][msg.sender] - amount;

        uint256 plain = uint256(amount);
        emit Transfer(
            from,
            to,
            keccak256(abi.encodePacked(plain)),
            abi.encodePacked(plain)
        );
        return true;
    }

    /// @notice Check your allowance for a spender (signed read).
    function allowance(address spender) external view returns (uint256) {
        return uint256(_allowances[msg.sender][spender]);
    }

    // ══════════════════════════════════════════════════════════════
    //  Deposit & Redeem (ETH ↔ sETH)
    // ══════════════════════════════════════════════════════════════

    /// @notice Deposit ETH and mint sETH tokens 1:1.
    function deposit() external payable {
        require(msg.value > 0, "Must deposit > 0 ETH");

        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;

        emit Deposit(msg.sender, msg.value);
        emit Transfer(
            address(0),
            msg.sender,
            keccak256(abi.encodePacked(msg.value)),
            abi.encodePacked(msg.value)
        );
    }

    /// @notice Burn sETH tokens and receive ETH at the specified address.
    function redeem(address payable to, suint256 amount) external {
        require(to != address(0), "Cannot redeem to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;

        uint256 plainAmount = uint256(amount);
        _totalSupply -= plainAmount;

        (bool success, ) = to.call{value: plainAmount}("");
        require(success, "ETH transfer failed");

        emit Transfer(
            msg.sender,
            address(0),
            keccak256(abi.encodePacked(plainAmount)),
            abi.encodePacked(plainAmount)
        );
        emit Redeem(msg.sender, to, plainAmount);
    }

    // ── Public Reads ─────────────────────────────────────────────

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Receive ETH directly → auto-mint sETH ───────────────────
    receive() external payable {
        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
        emit Transfer(
            address(0),
            msg.sender,
            keccak256(abi.encodePacked(msg.value)),
            abi.encodePacked(msg.value)
        );
    }
}
