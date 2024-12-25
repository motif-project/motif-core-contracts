// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/core/BitcoinPod.sol";
import "../src/interfaces/IBitcoinPod.sol";
import "forge-std/console.sol";

contract BitcoinPodTest is Test {
    BitcoinPod public pod;
    address public owner;
    address public operator;
    address public manager;
    bytes public operatorBtcPubKey;
    string public bitcoinAddress;
    uint256 public constant MAX_TX_SIZE = 1024 * 100; // 100KB

    event PodStateChanged(BitcoinPod.PodState previousState, BitcoinPod.PodState newState);
    event MintPodValue(address indexed pod, uint256 amount);
    event BurnPodValue(address indexed pod, uint256 amount);
    event WithdrawTransactionSet(bytes signedTransaction);
    event PodInitialized(address indexed pod, address indexed owner, address indexed operator);

    function setUp() public {
        owner = address(this);
        operator = address(0x1);
        manager = address(0x2);
        operatorBtcPubKey = hex"0123456789abcdef";
        bitcoinAddress = "tb1qhlx2vgesz00s4gr6jqqhparezuhtryrkpnd7tm";

        // Create new pod
        pod = new BitcoinPod(manager);
        // Expect the initialization event
        vm.expectEmit(true, true, true, true);
        emit PodInitialized(address(pod), owner, operator);
        // Initialize only once
        pod.initialize(owner, operator, operatorBtcPubKey, bitcoinAddress);
    }

    function testInitialState() public view {
        assertEq(pod.owner(), owner);
        assertEq(pod.operator(), operator);
        assertEq(pod.manager(), manager);
        assertEq(pod.operatorBtcPubKey(), operatorBtcPubKey);
        assertEq(bytes(pod.bitcoinAddress()), bytes(bitcoinAddress));
        assertEq(pod.bitcoinBalance(), 0);
        assertFalse(pod.locked());
        assertEq(pod.signedBitcoinWithdrawTransaction(), "");
    }

    function testInitializeZeroAddressReverts() public {
        BitcoinPod newPod = new BitcoinPod(manager);

        vm.expectRevert("Owner cannot be the zero address");
        newPod.initialize(address(0), operator, operatorBtcPubKey, bitcoinAddress);

        vm.expectRevert("Operator cannot be the zero address");
        newPod.initialize(owner, address(0), operatorBtcPubKey, bitcoinAddress);
    }

    function testInitializeEmptyValuesReverts() public {
        BitcoinPod newPod = new BitcoinPod(manager);

        vm.expectRevert("Operator BTC public key cannot be empty");
        newPod.initialize(owner, operator, "", bitcoinAddress);

        vm.expectRevert("Bitcoin address cannot be empty");
        newPod.initialize(owner, operator, operatorBtcPubKey, "");
    }

    function testMint() public {
        uint256 amount = 100;

        // Successful mint when unlocked
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit MintPodValue(address(pod), amount);
        pod.mint(amount);
        assertEq(pod.bitcoinBalance(), amount);

        // Lock pod
        vm.prank(manager);
        pod.lock();

        // Try minting while locked
        vm.prank(manager);
        vm.expectRevert("Pod is locked");
        pod.mint(amount);

        // Try minting with zero amount
        vm.prank(manager);
        pod.unlock();
        vm.prank(manager);
        vm.expectRevert("Amount must be greater than 0");
        pod.mint(0);

        // Try minting when inactive
        vm.prank(manager);
        pod.setPodState(IBitcoinPod.PodState.Inactive);
        vm.prank(manager);
        vm.expectRevert("Pod is not active");
        pod.mint(amount);
    }

    function testBurn() public {
        uint256 amount = 100;

        // Setup: mint some balance first
        vm.prank(manager);
        pod.mint(amount);

        // Lock pod and try burning while locked
        vm.prank(manager);
        pod.lock();
        vm.prank(manager);
        vm.expectRevert("Pod is locked");
        pod.burn(amount);

        // Unlock and test remaining burn scenarios
        vm.prank(manager);
        pod.unlock();

        // set the pod state as inactive
        vm.prank(manager);
        pod.setPodState(IBitcoinPod.PodState.Inactive);

        // Try burning too much
        vm.prank(manager);
        vm.expectRevert("Insufficient balance");
        pod.burn(amount + 1);

        // Successful burn
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit BurnPodValue(address(pod), amount);
        pod.burn(amount);
        assertEq(pod.bitcoinBalance(), 0);
    }

    function testStateTransitions() public {
        // Test valid transitions
        vm.startPrank(manager);

        // Active -> Inactive
        vm.expectEmit(true, true, true, true);
        emit PodStateChanged(IBitcoinPod.PodState.Active, IBitcoinPod.PodState.Inactive);
        pod.setPodState(IBitcoinPod.PodState.Inactive);

        // Inactive -> Active
        vm.expectEmit(true, true, true, true);
        emit PodStateChanged(IBitcoinPod.PodState.Inactive, IBitcoinPod.PodState.Active);
        pod.setPodState(IBitcoinPod.PodState.Active);

        vm.stopPrank();
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
        bytes memory largeTxn = new bytes(MAX_TX_SIZE + 1);

        // Only manager can set
        vm.prank(address(0x3));
        vm.expectRevert("Only manager can perform this action");
        pod.setSignedBitcoinWithdrawTransaction(txn);

        // Cannot set empty transaction
        vm.prank(manager);
        vm.expectRevert("Signed transaction cannot be empty");
        pod.setSignedBitcoinWithdrawTransaction("");

        // Cannot set transaction for active pod
        vm.prank(manager);
        vm.expectRevert("Pod is not inactive");
        pod.setSignedBitcoinWithdrawTransaction(txn);

        // Cannot set transaction larger than MAX_TX_SIZE
        vm.prank(manager);
        pod.setPodState(IBitcoinPod.PodState.Inactive);
        vm.prank(manager);
        vm.expectRevert("Signed transaction exceeds max size");
        pod.setSignedBitcoinWithdrawTransaction(largeTxn);
        // Successful set
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit WithdrawTransactionSet(txn);
        pod.setSignedBitcoinWithdrawTransaction(txn);
        assertEq(pod.signedBitcoinWithdrawTransaction(), txn);
    }

    /// @notice Tests all getter functions of the BitcoinPod contract
    /// @dev This is a view function that only reads state variables  
    // solhint-disable-next-line state-mutability
    function testGetters() public view {
        assertEq(pod.getBitcoinAddress(), bitcoinAddress);
        assertEq(pod.getOperatorBtcPubKey(), operatorBtcPubKey);
        assertEq(pod.getOperator(), operator);
        assertEq(pod.getBitcoinBalance(), 0);
        assertEq(pod.getSignedBitcoinWithdrawTransaction(), bytes(""));
    }

    function testPodState() public view {
        IBitcoinPod.PodState activeState = IBitcoinPod.PodState.Active;
        IBitcoinPod.PodState state = pod.getPodState();
        // compare enum values
        assertEq(uint256(state), uint256(activeState));
    }

    function testPodStateReverts() public {
        vm.prank(manager);
        vm.expectRevert("Invalid state transition");
        pod.setPodState(IBitcoinPod.PodState.Active);
    }

    function testReentrancyProtection() public {
        // Test reentrancy protection on state-changing functions
        // Note: This is a basic test, actual reentrancy would need a malicious contract
        vm.prank(manager);
        pod.mint(100);

        // Additional reentrancy tests with mock contracts SHOULD BE ADDED LATER
    }
}
