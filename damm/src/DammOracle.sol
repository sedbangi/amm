// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/console.sol";
import {PriorityFeeAndPriceReturnVolatilitySimulator} from "../src/PriorityFeeAndPriceReturnVolatilitySimulator.sol";
import {MevClassifier} from "../src/MevClassifier.sol";

contract DammOracle {
    uint256 public OFF_CHAIN_MID_PRICE_ETH_USDT = 2200;
    uint256 public HALF_SPREAD = 5000;
    uint256 constant HUNDRED_PERCENT = 1_000_000;
    uint256 constant SCALING_FACTOR = 10**18;
    uint256 public SqrtX96Price;

    PriorityFeeAndPriceReturnVolatilitySimulator public volatilityCalculator;

    // State variables
    mapping(uint256 => uint256) public pricesBefore;
    mapping(uint256 => uint256) public pricesAfter;

    constructor() {
        volatilityCalculator = new PriorityFeeAndPriceReturnVolatilitySimulator();
    }

    function getOffchainMidPrice() public view returns(uint256 offChainMidPrice) {
        return OFF_CHAIN_MID_PRICE_ETH_USDT;
    }

    function getOrderBookPressure() public view returns (uint256) {
        uint256 bidSize = random(1, 1000);
        console.log("getOrderBookPressure | bid size:", bidSize);
        uint256 bidPrice = OFF_CHAIN_MID_PRICE_ETH_USDT * (HUNDRED_PERCENT - HALF_SPREAD) / HUNDRED_PERCENT;

        console.log("getOrderBookPressure | bid price:", bidPrice);
        uint256 askPrice = OFF_CHAIN_MID_PRICE_ETH_USDT * (HUNDRED_PERCENT + HALF_SPREAD) / HUNDRED_PERCENT;
        console.log("getOrderBookPressure | ask price:", askPrice);
        uint256 askSize = random(1, 1000);
        console.log("getOrderBookPressure | ask size:", askSize);
        return (askSize * askPrice - bidSize * bidPrice) * 1000 / (askSize * askPrice + bidSize * bidPrice);
    }
    
    // Function to set prices for testing purposes
    function setPrices(uint256 blockId, uint256 priceBefore, uint256 priceAfter) public {
        pricesBefore[blockId] = priceBefore;
        pricesAfter[blockId] = priceAfter;
    }

    // Function to get prices
    function getPrices(uint256 blockId) public view returns (uint256, uint256) {
        return (pricesBefore[blockId], pricesAfter[blockId]);
    }
    }

    function getPriceVolatility() public view returns (uint256) {
        return volatilityCalculator.getPriceVolatility();
    }

    function getPriorityFeeVolatility() public view returns (uint256) {
        return volatilityCalculator.getPriorityFeeVolatility();
    }

    function random(uint256 min, uint256 max) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (max - min + 1) + min;
    }

    // function getPrices(uint256 blockId) external view returns (uint256 priceBeforePreviousBlock, 
    //                                                            uint256 priceAfterPreviousBlock) {
    //     // Simulate fetching two consecutive prices from Gbm
    //     // uint256 priceVolatility = getPriceVolatility(); 
    //     uint256 priceVolatility = 0.1 / sqrt(86400/13);
    //     uint256 basePrice = 1000; // Example base price
    //     // Simulate price before the previous block
    //     priceBeforePreviousBlock = basePrice + random(0, priceVolatility);
    //     // Simulate price after the previous block
    //     priceAfterPreviousBlock = basePrice + random(0, priceVolatility);
    //     return (priceBeforePreviousBlock, priceAfterPreviousBlock);
    // }
}