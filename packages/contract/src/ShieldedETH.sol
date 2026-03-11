// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Shielded ETH (sETH)
/// @notice Deposit ETH to receive shielded sETH tokens. Transfer privately
///         and redeem to any address to get your ETH back.
///         All balances are encrypted using Seismic's shielded types.
contract ShieldedETH {
    // ── Token Metadata ───────────────────────────────────────────
    string public constant name = "Shielded ETH";
    string public constant symbol = "sETH";
    uint8 public constant decimals = 18;

    // ── Shielded Balances (encrypted on-chain) ───────────────────
    mapping(address => suint256) private _balances;

    // ── Public total supply tracker ──────────────────────────────
    uint256 private _totalSupply;

    // ── Events ───────────────────────────────────────────────────
    event Deposit(address indexed from, uint256 amount);
    event Redeem(address indexed from, address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to);

    // ── Deposit: ETH → sETH ─────────────────────────────────────
    /// @notice Deposit ETH and receive the same amount of sETH.
    ///         The sETH balance is stored encrypted (suint256).
    function deposit() external payable {
        require(msg.value > 0, "Must deposit > 0 ETH");

        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;

        emit Deposit(msg.sender, msg.value);
    }

    // ── Transfer: sETH → sETH (shielded) ────────────────────────
    /// @notice Transfer sETH to another address.
    ///         Amount is shielded (suint256) so no one can see how much
    ///         was transferred on-chain.
    /// @param to     Recipient address.
    /// @param amount Amount of sETH to transfer (encrypted).
    function transfer(address to, suint256 amount) external {
        require(to != address(0), "Cannot transfer to zero address");
        require(to != msg.sender, "Cannot transfer to yourself");

        // Check sufficient balance (comparison on shielded values)
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[to] = _balances[to] + amount;

        emit Transfer(msg.sender, to);
    }

    // ── Redeem: sETH → ETH ──────────────────────────────────────
    /// @notice Burn sETH and receive ETH at the specified address.
    ///         The amount to redeem is shielded.
    /// @param to     Address to receive the ETH (can be different wallet).
    /// @param amount Amount of sETH to redeem (encrypted).
    function redeem(address payable to, suint256 amount) external {
        require(to != address(0), "Cannot redeem to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;

        // Convert shielded amount to plain uint256 for the ETH transfer
        uint256 plainAmount = uint256(amount);
        _totalSupply -= plainAmount;

        // Send ETH to the target address
        (bool success, ) = to.call{value: plainAmount}("");
        require(success, "ETH transfer failed");

        emit Redeem(msg.sender, to, plainAmount);
    }

    // ── Shielded Read: Balance (owner-only via msg.sender) ───────
    /// @notice Get your own sETH balance. Only callable by the balance owner.
    ///         Uses signed read — msg.sender proves identity.
    function getBalance() external view returns (uint256) {
        return uint256(_balances[msg.sender]);
    }

    // ── Public Reads ─────────────────────────────────────────────
    /// @notice Get total sETH supply (not shielded).
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Get the ETH held by this contract.
    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ── Receive ETH directly ─────────────────────────────────────
    receive() external payable {
        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}
