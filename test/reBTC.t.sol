// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "forge-std/Test.sol";
import "../src/token/reBTC.sol";
import "../src/token/WreBTC.sol";

contract ReBTCTest is Test {
    ReBTC public reBTC;
    WrappedReBTC public wreBTC;
    
    address public admin = address(0x1);
    address public tokenhub = address(0x2);
    address public rebaser = address(0x3);
    address public user1 = address(0x4);
    address public user2 = address(0x5);
    
    uint256 public constant INITIAL_DEPOSIT = 100 * 10**8; // 100 BTC
    uint256 public constant MIN_DEPOSIT = 10**4; // 0.0001 BTC
    uint256 public constant MINIMUM_INITIAL_DEPOSIT = 10**8; // 1 BTC
    
    function setUp() public {
        // Deploy contracts
        vm.startPrank(admin);
        
        reBTC = new ReBTC();
        reBTC.initialize(admin, tokenhub, rebaser);
        
        wreBTC = new WrappedReBTC();
        wreBTC.initialize(admin, address(reBTC));
        
        // Setup roles
        reBTC.grantRole(reBTC.TOKENHUB_ROLE(), tokenhub);
        reBTC.grantRole(reBTC.REBASER_ROLE(), rebaser);
        
        // Initialize with some Bitcoin
        reBTC.updateTotalPooledBTC(INITIAL_DEPOSIT);
        
        // Mint initial shares to admin
        reBTC.mint(admin, INITIAL_DEPOSIT);
        
        vm.stopPrank();
    }
    
    // ================ Share Calculation Tests ================
    
   /* function testMinimumInitialDeposit() public {
        // Reset contract state for this test
        vm.startPrank(admin);
        ReBTC newReBTC = new ReBTC();
        newReBTC.initialize(admin, admin, admin);
        newReBTC.updateTotalPooledBTC(0);
        newReBTC.grantRole(newReBTC.TOKENHUB_ROLE(), admin);
        vm.stopPrank();
        
        // Try to mint shares with amount below minimum
        vm.startPrank(admin);
        vm.expectRevert("Initial deposit too small");
        newReBTC.getShares(MINIMUM_INITIAL_DEPOSIT - 1);
        
        // update total pooled bitcoin
        newReBTC.updateTotalPooledBTC(INITIAL_DEPOSIT);
        newReBTC.mint(admin, INITIAL_DEPOSIT);
        // update total pooled bitcoin
        newReBTC.updateTotalPooledBTC(MINIMUM_INITIAL_DEPOSIT);
        
        // Mint with exact minimum
        uint256 tokensAmount = newReBTC.mint(admin, MINIMUM_INITIAL_DEPOSIT);
        vm.stopPrank();
        
        assertEq(tokensAmount, MINIMUM_INITIAL_DEPOSIT);
        assertEq(newReBTC.getShares(admin), MINIMUM_INITIAL_DEPOSIT);
    }
    
    function testTinyDepositsAfterInitial() public {
        // Mint tiny amount to user1
        vm.startPrank(admin);
        uint256 tinyAmount = 1; // 0.00000001 BTC
        uint256 expectedShares = reBTC.getShares(tinyAmount);
        uint256 tokensAmount = reBTC.mint(admin, expectedShares);
        vm.stopPrank();
        
        // Verify shares and tokens
        assertEq(reBTC.getShares(admin), expectedShares);
        assertEq(tokensAmount, tinyAmount);
    }
    
    function testShareCalculationConsistency() public {
        // Perform multiple operations
        vm.startPrank(tokenhub);
        
        // Mint to user1
        uint256 amount1 = 10 * 10**8; // 10 BTC
        reBTC.mint(user1, amount1);
        
        // Mint to user2
        uint256 amount2 = 5 * 10**8; // 5 BTC
        reBTC.mint(user2, amount2);
        
        // Burn from user1
        uint256 burnAmount = 2 * 10**8; // 2 BTC
        reBTC.burn(user1, burnAmount);
        
        vm.stopPrank();
        
        // Verify final balances
        uint256 user1Shares = reBTC.getShares(user1);
        uint256 user1Tokens = reBTC.balanceOf(user1);
        uint256 calculatedTokens = (user1Shares * reBTC.totalSupply()) / reBTC.getTotalShares();
        
        // Allow small rounding difference (1 wei)
        assertApproxEqAbs(user1Tokens, calculatedTokens, 1);
    }*/
    
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
            uint256 scaledAmount = amounts[i] * 10**10;
            reBTC.mint(admin, scaledAmount);
            vm.stopPrank();
            
            uint256 balance = reBTC.balanceOf(admin);
            
            // Verify the balance is approximately equal to the deposit amount
            assertApproxEqRel(balance, amounts[i], 10**15); // 0.1% tolerance
            
            // Reset for next test
            vm.startPrank(admin);
            reBTC.burn(admin, scaledAmount);
            vm.stopPrank();
        }
    }
    
    // ================ Rebase Mechanism Tests ================
    
    function testZeroRewards() public {
        // Get initial state
        uint256 initialTotal = reBTC.totalSupply();
        uint256 initialTotalShares = reBTC.getTotalShares();
        
        // Process rebase with same amount (no rewards)
        vm.startPrank(tokenhub);
        reBTC.updateTotalPooledBTC(initialTotal);
        vm.stopPrank();
        
        // Verify no changes in shares
        assertEq(reBTC.getTotalShares(), initialTotalShares);
        assertEq(reBTC.getTotalPooledBTC(), initialTotal);
    }
    
    function testNegativeRebase() public {
        // Get initial state
        uint256 initialTotal = reBTC.totalSupply();
        uint256 initialAdminBalance = reBTC.balanceOf(admin);
        
        // Process rebase with 10% less Bitcoin
        uint256 newTotal = initialTotal * 90 / 100;
        
        vm.startPrank(tokenhub);
        reBTC.updateTotalPooledBTC(newTotal);
        vm.stopPrank();
        
        // Verify total Bitcoin decreased
        assertEq(reBTC.getTotalPooledBTC(), newTotal);
        
        // Verify admin balance decreased proportionally
        uint256 expectedNewBalance = initialAdminBalance * 90 / 100;
        assertApproxEqRel(reBTC.balanceOf(admin), expectedNewBalance, 10**15); // 0.1% tolerance
    }
    
    function testLargePositiveRebase() public {
        // Get initial state
        uint256 initialTotal = reBTC.totalSupply();
        
        // Process rebase with 1000% more Bitcoin (extreme case)
        uint256 newTotal = initialTotal * 1000 / 100;
        
        vm.startPrank(tokenhub);
        reBTC.updateTotalPooledBTC(newTotal);
        vm.stopPrank();
        
        // Verify fee recipient received correct amount
        uint256 rewardAmount = newTotal - initialTotal;
        uint256 feeAmount = rewardAmount * 500 / 10000;
        
        assertApproxEqRel(reBTC.balanceOf(tokenhub), feeAmount, 10**15); // 0.1% tolerance
    }
    
    function testMultipleRebases() public {
        // Perform multiple rebases and check consistency
        uint256 total = reBTC.totalSupply();
        
        for (uint i = 0; i < 5; i++) {
            // Alternate between positive and negative rebases
            if (i % 2 == 0) {
                total = total * 110 / 100; // +10%
            } else {
                total = total * 95 / 100; // -5%
            }
            
            vm.startPrank(tokenhub);
            reBTC.updateTotalPooledBTC(total);
            vm.stopPrank();
        }
        
        // Verify final state is consistent
        assertEq(reBTC.getTotalPooledBTC(), total);
        
        // Check that total shares * exchange rate = total Bitcoin
        uint256 totalShares = reBTC.getTotalShares();
        uint256 calculatedBitcoin = (totalShares * reBTC.totalSupply()) / reBTC.getTotalShares();
        
        assertApproxEqRel(calculatedBitcoin, total, 10**15); // 0.1% tolerance
    }
    
    // ================ Transfer and Allowance Tests ================
    
    function testTransferEntireBalance() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Transfer entire balance
        uint256 user1Balance = reBTC.balanceOf(admin);
        vm.startPrank(admin);
        reBTC.transfer(user2, user1Balance);
        vm.stopPrank();
        
        // Verify balances
        assertEq(reBTC.balanceOf(admin), 0);
        assertEq(reBTC.balanceOf(user2), user1Balance);
        assertEq(reBTC.getShares(admin), 0);
    }
    
    function testInfiniteAllowance() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Set infinite allowance
        vm.startPrank(admin);
        reBTC.approve(user2, type(uint256).max);
        vm.stopPrank();
        
        // Multiple transfers should work without reducing allowance
        vm.startPrank(user2);
        reBTC.transfer(user2, 1 * 10**8); // 1 BTC
        vm.stopPrank();
        
        assertEq(reBTC.allowance(admin, user2), type(uint256).max);
        
        vm.startPrank(user2);
        reBTC.transfer(user2, 2 * 10**8); // 2 BTC
        vm.stopPrank();
        
        assertEq(reBTC.allowance(admin, user2), type(uint256).max);
    }
    
   /* function testTransferShares() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Transfer all shares
        uint256 user1Shares = reBTC.getShares(admin);
        vm.startPrank(admin);
        reBTC.transferShares(user2, user1Shares);
        vm.stopPrank();
        
        // Verify balances
        assertEq(reBTC.getShares(admin), 0);
        assertEq(reBTC.getShares(user2), user1Shares);
        assertEq(reBTC.balanceOf(admin), 0);
    }*/
    
    // ================ Wrapped Token Tests ================
    
    function testWrappingEntireBalance() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Approve and wrap entire balance
        uint256 user1Balance = reBTC.balanceOf(admin);
        vm.startPrank(admin);
        reBTC.approve(address(wreBTC), user1Balance);
        wreBTC.wrap(user1Balance);
        vm.stopPrank();
        
        // Verify balances
        assertEq(reBTC.balanceOf(admin), 0);
        assertEq(wreBTC.balanceOf(admin), user1Balance);
    }
    
    function testWrappedBalanceAfterRebase() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 10 * 10**8; // 10 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Wrap half the balance
        uint256 wrapAmount = 5 * 10**8; // 5 BTC
        vm.startPrank(admin);
        reBTC.approve(address(wreBTC), wrapAmount);
        wreBTC.wrap(wrapAmount);
        vm.stopPrank();
        
        // Process positive rebase (100% increase)
        uint256 initialTotal = reBTC.totalSupply();
        vm.startPrank(tokenhub);
        reBTC.updateTotalPooledBTC(initialTotal * 2);
        vm.stopPrank();
        
        // Verify wrapped balance remains the same
        assertEq(wreBTC.balanceOf(admin), wrapAmount);
        
        // Unwrap and verify received amount reflects rebase
        vm.startPrank(admin);
        wreBTC.unwrap(wrapAmount);
        vm.stopPrank();
        
        // Should receive approximately double (minus fees)
        uint256 expectedMinimum = wrapAmount * 190 / 100; // >190% of initial
        assertTrue(reBTC.balanceOf(admin) > expectedMinimum);
    }
    
    function testMinimumWrapAmount() public {
        // Mint to user1
        vm.startPrank(admin);
        uint256 amount = 1 * 10**8; // 1 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Try to wrap tiny amount
        uint256 tinyAmount = 1; // 0.00000001 BTC
        vm.startPrank(admin);
        reBTC.approve(address(wreBTC), tinyAmount);
        
        // Should revert if below minimum
        if (MIN_DEPOSIT > 1) {
            vm.expectRevert("Amount too small");
            wreBTC.wrap(tinyAmount);
        } else {
            wreBTC.wrap(MIN_DEPOSIT);
            assertEq(wreBTC.balanceOf(admin), MIN_DEPOSIT);
        }
        vm.stopPrank();
    }
    
    // ================ Access Control Tests ================
    
    function testUnauthorizedRebase() public {
        vm.startPrank(user1);
        vm.expectRevert();
        reBTC.updateTotalPooledBTC(200 * 10**8);
        vm.stopPrank();
    }
    
    function testUnauthorizedMinting() public {
        vm.startPrank(user1);
        vm.expectRevert();
        reBTC.mint(user1, 100 * 10**8);
        vm.stopPrank();
    }
    
    function testUnauthorizedBurning() public {
        vm.startPrank(user1);
        vm.expectRevert();
        reBTC.burn(user1, 100 * 10**8);
        vm.stopPrank();
    }
    
   /* function testUnauthorizedPausing() public {
        vm.startPrank(user1);
        vm.expectRevert();
        reBTC.pause();
        vm.stopPrank();
    }*/
    
    // ================ Stress Tests ================
    
    function testManySmallDeposits() public {
        // Perform many small deposits and check consistency
        uint256 numDeposits = 100;
        uint256 smallAmount = MIN_DEPOSIT;
        
        for (uint i = 0; i < numDeposits; i++) {
            vm.startPrank(admin);
            uint256 scaledAmount = smallAmount * 10**10;
            reBTC.mint(admin, scaledAmount);
            vm.stopPrank();
        }
        
        // Verify final balance
        uint256 expectedBalance = smallAmount * numDeposits;
        assertApproxEqRel(reBTC.balanceOf(admin), expectedBalance, 10**15); // 0.1% tolerance
    }
    
    function testAlternatingDepositWithdrawal() public {
        // Alternate between deposits and withdrawals
        uint256 numOperations = 50;
        uint256 amount = 1 * 10**8; // 1 BTC
        
        // Initial deposit
        vm.startPrank(admin);
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        for (uint i = 0; i < numOperations; i++) {
            if (i % 2 == 0) {
                // Deposit
                vm.startPrank(admin);
                uint256 scaledAmount = amount * 10**10;
                reBTC.mint(admin, scaledAmount);
                vm.stopPrank();
            } else {
                // Withdraw
                vm.startPrank(admin);
                uint256 scaledAmount = amount * 10**10;
                reBTC.burn(admin, scaledAmount);
                vm.stopPrank();
            }
        }
        
        // Verify final balance is consistent
        uint256 finalShares = reBTC.getShares(admin);
        uint256 finalBalance = reBTC.balanceOf(admin);
        uint256 calculatedBalance = (finalShares * reBTC.totalSupply()) / reBTC.getTotalShares();
        
        assertApproxEqRel(finalBalance, calculatedBalance, 10**15); // 0.1% tolerance
    }
    
    function testRebaseAfterManyTransfers() public {
        // Setup initial balances
        vm.startPrank(admin);
        uint256 amount = 100 * 10**8; // 100 BTC
        uint256 scaledAmount = amount * 10**10;
        reBTC.mint(admin, scaledAmount);
        vm.stopPrank();
        
        // Perform many transfers
        uint256 numTransfers = 50;
        uint256 transferAmount = 1 * 10**8; // 1 BTC
        
        for (uint i = 0; i < numTransfers; i++) {
            if (i % 2 == 0) {
                vm.startPrank(admin);
                reBTC.transfer(user2, transferAmount);
                vm.stopPrank();
            } else {
                vm.startPrank(user2);
                reBTC.transfer(admin, transferAmount);
                vm.stopPrank();
            }
        }
        
        // Process rebase
        uint256 initialTotal = reBTC.totalSupply();
        vm.startPrank(tokenhub);
        reBTC.updateTotalPooledBTC(initialTotal * 120 / 100); // +20%
        vm.stopPrank();
        
        // Verify balances are consistent after rebase
        uint256 user1Shares = reBTC.getShares(admin);
        uint256 user1Balance = reBTC.balanceOf(admin);
        uint256 calculatedBalance = (user1Shares * reBTC.totalSupply()) / reBTC.getTotalShares();
        
        assertApproxEqRel(user1Balance, calculatedBalance, 10**15); // 0.1% tolerance
    }
}
