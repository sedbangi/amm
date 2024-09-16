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

    PriorityFeeAndPriceReturnVolatilitySimulator public simulator;

    // State variables
    mapping(uint256 => uint256) public pricesBefore;
    mapping(uint256 => uint256) public pricesAfter;

    constructor(address simulatorAddress) {
        // volatilityCalculator = new PriorityFeeAndPriceReturnVolatilitySimulator(100);
        simulator = PriorityFeeAndPriceReturnVolatilitySimulator(simulatorAddress);
    }

    function getOffchainMidPrice() public view returns(uint256 offChainMidPrice) {
        return OFF_CHAIN_MID_PRICE_ETH_USDT;
    }

    function callGenerateDataAndCalculateVolatilities() public returns (uint256, uint256) {
        return simulator.generateDataAndCalculateVolatilities();
    }

    function getOrderBookPressure() public view returns (uint256) {
        uint256 bidSize = random(1, 1000, 0);
        console.log("getOrderBookPressure | bid size:", bidSize);
        uint256 bidPrice = OFF_CHAIN_MID_PRICE_ETH_USDT * (HUNDRED_PERCENT - HALF_SPREAD) / HUNDRED_PERCENT;

        console.log("getOrderBookPressure | bid price:", bidPrice);
        uint256 askPrice = OFF_CHAIN_MID_PRICE_ETH_USDT * (HUNDRED_PERCENT + HALF_SPREAD) / HUNDRED_PERCENT;
        console.log("getOrderBookPressure | ask price:", askPrice);
        uint256 askSize = random(1, 1000, 1);
        console.log("getOrderBookPressure | ask size:", askSize);
        return (askSize * askPrice - bidSize * bidPrice) * 1000 / (askSize * askPrice + bidSize * bidPrice);
    }
    
    // Function to set prices for testing purposes
    function setPrices(uint256 blockId, uint256 priceBefore, uint256 priceAfter) public {
        pricesBefore[blockId] = priceBefore;
        pricesAfter[blockId] = priceAfter;
    }

     function getPriceVolatility() public pure returns (uint256) {
        // Use integer arithmetic to approximate 0.1 / sqrt(86400 / 13)
        uint256 numerator = 1; // 0.1 scaled by 10
        uint256 denominator = sqrt(uint256(86400) / 13) * 10; // Scale the denominator by 10
        return numerator * 1e18 / denominator; // Scale the result by 1e18 for precision
    }


    function getPriorityFeeVolatility() public view returns (uint256) {
        return simulator.getPriorityFeeVolatility();
    }

    /*
    function getPriorityFeeVolatility() public view returns (uint256) {
        return volatilityCalculator.getPriorityFeeVolatility();
    }
    */

    function random(uint256 min, uint256 max, uint256 nonce) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, nonce))) % (max - min + 1) + min;
    }

    function getPrices(uint256 blockId) external view returns (uint256 priceBeforePreviousBlock, uint256 priceAfterPreviousBlock) {
        uint256 priceVolatility = getPriceVolatility();
        uint256 basePrice = 1000;
        priceBeforePreviousBlock = basePrice + random(0, priceVolatility, 4);
        priceAfterPreviousBlock = basePrice + random(0, priceVolatility, 5);
        return (priceBeforePreviousBlock, priceAfterPreviousBlock);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}