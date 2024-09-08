// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20TokenWithLock is ERC20, Ownable {
    // Mapping to keep track of locked balances
    mapping(address => uint256) private _lockedBalances;
    // Mapping to keep track of unlocked balances
    mapping(address => uint256) private _unlockedBalances;

    // Event to signal that tokens have been unlocked
    event TokensUnlocked(address indexed account, uint256 amount);

    // Struct to store transaction details
    struct Transaction {
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
    }

    // Array to store the last three transactions
    Transaction[3] private lastThreeTransactions;

    constructor(uint256 initialSupply) ERC20("MyToken", "MTK") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }

    // Mint function that locks the minted tokens
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(address(this), amount); // Mint tokens to the contract itself
        _lockedBalances[to] += amount; // Lock the tokens for the recipient
    }

    // Function to unlock tokens
    function unlockTokens(address account) public onlyOwner {
        uint256 lockedAmount = _lockedBalances[account];
        require(lockedAmount > 0, "No tokens to unlock");

        _lockedBalances[account] = 0;
        _unlockedBalances[account] += lockedAmount;

        emit TokensUnlocked(account, lockedAmount);
    }

    // Override the transfer function to include locked balance check and track transactions
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        require(balanceOf(from) - _lockedBalances[from] >= amount, "Transfer amount exceeds unlocked balance");
        super._beforeTokenTransfer(from, to, amount);

        // Track the transaction
        _trackTransaction(from, to, amount);
    }

    // Function to get the locked balance of an account
    function lockedBalanceOf(address account) public view returns (uint256) {
        return _lockedBalances[account];
    }

    // Function to get the unlocked balance of an account
    function unlockedBalanceOf(address account) public view returns (uint256) {
        return balanceOf(account) - _lockedBalances[account];
    }

    // Function to track the last three transactions
    function _trackTransaction(address from, address to, uint256 amount) internal {
        // Shift the transactions
        lastThreeTransactions[2] = lastThreeTransactions[1];
        lastThreeTransactions[1] = lastThreeTransactions[0];
        lastThreeTransactions[0] = Transaction(from, to, amount, block.timestamp);
    }

    // Function to check if the first transaction was an MEV transaction
    function isMEVTransaction() public view returns (bool) {
        // Check if the second transaction had high slippage
        bool highSlippage = _checkHighSlippage(lastThreeTransactions[1]);

        // Check if the third transaction reverses the first transaction
        bool reversesFirstTransaction = _checkReversesFirstTransaction(lastThreeTransactions[2], lastThreeTransactions[0]);

        return highSlippage && reversesFirstTransaction;
    }

    // Function to check if a transaction had high slippage
    function _checkHighSlippage(Transaction memory txn) internal view returns (bool) {
        // Implement your logic to check high slippage
        // For example, you can compare the transaction amount with a threshold
        uint256 slippageThreshold = 1000 * 10 ** decimals(); // Example threshold
        return txn.amount > slippageThreshold;
    }

    // Function to check if a transaction reverses the first transaction
    function _checkReversesFirstTransaction(Transaction memory txn1, Transaction memory txn2) internal view returns (bool) {
        return txn1.from == txn2.to && txn1.to == txn2.from && txn1.amount == txn2.amount;
    }
}
