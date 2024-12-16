// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/core/BitcoinPod.sol";

contract BitcoinPodTest is Test {
    BitcoinPod public pod;
    address public owner;
    address public operator;
    address public manager;
    bytes public operatorBtcPubKey;
    string public bitcoinAddress;

    function setUp() public {
        owner = address(this);
        operator = address(0x1);
        manager = address(0x2);
        operatorBtcPubKey = hex"0123456789abcdef";
        bitcoinAddress = "tb1qhlx2vgesz00s4gr6jqqhparezuhtryrkpnd7tm";

        pod = new BitcoinPod(manager);
        pod.initialize(owner, operator, operatorBtcPubKey, bitcoinAddress);
    }

    function testInitialState() public view{
        assertEq(pod.owner(), owner);
        assertEq(pod.operator(), operator);
        assertEq(pod.manager(), manager);
        assertEq(pod.operatorBtcPubKey(), operatorBtcPubKey);
        assertEq(bytes(pod.bitcoinAddress()), bytes(bitcoinAddress));
        assertEq(pod.bitcoinBalance(), 0);
        assertFalse(pod.locked());
        assertEq(pod.signedBitcoinWithdrawTransaction(), "");
    }

    function testMint() public {
        uint256 amount = 100;
        
        // Successful mint when unlocked
        vm.prank(manager);
        pod.mint(operator, amount);
        assertEq(pod.bitcoinBalance(), amount);

        // Lock pod
        vm.prank(manager);
        pod.lock();

        // Try minting while locked
        vm.prank(manager);
        vm.expectRevert("Pod is locked");
        pod.mint(operator, amount);

        // Try minting with wrong operator (while unlocked)
        vm.prank(manager);
        pod.unlock();
        vm.prank(manager);
        vm.expectRevert("Only designated operator can perform this action");
        pod.mint(address(0x3), amount);
    }

    function testBurn() public {
        uint256 amount = 100;
        
        // Setup: mint some balance first
        vm.prank(manager);
        pod.mint(operator, amount);

        // Lock pod and try burning while locked
        vm.prank(manager);
        pod.lock();
        vm.prank(manager);
        vm.expectRevert("Pod is locked");
        pod.burn(operator, amount);

        // Unlock and test remaining burn scenarios
        vm.prank(manager);
        pod.unlock();

        // Try burning with wrong operator
        vm.prank(manager);
        vm.expectRevert("Only designated operator can perform this action");
        pod.burn(address(0x3), amount);

        // Try burning too much
        vm.prank(manager);
        vm.expectRevert("Insufficient balance");
        pod.burn(operator, amount + 1);

        // Successful burn
        vm.prank(manager);
        pod.burn(operator, amount);
        assertEq(pod.bitcoinBalance(), 0);
    }

    function testLockUnlock() public {
        // Only manager can lock/unlock
        vm.prank(address(0x3));
        vm.expectRevert("Only manager can perform this action");
        pod.lock();

        vm.prank(address(0x3));
        vm.expectRevert("Only manager can perform this action");
        pod.unlock();

        // Successful lock
        vm.prank(manager);
        pod.lock();
        assertTrue(pod.isLocked());

        // Successful unlock
        vm.prank(manager);
        pod.unlock();
        assertFalse(pod.isLocked());
    }

    function testSetSignedBitcoinWithdrawTransaction() public {
        bytes memory txn = hex"1234";

        // Only manager can set
        vm.prank(address(0x3));
        vm.expectRevert("Only manager can perform this action");
        pod.setSignedBitcoinWithdrawTransaction(txn);

        // Successful set
        vm.prank(manager);
        pod.setSignedBitcoinWithdrawTransaction(txn);
        assertEq(pod.getSignedBitcoinWithdrawTransaction(), txn);
    }

    function testGetters() public view{
        assertEq(pod.getBitcoinAddress(), bitcoinAddress);
        assertEq(pod.getOperatorBtcPubKey(), operatorBtcPubKey);
        assertEq(pod.getOperator(), operator);
        assertEq(pod.getBitcoinBalance(), 0);
        assertEq(pod.getSignedBitcoinWithdrawTransaction(), "");
    }
}
