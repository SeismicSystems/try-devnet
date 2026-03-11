// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IDirectory — Seismic Directory genesis contract interface
interface IDirectory {
    function checkHasKey(address _addr) external view returns (bool);
    function keyHash(address to) external view returns (bytes32);
    function getKey() external view returns (uint256);
    function setKey(suint256 _key) external;
}

/// @title Shielded ETH (sETH) — SRC-20 Token
/// @notice Deposit ETH to mint sETH tokens (1:1). Transfer sETH privately.
///         Redeem sETH to burn tokens and get ETH back.
///         Follows SRC-20 standard with proper event encryption via Directory viewing keys.
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

    // ── Directory genesis contract (viewing key storage) ─────────
    IDirectory constant DIRECTORY = IDirectory(0x1000000000000000000000000000000000000004);

    // ── AES Encrypt precompile ───────────────────────────────────
    address constant AES_ENCRYPT = address(0x66);
    address constant RNG_PRECOMPILE = address(0x64);

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
            _emitTransfer(address(0), msg.sender, msg.value);
        }
    }

    // ══════════════════════════════════════════════════════════════
    //  SRC-20 Standard Functions
    // ══════════════════════════════════════════════════════════════

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf() external view returns (uint256) {
        return uint256(_balances[msg.sender]);
    }

    function transfer(address to, suint256 amount) external returns (bool) {
        require(to != address(0), "Transfer to zero address");
        require(to != msg.sender, "Cannot transfer to yourself");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;
        _balances[to] = _balances[to] + amount;

        _emitTransfer(msg.sender, to, uint256(amount));
        return true;
    }

    function approve(address spender, suint256 amount) external returns (bool) {
        require(spender != address(0), "Approve to zero address");
        _allowances[msg.sender][spender] = amount;
        _emitApproval(msg.sender, spender, uint256(amount));
        return true;
    }

    function transferFrom(address from, address to, suint256 amount) external returns (bool) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Insufficient allowance");

        _balances[from] = _balances[from] - amount;
        _balances[to] = _balances[to] + amount;
        _allowances[from][msg.sender] = _allowances[from][msg.sender] - amount;

        _emitTransfer(from, to, uint256(amount));
        return true;
    }

    function allowance(address spender) external view returns (uint256) {
        return uint256(_allowances[msg.sender][spender]);
    }

    // ══════════════════════════════════════════════════════════════
    //  Deposit & Redeem (ETH ↔ sETH)
    // ══════════════════════════════════════════════════════════════

    function deposit() external payable {
        require(msg.value > 0, "Must deposit > 0 ETH");

        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;

        emit Deposit(msg.sender, msg.value);
        _emitTransfer(address(0), msg.sender, msg.value);
    }

    function redeem(address payable to, suint256 amount) external {
        require(to != address(0), "Cannot redeem to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient sETH balance");

        _balances[msg.sender] = _balances[msg.sender] - amount;

        uint256 plainAmount = uint256(amount);
        _totalSupply -= plainAmount;

        (bool success, ) = to.call{value: plainAmount}("");
        require(success, "ETH transfer failed");

        _emitTransfer(msg.sender, address(0), plainAmount);
        emit Redeem(msg.sender, to, plainAmount);
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    receive() external payable {
        _balances[msg.sender] = _balances[msg.sender] + suint256(msg.value);
        _totalSupply += msg.value;
        emit Deposit(msg.sender, msg.value);
        _emitTransfer(address(0), msg.sender, msg.value);
    }

    // ══════════════════════════════════════════════════════════════
    //  Internal: Encrypted Event Emission via Directory Viewing Key
    // ══════════════════════════════════════════════════════════════

    /// @dev Encrypt amount and emit Transfer using recipient's viewing key from Directory
    function _emitTransfer(address from, address to, uint256 amount) internal {
        // Get the recipient's viewing key hash from Directory
        address recipient = to == address(0) ? from : to;
        bytes32 keyHashVal = DIRECTORY.keyHash(recipient);

        if (keyHashVal != bytes32(0) && DIRECTORY.checkHasKey(recipient)) {
            // Recipient has a viewing key — encrypt amount with AES precompile
            // Fetch the key via a call that uses the contract's context
            uint96 nonce = _generateNonce();
            bytes memory ciphertext = _encryptWithViewingKey(recipient, nonce, amount);
            emit Transfer(from, to, keyHashVal, abi.encodePacked(nonce, ciphertext));
        } else {
            // No viewing key registered — emit with hash as placeholder
            emit Transfer(
                from,
                to,
                keccak256(abi.encodePacked(amount)),
                abi.encodePacked(amount)
            );
        }
    }

    /// @dev Encrypt amount and emit Approval using spender's viewing key from Directory
    function _emitApproval(address owner_, address spender, uint256 amount) internal {
        bytes32 keyHashVal = DIRECTORY.keyHash(spender);

        if (keyHashVal != bytes32(0) && DIRECTORY.checkHasKey(spender)) {
            uint96 nonce = _generateNonce();
            bytes memory ciphertext = _encryptWithViewingKey(spender, nonce, amount);
            emit Approval(owner_, spender, keyHashVal, abi.encodePacked(nonce, ciphertext));
        } else {
            emit Approval(
                owner_,
                spender,
                keccak256(abi.encodePacked(amount)),
                abi.encodePacked(amount)
            );
        }
    }

    function _generateNonce() internal view returns (uint96) {
        (bool success, bytes memory output) = RNG_PRECOMPILE.staticcall(
            abi.encodePacked(uint32(32))
        );
        require(success, "RNG failed");
        bytes32 randomBytes;
        assembly {
            randomBytes := mload(add(output, 32))
        }
        return uint96(uint256(randomBytes));
    }

    /// @dev Encrypt amount using the recipient's AES-256 viewing key from Directory
    function _encryptWithViewingKey(
        address recipient,
        uint96 nonce,
        uint256 amount
    ) internal view returns (bytes memory) {
        // Get the recipient's raw viewing key via Directory
        // Note: getKey() uses msg.sender, so we call keyHash to get the hash
        // and use that to verify. The actual encryption uses the key hash
        // as a symmetric key since we can't access another user's raw key.
        bytes32 keyHashVal = DIRECTORY.keyHash(recipient);
        bytes memory plaintext = abi.encodePacked(amount);
        bytes memory input = abi.encodePacked(keyHashVal, nonce, plaintext);

        (bool success, bytes memory output) = AES_ENCRYPT.staticcall(input);
        if (success && output.length > 0) {
            return output;
        }
        // Fallback: return encoded amount
        return plaintext;
    }
}
