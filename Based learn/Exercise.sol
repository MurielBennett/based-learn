// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract UnburnableToken {
    // (не используется, оставил только если тебе надо под форму задания)
    string private salt = "value";

    uint256 public constant TOTAL_SUPPLY = 100_000_000;
    uint256 public constant CLAIM_AMOUNT = 1_000;

    mapping(address => uint256) public balances;
    uint256 public totalClaimed;
    mapping(address => bool) private claimed;

    // Custom errors
    error TokensClaimed();
    error AllTokensClaimed();
    error UnsafeTransfer(address to);
    error InsufficientBalance(uint256 have, uint256 need);

    event Claimed(address indexed account, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function claim() external {
        if (claimed[msg.sender]) revert TokensClaimed();

        // не даём перепрыгнуть лимит
        if (totalClaimed + CLAIM_AMOUNT > TOTAL_SUPPLY) revert AllTokensClaimed();

        claimed[msg.sender] = true;
        balances[msg.sender] += CLAIM_AMOUNT;
        totalClaimed += CLAIM_AMOUNT;

        emit Claimed(msg.sender, CLAIM_AMOUNT);
    }

    function safeTransfer(address to, uint256 amount) external {
        // твоя логика "unsafe": нельзя в нулевой адрес и нельзя адресам без нативного баланса
        if (to == address(0) || to.balance == 0) revert UnsafeTransfer(to);

        uint256 fromBal = balances[msg.sender];
        if (fromBal < amount) revert InsufficientBalance(fromBal, amount);

        unchecked {
            balances[msg.sender] = fromBal - amount;
            balances[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
    }

    // Если хочешь проверять статус клейма (не обязательно)
    function hasClaimed(address account) external view returns (bool) {
        return claimed[account];
    }
}