// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";

 import {DammOracle} from "../src/DammOracle.sol";
import {DammHook} from "../src/DammHook.sol";
import {console} from "forge-std/console.sol";

contract DammHook is BaseHook {
	// Use CurrencyLibrary and BalanceDeltaLibrary
	// to add some helper functions over the Currency and BalanceDelta
	// data types 
    using BalanceDeltaLibrary for BalanceDelta;
    using LPFeeLibrary for uint24;

    DammOracle dammOracle;

    // Keeping track of the moving average gas price
    uint128 public movingAverageGasPrice;
    // How many times has the moving average been updated?
    // Needed as the denominator to update it the next time based on the moving average formula
    uint104 public movingAverageGasPriceCount;

	// Keeping track of user => referrer
	mapping(address => address) public referredBy;

	// Amount of points someone gets for referring someone else
    uint256 public constant POINTS_FOR_REFERRAL = 500 * 10 ** 18;

    // The default base fees we will charge
    uint24 public constant BASE_FEE = 3000; // 0.3%

    error MustUseDynamicFee();

    mapping(address => uint256) public informedTraders;

    // DammOracle dammOracle;

    // Initialize BaseHook parent contract in the constructor
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        dammOracle = new DammOracle();
        updateMovingAverage();
    }

	// Set up hook permissions to return `true`
	// for the two hook functions we are using
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    function beforeInitialize(
        address,
        PoolKey calldata key,
        uint160,
        bytes calldata
    ) external pure override returns (bytes4) {
        // `.isDynamicFee()` function comes from using
        // the `SwapFeeLibrary` for `uint24`
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        return this.beforeInitialize.selector;
    }

    // TODO external override onlyByPoolManager
    function beforeSwap(
                address sender, 
                PoolKey calldata key, 
                IPoolManager.SwapParams calldata params, 
                bytes calldata hookData
            )   external override
                returns (bytes4, BeforeSwapDelta, uint24)
            {
                uint256 submittedFee;
                uint256 blockNumber = uint256(block.number);
                int256 amountToSwap = params.amountSpecified;
                uint256 poolFee;

                uint24 fee = BASE_FEE;
                uint256 offChainMidPrice = dammOracle.getOrderBookPressure();

                poolManager.updateDynamicLPFee(key, fee);
                console.log("Blocknumber: ", blockNumber);


            // if (currentBlockId == 0) {
            //     currentBlockId = blockNumber;
            //     beginBlock(blockNumber, efficientOffChainPrice);
            // } else if (currentBlockId != blockId) {
            //     endBlock();
            //     currentBlockId = blockNumber;
            //     beginBlock(blockNumber, efficientOffChainPrice);
            // }

            // if (currentBlockId == 0) {
            //     poolFee = 1 + BASE_FEE;
            // } else {
            //     uint256 delta = calculateCombinedFee(blockNumber, sender).sub(BASE_FEE);
            //     poolFee = poolFee.add(delta);
            // }

            // uint256 currentAMMPrice = sqrtPrice.mul(sqrtPrice);
            // (uint256 ammBidPrice, uint256 ammAskPrice) = getBidAndAskOfAMM(currentAMMPrice);

            // if (submittedFee < 0) {
            //     revert("Submitted fee must be non-negative.");
            // } else if (submittedFee >= BASE_FEE) {
            //     revert("Submitted fee cannot exceed base fee.");
            // } else {
            //     listSubmittedFees.push(submittedFee);
            //     previousBlockSwappers[sender] = true;
            //     setOfIntendToTradeSwapperSignalledInPreviousBlock[sender] = true;
            // }

            // if (informedTraders[sender]) {
            //     if (ammAskPrice > efficientOffChainPrice && ammBidPrice < efficientOffChainPrice) {
            //         return (0, 0, 0);
            //     }
            // }

            // uint256 x;
            // uint256 y;
            // uint256 fee;
            // if (ammAskPrice < efficientOffChainPrice) {
            //     uint256 _fee = 1 + poolFee;
            //     uint256 newSqrtPrice = sqrt(efficientOffChainPrice.div(_fee));
            //     (x, y, fee) = buyXTokensForYTokens(newSqrtPrice, _fee);
            // } else if (ammBidPrice > efficientOffChainPrice) {
            //     uint256 _fee = 1 + poolFee;
            //     uint256 newSqrtPrice = sqrt(efficientOffChainPrice.mul(2).sub(_fee));
            //     (x, y, fee) = sellXTokensForYTokens(newSqrtPrice, _fee);
            // }

            // if (tx.gas > x.mul(efficientOffChainPrice).add(y)) {
            //     revert("Gas cost cannot exceed the total value of the trade.");
            // } else {
            //     sqrtPrice = sqrt(efficientOffChainPrice);
            // }

            // emit TokensSwapped(swapperId, x, y, fee);
            return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(
        address,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        updateMovingAverage();
        return (this.afterSwap.selector, 0);
    }


    function getFee() internal view returns (uint24) {
        uint128 gasPrice = uint128(tx.gasprice);

        // if gasPrice > movingAverageGasPrice * 1.1, then half the fees
        if (gasPrice > (movingAverageGasPrice * 11) / 10) {
            return BASE_FEE / 2;
        }

        // if gasPrice < movingAverageGasPrice * 0.9, then double the fees
        if (gasPrice < (movingAverageGasPrice * 9) / 10) {
            return BASE_FEE * 2;
        }

        return BASE_FEE;
    }

    // Update our moving average gas price
    function updateMovingAverage() internal {
        uint128 gasPrice = uint128(tx.gasprice);

        // New Average = ((Old Average * # of Txns Tracked) + Current Gas Price) / (# of Txns Tracked + 1)
        movingAverageGasPrice =
            ((movingAverageGasPrice * movingAverageGasPriceCount) + gasPrice) /
            (movingAverageGasPriceCount + 1);

        movingAverageGasPriceCount++;
    }
}