// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {DammHook} from "../src/DammHook.sol";
import {DammOracle} from "../src/DammOracle.sol";

contract DammHookTest is Test {
    DammHook dammHook;
    DammOracle dammOracle;

    struct NewHookData {
        address sender;
        bytes hookData;
    }

    struct BeforeSwapDelta {
        uint256 delta0;
        uint256 delta1;
    }

    function setUp() public {
        // Deploy the mock oracle
        dammOracle = new DammOracle();
        // Deploy the DammHook contract with the mock oracle address
        dammHook = new DammHook(address(dammOracle));
    }

    function testBeforeSwap() public {
        // Mock data
        address sender = address(this);
        IPoolManager.PoolKey memory key = IPoolManager.PoolKey({
            // Initialize with mock data
            token0: address(0),
            token1: address(0),
            fee: 0
        });
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            amountSpecified: 1000,
            sqrtPriceLimitX96: 0,
            recipient: address(0),
            deadline: block.timestamp
        });
        bytes memory hookData = abi.encode(NewHookData({
            sender: sender,
            hookData: abi.encode(500)
        }));

        // Set mock oracle data
        dammOracle.setOrderBookPressure(2000);

        // Call the beforeSwap function
        (bytes4 resultBytes4, BeforeSwapDelta memory resultDelta, uint24 resultFee) = dammHook.beforeSwap(
            sender,
            key,
            params,
            hookData
        );

        // Assertions
        bytes4 expectedBytes4 = 0x12345678; // Replace with expected value
        BeforeSwapDelta memory expectedDelta = BeforeSwapDelta({
            delta0: 0,
            delta1: 0
        });
        uint24 expectedFee = 1000; // Replace with expected value

        assertEq(resultBytes4, expectedBytes4, "Incorrect bytes4 returned");
        assertEq(resultDelta.delta0, expectedDelta.delta0, "Incorrect BeforeSwapDelta delta0 returned");
        assertEq(resultDelta.delta1, expectedDelta.delta1, "Incorrect BeforeSwapDelta delta1 returned");
        assertEq(resultFee, expectedFee, "Incorrect uint24 returned");
    }
}