// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AMM.sol";

contract SwapContract is Ownable {
    IERC20 public token0;
    IERC20 public token1;
    AMM public amm;
    uint256 public swapCount;

    event SwapWithBid(address indexed swapper, uint256 amountIn, uint256 amountOut, bool bidSubmitted);
    event SwapWithoutBid(address indexed swapper, uint256 amountIn, uint256 amountOut);
    event SwapWithBidNoAmount(address indexed swapper, bool bidSubmitted);

    constructor(address _token0, address _token1, address _amm) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        amm = AMM(_amm);
        swapCount = 0;
    }

    function createSwapsWithBids(uint256 amountIn, uint256 amountOut, uint256 efficientOffChainPrice, uint256 submittedFee, uint256 blockId, uint256 gasCost, bool informed) external onlyOwner {
        for (uint256 i = 0; i < 10; i++) {
            token0.transferFrom(msg.sender, address(this), amountIn);
            token1.transfer(msg.sender, amountOut);
            (uint256 x, uint256 y, uint256 fee) = amm.tradeToPriceWithGasFee(efficientOffChainPrice, submittedFee, msg.sender, blockId, gasCost, informed);
            emit SwapWithBid(msg.sender, x, y, true);
            swapCount++;
        }
    }

    function createSwapsWithoutBids(uint256 amountIn, uint256 amountOut, uint256 efficientOffChainPrice, uint256 blockId, uint256 gasCost, bool informed) external onlyOwner {
        for (uint256 i = 0; i < 10; i++) {
            token0.transferFrom(msg.sender, address(this), amountIn);
            token1.transfer(msg.sender, amountOut);
            (uint256 x, uint256 y, uint256 fee) = amm.tradeToPriceWithGasFee(efficientOffChainPrice, 0, msg.sender, blockId, gasCost, informed);
            emit SwapWithoutBid(msg.sender, x, y);
            swapCount++;
        }
    }

    function createSwapsWithBidsNoAmount(uint256 efficientOffChainPrice, uint256 submittedFee, uint256 blockId, uint256 gasCost, bool informed) external onlyOwner {
        for (uint256 i = 0; i < 10; i++) {
            (uint256 x, uint256 y, uint256 fee) = amm.tradeToPriceWithGasFee(efficientOffChainPrice, submittedFee, msg.sender, blockId, gasCost, informed);
            emit SwapWithBidNoAmount(msg.sender, true);
            swapCount++;
        }
    }
}
