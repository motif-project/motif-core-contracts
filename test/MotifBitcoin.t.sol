// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "../src/token/MotifBTC.sol";
import "../src/token/MotifBitcoin.sol";
import "../src/token/WMotifBTC.sol";

contract MotifBitcoinTest is Test {
    MotifBitcoin public motifBitcoin;
    WrappedMotifBitcoin public wMotifBTC;
    
    address public admin = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public feeRecipient = address(0x4);
    
    uint256 public constant INITIAL_DEPOSIT = 100 * 10**8; // 100 BTC
    uint256 public constant MIN_DEPOSIT = 10**4; // 0.0001 BTC
    uint256 public constant MINIMUM_INITIAL_DEPOSIT = 10**8; // 1 BTC
    
    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        
        motifBitcoin = new MotifBitcoin();
        motifBitcoin.initialize(admin);
        
        wMotifBTC = new WrappedMotifBitcoin();
        wMotifBTC.initialize(admin, address(motifBitcoin));
        
        // Setup roles
        motifBitcoin.grantRole(motifBitcoin.MINT_ROLE(), admin);
        motifBitcoin.grantRole(motifBitcoin.BURN_ROLE(), admin);
        motifBitcoin.grantRole(motifBitcoin.REBASE_ROLE(), admin);
        motifBitcoin.grantRole(motifBitcoin.PAUSE_ROLE(), admin);
        motifBitcoin.grantRole(motifBitcoin.RESUME_ROLE(), admin);
        
        // Initialize with some Bitcoin
        motifBitcoin.setBitcoinReporter(admin);
        motifBitcoin.updateTotalPooledBitcoin(INITIAL_DEPOSIT);
        
        // Mint initial shares to admin
        motifBitcoin.initializeShares(INITIAL_DEPOSIT);
        
        vm.stopPrank();
    }
    
    // ================ Share Calculation Tests ================
    
    function testMinimumInitialDeposit() public {
        // Reset contract state for this test
        vm.startPrank(admin);
        MotifBitcoin newMotifBitcoin = new MotifBitcoin();
        newMotifBitcoin.initialize(admin);
        newMotifBitcoin.setBitcoinReporter(admin);
        newMotifBitcoin.updateTotalPooledBitcoin(0);
        newMotifBitcoin.grantRole(newMotifBitcoin.MINT_ROLE(), admin);
        vm.stopPrank();
        
        // Try to mint shares with amount below minimum
        vm.startPrank(admin);
        vm.expectRevert("Initial deposit too small");
        console.log("GetPooledBitcoin, ", newMotifBitcoin.getTotalPooledBitcoin());
        newMotifBitcoin.getSharesByPooledBitcoin(MINIMUM_INITIAL_DEPOSIT - 1);
        
        // update total pooled bitcoin
        newMotifBitcoin.updateTotalPooledBitcoin(INITIAL_DEPOSIT);
        newMotifBitcoin.initializeShares(INITIAL_DEPOSIT);
        // update total pooled bitcoin
        newMotifBitcoin.updateTotalPooledBitcoin(MINIMUM_INITIAL_DEPOSIT);
        
        // Mint with exact minimum
        uint256 tokensAmount = newMotifBitcoin.mintShares(user1, MINIMUM_INITIAL_DEPOSIT);
        vm.stopPrank();
        
        assertEq(tokensAmount, MINIMUM_INITIAL_DEPOSIT);
        assertEq(newMotifBitcoin.sharesOf(user1), MINIMUM_INITIAL_DEPOSIT);
    }
    
    function testTinyDepositsAfterInitial() public {
        // Mint tiny amount to user1
        vm.startPrank(admin);
        uint256 tinyAmount = 1; // 0.00000001 BTC
        uint256 expectedShares = motifBitcoin.getSharesByPooledBitcoin(tinyAmount);
        uint256 tokensAmount = motifBitcoin.mintShares(user1, expectedShares);
        vm.stopPrank();
        
        // Verify shares and tokens
        assertEq(motifBitcoin.sharesOf(user1), expectedShares);
        assertEq(tokensAmount, tinyAmount);
    }
    
    function testShareCalculationConsistency() public {
        // Perform multiple operations
        vm.startPrank(admin);
        
        // Mint to user1
        uint256 amount1 = 10 * 10**8; // 10 BTC
        uint256 shares1 = motifBitcoin.getSharesByPooledBitcoin(amount1);
        motifBitcoin.mintShares(user1, shares1);
        
        // Mint to user2
        uint256 amount2 = 5 * 10**8; // 5 BTC
        uint256 shares2 = motifBitcoin.getSharesByPooledBitcoin(amount2);
        motifBitcoin.mintShares(user2, shares2);
        
        // Burn from user1
        uint256 burnAmount = 2 * 10**8; // 2 BTC
        uint256 burnShares = motifBitcoin.getSharesByPooledBitcoin(burnAmount);
        motifBitcoin.burnShares(user1, burnShares);
        
        vm.stopPrank();
        
        // Verify final balances
        uint256 user1Shares = motifBitcoin.sharesOf(user1);
        uint256 user1Tokens = motifBitcoin.balanceOf(user1);
        uint256 calculatedTokens = motifBitcoin.getPooledBitcoinByShares(user1Shares);
        
        // Allow small rounding difference (1 wei)
        assertApproxEqAbs(user1Tokens, calculatedTokens, 1);
    }
    
    function testShareCalculationPrecision() public {
        // Test with various deposit sizes to check precision
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 10**4;  // 0.0001 BTC (minimum)
        amounts[1] = 10**5;  // 0.001 BTC
        amounts[2] = 10**6;  // 0.01 BTC
        amounts[3] = 10**8;  // 1 BTC
        amounts[4] = 1000 * 10**8; // 1000 BTC
        
        for (uint i = 0; i < amounts.length; i++) {
            vm.startPrank(admin);
            uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amounts[i]);
            motifBitcoin.mintShares(user1, shares);
            vm.stopPrank();
            
            uint256 balance = motifBitcoin.balanceOf(user1);
            
            // Verify the balance is approximately equal to the deposit amount
            assertApproxEqRel(balance, amounts[i], 10**15); // 0.1% tolerance
            
            // Reset for next test
            vm.startPrank(admin);
            motifBitcoin.burnShares(user1, motifBitcoin.sharesOf(user1));
            vm.stopPrank();
        }
    }
    
    // ================ Rebase Mechanism Tests ================
    
    function testZeroRewards() public {
        // Get initial state
        uint256 initialTotalBitcoin = motifBitcoin.getTotalPooledBitcoin();
        uint256 initialTotalShares = motifBitcoin.getTotalShares();
        
        // Process rebase with same amount (no rewards)
        vm.startPrank(admin);
        motifBitcoin.processRebase(
            block.timestamp,
            initialTotalBitcoin,
            feeRecipient,
            500 // 5% fee
        );
        vm.stopPrank();
        
        // Verify no changes in shares
        assertEq(motifBitcoin.getTotalShares(), initialTotalShares);
        assertEq(motifBitcoin.getTotalPooledBitcoin(), initialTotalBitcoin);
    }
    
    function testNegativeRebase() public {
        // Get initial state
        uint256 initialTotalBitcoin = motifBitcoin.getTotalPooledBitcoin();
        uint256 initialAdminBalance = motifBitcoin.balanceOf(admin);
        
        // Process rebase with 10% less Bitcoin
        uint256 newTotalBitcoin = initialTotalBitcoin * 90 / 100;
        
        vm.startPrank(admin);
        motifBitcoin.processRebase(
            block.timestamp,
            newTotalBitcoin,
            feeRecipient,
            500 // 5% fee
        );
        vm.stopPrank();
        
        // Verify total Bitcoin decreased
        assertEq(motifBitcoin.getTotalPooledBitcoin(), newTotalBitcoin);
        
        // Verify admin balance decreased proportionally
        uint256 expectedNewBalance = initialAdminBalance * 90 / 100;
        assertApproxEqRel(motifBitcoin.balanceOf(admin), expectedNewBalance, 10**15); // 0.1% tolerance
    }
    
    function testLargePositiveRebase() public {
        // Get initial state
        uint256 initialTotalBitcoin = motifBitcoin.getTotalPooledBitcoin();
        
        // Process rebase with 1000% more Bitcoin (extreme case)
        uint256 newTotalBitcoin = initialTotalBitcoin * 1000 / 100;
        
        vm.startPrank(admin);
        motifBitcoin.processRebase(
            block.timestamp,
            newTotalBitcoin,
            feeRecipient,
            500 // 5% fee
        );
        vm.stopPrank();
        
        // Verify fee recipient received correct amount
        uint256 rewardAmount = newTotalBitcoin - initialTotalBitcoin;
        uint256 feeAmount = rewardAmount * 500 / 10000;
        
        assertApproxEqRel(motifBitcoin.balanceOf(feeRecipient), feeAmount, 10**15); // 0.1% tolerance
    }
    
    function testMultipleRebases() public {
        // Perform multiple rebases and check consistency
        uint256 totalBitcoin = motifBitcoin.getTotalPooledBitcoin();
        
        for (uint i = 0; i < 5; i++) {
            // Alternate between positive and negative rebases
            if (i % 2 == 0) {
                totalBitcoin = totalBitcoin * 110 / 100; // +10%
            } else {
                totalBitcoin = totalBitcoin * 95 / 100; // -5%
            }
            
            vm.startPrank(admin);
            motifBitcoin.processRebase(
                block.timestamp + i * 1 days,
                totalBitcoin,
                feeRecipient,
                500 // 5% fee
            );
            vm.stopPrank();
        }
        
        // Verify final state is consistent
        assertEq(motifBitcoin.getTotalPooledBitcoin(), totalBitcoin);
        
        // Check that total shares * exchange rate = total Bitcoin
        uint256 totalShares = motifBitcoin.getTotalShares();
        uint256 calculatedBitcoin = motifBitcoin.getPooledBitcoinByShares(totalShares);
        
        assertApproxEqRel(calculatedBitcoin, totalBitcoin, 10**15); // 0.1% tolerance
    }
    
    // ================ Transfer and Allowance Tests ================
    
    function testTransferEntireBalance() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Transfer entire balance
        uint256 user1Balance = motifBitcoin.balanceOf(user1);
        vm.startPrank(user1);
        motifBitcoin.transfer(user2, user1Balance);
        vm.stopPrank();
        
        // Verify balances
        assertEq(motifBitcoin.balanceOf(user1), 0);
        assertEq(motifBitcoin.balanceOf(user2), user1Balance);
        assertEq(motifBitcoin.sharesOf(user1), 0);
    }
    
    function testInfiniteAllowance() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Set infinite allowance
        vm.startPrank(user1);
        motifBitcoin.approve(user2, type(uint256).max);
        vm.stopPrank();
        
        // Multiple transfers should work without reducing allowance
        vm.startPrank(user2);
        motifBitcoin.transferFrom(user1, user2, 1 * 10**8); // 1 BTC
        vm.stopPrank();
        
        assertEq(motifBitcoin.allowance(user1, user2), type(uint256).max);
        
        vm.startPrank(user2);
        motifBitcoin.transferFrom(user1, user2, 2 * 10**8); // 2 BTC
        vm.stopPrank();
        
        assertEq(motifBitcoin.allowance(user1, user2), type(uint256).max);
    }
    
    function testTransferShares() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Transfer all shares
        uint256 user1Shares = motifBitcoin.sharesOf(user1);
        vm.startPrank(user1);
        motifBitcoin.transferShares(user2, user1Shares);
        vm.stopPrank();
        
        // Verify balances
        assertEq(motifBitcoin.sharesOf(user1), 0);
        assertEq(motifBitcoin.sharesOf(user2), user1Shares);
        assertEq(motifBitcoin.balanceOf(user1), 0);
    }
    
    // ================ Wrapped Token Tests ================
    
    function testWrappingEntireBalance() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Approve and wrap entire balance
        uint256 user1Balance = motifBitcoin.balanceOf(user1);
        vm.startPrank(user1);
        motifBitcoin.approve(address(wMotifBTC), user1Balance);
        wMotifBTC.wrap(user1Balance);
        vm.stopPrank();
        
        // Verify balances
        assertEq(motifBitcoin.balanceOf(user1), 0);
        assertEq(wMotifBTC.balanceOf(user1), user1Balance);
    }
    
    function testWrappedBalanceAfterRebase() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Wrap half the balance
        uint256 wrapAmount = 5 * 10**8; // 5 BTC
        vm.startPrank(user1);
        motifBitcoin.approve(address(wMotifBTC), wrapAmount);
        wMotifBTC.wrap(wrapAmount);
        vm.stopPrank();
        
        // Process positive rebase (100% increase)
        uint256 initialTotalBitcoin = motifBitcoin.getTotalPooledBitcoin();
        vm.startPrank(admin);
        motifBitcoin.processRebase(
            block.timestamp,
            initialTotalBitcoin * 2,
            feeRecipient,
            500 // 5% fee
        );
        vm.stopPrank();
        
        // Verify wrapped balance remains the same
        assertEq(wMotifBTC.balanceOf(user1), wrapAmount);
        
        // Unwrap and verify received amount reflects rebase
        vm.startPrank(user1);
        wMotifBTC.unwrap(wrapAmount);
        vm.stopPrank();
        
        // Should receive approximately double (minus fees)
        uint256 expectedMinimum = wrapAmount * 190 / 100; // >190% of initial
        assertTrue(motifBitcoin.balanceOf(user1) > expectedMinimum);
    }
    
    function testMinimumWrapAmount() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 1 * 10**8; // 1 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Try to wrap tiny amount
        uint256 tinyAmount = 1; // 0.00000001 BTC
        vm.startPrank(user1);
        motifBitcoin.approve(address(wMotifBTC), tinyAmount);
        
        // Should revert if below minimum
        if (MIN_DEPOSIT > 1) {
            vm.expectRevert("Amount too small");
            wMotifBTC.wrap(tinyAmount);
        } else {
            wMotifBTC.wrap(MIN_DEPOSIT);
            assertEq(wMotifBTC.balanceOf(user1), MIN_DEPOSIT);
        }
        vm.stopPrank();
    }
    
    // ================ Access Control Tests ================
    
    function testUnauthorizedRebase() public {
        vm.startPrank(user1);
        vm.expectRevert();
        motifBitcoin.processRebase(
            block.timestamp,
            200 * 10**8,
            feeRecipient,
            500
        );
        vm.stopPrank();
    }
    
    function testUnauthorizedMinting() public {
        vm.startPrank(user1);
        vm.expectRevert();
        motifBitcoin.mintShares(
            user1,
            100 * 10**8
        );
        vm.stopPrank();
    }
    
    function testUnauthorizedBurning() public {
        vm.startPrank(user1);
        vm.expectRevert();
        motifBitcoin.burnShares(
            user1,
            100 * 10**8
        );
        vm.stopPrank();
    }
    
    function testUnauthorizedPausing() public {
        vm.startPrank(user1);
        vm.expectRevert();
        motifBitcoin.pause();
        vm.stopPrank();
    }
    
    // ================ Stress Tests ================
    
    function testManySmallDeposits() public {
        // Perform many small deposits and check consistency
        uint256 numDeposits = 100;
        uint256 smallAmount = MIN_DEPOSIT;
        
        for (uint i = 0; i < numDeposits; i++) {
            vm.startPrank(admin);
            uint256 shares = motifBitcoin.getSharesByPooledBitcoin(smallAmount);
            motifBitcoin.mintShares(user1, shares);
            vm.stopPrank();
        }
        
        // Verify final balance
        uint256 expectedBalance = smallAmount * numDeposits;
        assertApproxEqRel(motifBitcoin.balanceOf(user1), expectedBalance, 10**15); // 0.1% tolerance
    }
    
    function testAlternatingDepositWithdrawal() public {
        // Alternate between deposits and withdrawals
        uint256 numOperations = 50;
        uint256 amount = 1 * 10**8; // 1 BTC
        
        // Initial deposit
        vm.startPrank(admin);
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount * 10);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        for (uint i = 0; i < numOperations; i++) {
            if (i % 2 == 0) {
                // Deposit
                vm.startPrank(admin);
                shares = motifBitcoin.getSharesByPooledBitcoin(amount);
                motifBitcoin.mintShares(user1, shares);
                vm.stopPrank();
            } else {
                // Withdraw
                vm.startPrank(admin);
                shares = motifBitcoin.getSharesByPooledBitcoin(amount);
                motifBitcoin.burnShares(user1, shares);
                vm.stopPrank();
            }
        }
        
        // Verify final balance is consistent
        uint256 finalShares = motifBitcoin.sharesOf(user1);
        uint256 finalBalance = motifBitcoin.balanceOf(user1);
        uint256 calculatedBalance = motifBitcoin.getPooledBitcoinByShares(finalShares);
        
        assertApproxEqRel(finalBalance, calculatedBalance, 10**15); // 0.1% tolerance
    }
    
    function testRebaseAfterManyTransfers() public {
        // Setup initial balances
        vm.startPrank(admin);
        uint256 amount = 100 * 10**8; // 100 BTC
        uint256 shares = motifBitcoin.getSharesByPooledBitcoin(amount);
        motifBitcoin.mintShares(user1, shares);
        vm.stopPrank();
        
        // Perform many transfers
        uint256 numTransfers = 50;
        uint256 transferAmount = 1 * 10**8; // 1 BTC
        
        for (uint i = 0; i < numTransfers; i++) {
            if (i % 2 == 0) {
                vm.startPrank(user1);
                motifBitcoin.transfer(user2, transferAmount);
                vm.stopPrank();
            } else {
                vm.startPrank(user2);
                motifBitcoin.transfer(user1, transferAmount);
                vm.stopPrank();
            }
        }
        
        // Process rebase
        uint256 initialTotalBitcoin = motifBitcoin.getTotalPooledBitcoin();
        vm.startPrank(admin);
        motifBitcoin.processRebase(
            block.timestamp,
            initialTotalBitcoin * 120 / 100, // +20%
            feeRecipient,
            500 // 5% fee
        );
        vm.stopPrank();
        
        // Verify balances are consistent after rebase
        uint256 user1Shares = motifBitcoin.sharesOf(user1);
        uint256 user1Balance = motifBitcoin.balanceOf(user1);
        uint256 calculatedBalance = motifBitcoin.getPooledBitcoinByShares(user1Shares);
        
        assertApproxEqRel(user1Balance, calculatedBalance, 10**15); // 0.1% tolerance
    }
}
