// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {console} from "forge-std/console.sol";

import {DammHook} from "../src/DammHook.sol";


contract TestDammHook is Test, Deployers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    DammHook hook;
    address swapper0 = address(0xBEEF0);
    address swapper1 = address(0xBEEF1);
    address swapper2 = address(0xBEEF2);

    function setUp() public { 
        // Deploy v4-core
        deployFreshManagerAndRouters();

        // Deploy, mint tokens, and approve all periphery contracts for two tokens
        deployMintAndApprove2Currencies();

        // Deploy our hook with the proper flags
        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_SWAP_FLAG |
                    Hooks.AFTER_SWAP_FLAG
            )
        );

        // Set gas price = 10 gwei and deploy our hook
        vm.txGasPrice(10 gwei);
        deployCodeTo("DammHook", abi.encode(manager), hookAddress);
        hook = DammHook(hookAddress);

        // Initialize a pool
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            LPFeeLibrary.DYNAMIC_FEE_FLAG, // Set the `DYNAMIC_FEE_FLAG` in place of specifying a fixed fee
            SQRT_PRICE_1_1,
            ZERO_BYTES
        );

        // Add some liquidity
        modifyLiquidityRouter.modifyLiquidity(
            key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: -120,
                tickUpper: 120,
                liquidityDelta: 10000 ether,
                salt: bytes32(0)
            }),
            ZERO_BYTES
        );
    }

    function testBeforeSwapAndCalculateCombinedFee() public {
        key.currency0.transfer(address(this), 10e18);
        key.currency1.transfer(address(this), 10e18);

        key.currency0.transfer(address(hook), 10e18);
        key.currency1.transfer(address(hook), 10e18);

        key.currency0.transfer(address(swapper0), 10e18);
        key.currency1.transfer(address(swapper0), 10e18);

        key.currency0.transfer(address(swapper1), 10e18);
        key.currency1.transfer(address(swapper1), 10e18);

        key.currency0.transfer(address(swapper2), 15e18);
        key.currency1.transfer(address(swapper2), 15e18);

        console.log("testBeforeSwap | --- STARTING BALANCES ---");

        uint256 swapper0BalanceBefore0 = currency0.balanceOf(address(swapper0));
        uint256 swapper0BalanceBefore1 = currency1.balanceOf(address(swapper0));

        uint256 swapper1BalanceBefore0 = currency0.balanceOf(address(swapper1));
        uint256 swapper1BalanceBefore1 = currency1.balanceOf(address(swapper1));

        uint256 swapper2BalanceBefore0 = currency0.balanceOf(address(swapper2));
        uint256 swapper2BalanceBefore1 = currency1.balanceOf(address(swapper2));

        console.log("testBeforeSwap | Swapper address 0: ", address(swapper0));
        console.log("testBeforeSwap | Swapper address 1: ", address(swapper1));
        console.log("testBeforeSwap | Swapper address 2: ", address(swapper2));
        console.log("testBeforeSwap | Swapper address 0 balance in currency0 before swapping: ", swapper0BalanceBefore0);
        console.log("testBeforeSwap | Swapper address 0 balance in currency1 before swapping: ", swapper0BalanceBefore1);
        console.log("testBeforeSwap | Swapper address 1 balance in currency0 before swapping: ", swapper1BalanceBefore0);
        console.log("testBeforeSwap | Swapper address 1 balance in currency1 before swapping: ", swapper1BalanceBefore1);
        console.log("testBeforeSwap | Swapper address 2 balance in currency0 before swapping: ", swapper2BalanceBefore0);
        console.log("testBeforeSwap | Swapper address 2 balance in currency1 before swapping: ", swapper2BalanceBefore1);

        // Set up our swap parameters
        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest
            .TestSettings({takeClaims: false, settleUsingBurn: false});
        vm.envBool("FORGE_SNAPSHOT_CHECK");
        vm.txGasPrice(4 gwei);

        uint256 combinedFee = hook.publicCalculateCombinedFee(1000, address(swapper1), true);
        console.log("testBeforeSwap | --- Combined Fee for first transaction in pool for block", combinedFee);
        console.log("testBeforeSwap | --- BASE Fee", hook.getBaseFee());
        // assert(combinedFee > 0);

        // Test if MeV Flag is True
        // Test if MeV Flag is False
        
        // Test if first transaction for pool in block is False
        combinedFee = hook.publicCalculateCombinedFee(1000, address(swapper1), false);
        console.log("testBeforeSwap | --- Combined Fee For NON-frirst transaction", combinedFee);
        console.log("testBeforeSwap | --- BASE Fee", hook.getBaseFee());
       
    }
}