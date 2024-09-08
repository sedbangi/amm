// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/AMM.sol";

contract TestAMM is Test {
    AMM public amm;

    function setUp() public {
        amm = new AMM(100, 16666667, 0.003 ether, 0.5 ether, 2 ether, 0.5 ether, 0.95 ether);
    }

    function testInitialization() public {
        assertEq(amm.sqrtPrice(), sqrt(100 ether));
        assertEq(amm.L(), 16666667);
        assertEq(amm.baseFee(), 0.003 ether);
        assertEq(amm.m(), 0.5 ether);
        assertEq(amm.n(), 2 ether);
        assertEq(amm.alpha(), 0.5 ether);
        assertEq(amm.intentThreshold(), 0.95 ether);
        assertEq(amm.priceBeforePreviousBlock(), 100 ether * 995 / 1000);
        assertEq(amm.priceAfterPreviousBlock(), 100 ether);
        assertEq(amm.slippage(), 0);
        assertEq(amm.cutOffPercentile(), 0.85 ether);
        assertTrue(amm.firstTransaction());
        assertEq(amm.totalBlocks(), 0);
        assertEq(amm.listSubmittedFees().length, 0);
        assertEq(amm.setOfIntendToTradeSwapperSignalledInPreviousBlock().length, 0);
        assertEq(amm.setIntendToTradeNextBlock().length, 0);
    }

    function testAddLiquidity() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        (uint256 lower, uint256 upper, uint256 amount) = amm.liquidityRanges(0);
        assertEq(lower, 90 ether);
        assertEq(upper, 110 ether);
        assertEq(amount, 1000 ether);
    }

    function testEndogenousDynamicFee() public {
        amm.setPriceAfterPreviousBlock(105 ether);
        amm.setPriceBeforePreviousBlock(100 ether);
        uint256 fee = amm.endogenousDynamicFee(1 ether);
        assertEq(fee, 0.003 ether + 0.05 ether * 0.01 ether);
    }

    function testExogenousDynamicFee() public {
        amm.setListSubmittedFees([0.003 ether, 0.004 ether, 0.005 ether]);
        uint256 fee = amm.exogenousDynamicFee();
        assertEq(fee, 0.004 ether + 2 * 0.001 ether);
    }

    function testCalculateCombinedFee() public {
        amm.setPriceAfterPreviousBlock(105 ether);
        amm.setPriceBeforePreviousBlock(100 ether);
        amm.setListSubmittedFees([0.003 ether, 0.004 ether, 0.005 ether]);
        uint256 fee = amm.calculateCombinedFee(1 ether);
        uint256 expectedFee = 0.5 ether * (0.003 ether + 0.05 ether * 0.01 ether) + 0.5 ether * (0.004 ether + 2 * 0.001 ether);
        assertEq(fee, expectedFee);
    }

    function testBuyXTokensForYTokens() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        (uint256 x, uint256 y, uint256 fee) = amm.buyXTokensForYTokens(sqrt(105 ether), 1.003 ether);
        assertGt(x, 0);
        assertGt(y, 0);
        assertGt(fee, 0);
    }

    function testSellXTokensForYTokens() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        (uint256 x, uint256 y, uint256 fee) = amm.sellXTokensForYTokens(sqrt(95 ether), 1.003 ether);
        assertGt(x, 0);
        assertGt(y, 0);
        assertGt(fee, 0);
    }

    function testCalculateAmountXTokensInvolvedInSwap() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        uint256 amountX = amm.calculateAmountXTokensInvolvedInSwap(sqrt(105 ether));
        assertGt(amountX, 0);
    }

    function testCalculateAmountOfYTokensInvolvedInSwap() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        uint256 amountY = amm.calculateAmountOfYTokensInvolvedInSwap(sqrt(105 ether));
        assertLt(amountY, 0);
    }

    function testGetBidAndAskOfAMM() public {
        (uint256 bid, uint256 ask) = amm.getBidAndAskOfAMM(100 ether);
        assertEq(bid, 100 ether * (2 ether - 1.003 ether));
        assertEq(ask, 100 ether * 1.003 ether);
    }

    function testTradeToPriceWithGasFee() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        (uint256 x, uint256 y, uint256 fee) = amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, address(0), 1 ether, 0, true);
        assertGe(x, 0);
        assertGe(y, 0);
        assertGe(fee, 0);
    }

    function testSubmittedFeeCannotBeNegative() public {
        vm.expectRevert("Fee cannot be negative");
        amm.tradeToPriceWithGasFee(105 ether, -0.001 ether, address(0), 1 ether, 0, true);
    }

    function testSubmittedFeeCannotExceedBaseFee() public {
        vm.expectRevert("Fee exceeds base fee");
        amm.tradeToPriceWithGasFee(105 ether, amm.baseFee() * 4, address(0), 1 ether, 0, true);
    }

    function testAsymmetricFeeCannotBeNegative() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        (uint256 x, uint256 y, uint256 fee) = amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, address(0), 1 ether, 0, true);
        assertGe(fee, 0);
    }

    function testLPAddressesCannotPostBids() public {
        address lpAddress = address(0x123);
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        vm.expectRevert("LPs cannot post bids");
        amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, lpAddress, 1 ether, 0, true);
    }

    function testMEVTransactionRefund() public {
        address mevSwapper = address(0x456);
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, mevSwapper, 1 ether, 0, true);
        amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, address(0), 2 ether, 0, true);
        amm.tradeToPriceWithGasFee(100 ether, 0.003 ether, address(0), 3 ether, 0, true);
        assertTrue(amm.refundedSwappers(mevSwapper));
    }

    function testIdentifyMEVTransaction() public {
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);
        amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, address(0x1), 1 ether, 0, true);
        amm.tradeToPriceWithGasFee(110 ether, 0.003 ether, address(0x2), 2 ether, 0, true);
        amm.tradeToPriceWithGasFee(100 ether, 0.003 ether, address(0x3), 3 ether, 0, true);
        assertTrue(amm.isMEVTransaction(address(0x1)));
    }

    function testGasFeesLessThanGain() public {
        // Add initial liquidity
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);

        // Track initial balance of the liquidity provider
        address lp = address(this);
        uint256 initialBalance = lp.balance;

        // Perform a trade and measure gas fees
        uint256 gasStart = gasleft();
        (uint256 x, uint256 y, uint256 fee) = amm.tradeToPriceWithGasFee(105 ether, 0.003 ether, lp, 1 ether, 0, true);
        uint256 gasUsed = gasStart - gasleft();
        uint256 gasCost = gasUsed * tx.gasprice;

        // Calculate the gain from the AMM
        uint256 finalBalance = lp.balance;
        uint256 gain = finalBalance - initialBalance;

        // Ensure that the gas fees are less than the gain
        assertTrue(gain > gasCost, "Gas fees should be less than the gain from the AMM");
    }

    function testNoNegativeOrExcessiveBids() public {
        // Add initial liquidity
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);

        // Submit bids in block t-1
        uint256[] memory bids = new uint256[](3);
        bids[0] = 0.002 ether;
        bids[1] = 0.003 ether;
        bids[2] = 0.004 ether;
        amm.setListSubmittedFees(bids);

        // Move to block t and accept bids
        vm.roll(block.number + 1);
        uint256[] memory acceptedBids = amm.listSubmittedFees();

        // Check that none of the accepted bids are negative or greater than the base fee
        for (uint256 i = 0; i < acceptedBids.length; i++) {
            assertTrue(acceptedBids[i] >= 0, "Bid should not be negative");
            assertTrue(acceptedBids[i] <= amm.baseFee(), "Bid should not be greater than the base fee");
        }
    }

    function testStrategyProofness() public {
        // Add initial liquidity
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);

        // Submit bids in block t-1
        uint256[] memory bids = new uint256[](3);
        bids[0] = 0.002 ether;
        bids[1] = 0.003 ether;
        bids[2] = 0.004 ether;
        amm.setListSubmittedFees(bids);

        // Move to block t and accept bids
        vm.roll(block.number + 1);
        uint256[] memory acceptedBids = amm.listSubmittedFees();

        // Simulate alternative strategies
        uint256[] memory alternativeBids = new uint256[](3);
        alternativeBids[0] = 0.001 ether; // Lower bid
        alternativeBids[1] = 0.0035 ether; // Higher bid
        alternativeBids[2] = 0.0045 ether; // Higher bid
        amm.setListSubmittedFees(alternativeBids);

        // Move to block t+1 and accept alternative bids
        vm.roll(block.number + 1);
        uint256[] memory alternativeAcceptedBids = amm.listSubmittedFees();

        // Compare outcomes
        for (uint256 i = 0; i < acceptedBids.length; i++) {
            assertTrue(acceptedBids[i] >= alternativeAcceptedBids[i], "Alternative strategy should not be more beneficial");
        }
    }

    function testTruthTelling() public {
        // Add initial liquidity
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);

        // Submit true bids in block t-1
        uint256[] memory trueBids = new uint256[](3);
        trueBids[0] = 0.002 ether;
        trueBids[1] = 0.003 ether;
        trueBids[2] = 0.004 ether;
        amm.setListSubmittedFees(trueBids);

        // Move to block t and accept bids
        vm.roll(block.number + 1);
        uint256[] memory acceptedBids = amm.listSubmittedFees();

        // Check that accepted bids match true bids
        for (uint256 i = 0; i < acceptedBids.length; i++) {
            assertEq(acceptedBids[i], trueBids[i], "Accepted bid should match true bid");
        }
    }

    function testIncentiveCompatibility() public {
        // Add initial liquidity
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);

        // Submit true bids in block t-1
        uint256[] memory trueBids = new uint256[](3);
        trueBids[0] = 0.002 ether;
        trueBids[1] = 0.003 ether;
        trueBids[2] = 0.004 ether;
        amm.setListSubmittedFees(trueBids);

        // Move to block t and accept bids
        vm.roll(block.number + 1);
        uint256[] memory acceptedBids = amm.listSubmittedFees();

        // Submit alternative (manipulated) bids in block t-1
        uint256[] memory manipulatedBids = new uint256[](3);
        manipulatedBids[0] = 0.001 ether; // Lower bid
        manipulatedBids[1] = 0.0035 ether; // Higher bid
        manipulatedBids[2] = 0.0045 ether; // Higher bid
        amm.setListSubmittedFees(manipulatedBids);

        // Move to block t+1 and accept manipulated bids
        vm.roll(block.number + 1);
        uint256[] memory manipulatedAcceptedBids = amm.listSubmittedFees();

        // Compare outcomes
        for (uint256 i = 0; i < acceptedBids.length; i++) {
            assertTrue(acceptedBids[i] >= manipulatedAcceptedBids[i], "Manipulated strategy should not be more beneficial");
        }
    }

    function testNonDictatorial() public {
        // Add initial liquidity
        amm.addLiquidity(90 ether, 110 ether, 1000 ether);

        // Submit bids from multiple participants in block t-1
        uint256[] memory bids = new uint256[](3);
        bids[0] = 0.002 ether; // Participant 1
        bids[1] = 0.003 ether; // Participant 2
        bids[2] = 0.004 ether; // Participant 3
        amm.setListSubmittedFees(bids);

        // Move to block t and accept bids
        vm.roll(block.number + 1);
        uint256[] memory acceptedBids = amm.listSubmittedFees();

        // Ensure no single participant can dictate the outcome
        for (uint256 i = 0; i < acceptedBids.length; i++) {
            assertTrue(acceptedBids[i] <= amm.baseFee(), "No single participant should dictate the outcome");
        }
    }
}

    function sqrt(uint256 x) internal pure returns (uint256) {
        return uint256(sqrt(int256(x)));
    }

    function sqrt(int256 x) internal pure returns (int256) {
        int256 z = (x + 1) / 2;
        int256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}
