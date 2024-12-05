// SPDX-License-Identifier: MIT
 pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/core/BitcoinPodManager.sol";
import "../src/core/BitcoinPod.sol";
import "../src/interfaces/IBitDSMServiceManager.sol";
import {BitDSMRegistry} from "../src/core/BitDSMRegistry.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from "@eigenlayer/src/contracts/interfaces/ISignatureUtils.sol";
import {IStrategy} from "@eigenlayer/src/contracts/interfaces/IStrategy.sol";
import {Quorum, StrategyParams} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MockServiceManager {
    event BitcoinWithdrawalTransactionSigned(address indexed pod, address indexed operator, uint256 amount);
    BitcoinPodManager public podManager;    
    constructor() {
    }
    function initialize(address podManager_) public {
        podManager = BitcoinPodManager(podManager_);
    }
    // solhint-disable-next-line
    function deregisterOperatorFromAVS(address) external {}

    function registerOperatorToAVS(
        address,
        ISignatureUtils.SignatureWithSaltAndExpiry memory // solhint-disable-next-line
    ) external {}
    function confirmDeposit(address pod, bytes32 transactionId, uint256 amount) external {
        podManager.confirmBitcoinDeposit(pod, transactionId, amount);
   
    }

    function withdrawBitcoinPSBT(address pod, uint256 amount, bytes calldata psbtTransaction) external {
        podManager.setSignedBitcoinWithdrawTransactionPod(pod, psbtTransaction);
        emit BitcoinWithdrawalTransactionSigned(pod, msg.sender, amount);
    }

    function withdrawBitcoinCompleteTx(address pod, uint256 amount, bytes calldata completeTx) external {
         podManager.setSignedBitcoinWithdrawTransactionPod(pod, completeTx);
        emit BitcoinWithdrawalTransactionSigned(pod, msg.sender, amount);
    }

    function confirmWithdrawal(address pod) external {
        podManager.withdrawBitcoinAsTokens(pod);
    }
}

contract MockDelegationManager {
    function getOperatorShares(
        address,
        address[] memory strategies
    ) external pure returns (uint256[] memory) {
        uint256[] memory response = new uint256[](strategies.length);
        for (uint256 i; i < strategies.length; i++) {
            response[i] = 1000;
        }
        return response; // Return a dummy value for simplicity
    }
}

contract MockAppRegistry {
    mapping(address => AppRegistrationStatus) public appStatus;
    address public owner;

    enum AppRegistrationStatus {
        UNREGISTERED,
        REGISTERED
    }

    event AppRegistrationStatusUpdated(address indexed app, AppRegistrationStatus status);
    event AppMetadataURIUpdated(address indexed app, string metadataURI);

    function initialize(address initialOwner) public {
        owner = initialOwner;
    }

    function registerApp(address app) public {
        require(appStatus[app] == AppRegistrationStatus.UNREGISTERED, "AppRegistry: app already registered");
        appStatus[app] = AppRegistrationStatus.REGISTERED;
        emit AppRegistrationStatusUpdated(app, AppRegistrationStatus.REGISTERED);
    }

    function deregisterApp(address app) public {
        require(msg.sender == owner, "AppRegistry: caller is not owner");
        require(appStatus[app] == AppRegistrationStatus.REGISTERED, "AppRegistry: app not registered");
        appStatus[app] = AppRegistrationStatus.UNREGISTERED;
        emit AppRegistrationStatusUpdated(app, AppRegistrationStatus.UNREGISTERED);
    }

    function isAppRegistered(address app) public view returns (bool) {
        return appStatus[app] == AppRegistrationStatus.REGISTERED;
    }
}

contract BitcoinPodManagerTest is Test {
    BitDSMRegistry public bitDSMRegistry;
    BitcoinPodManager public podManager;
    MockAppRegistry public appRegistry;
    address public owner;
    MockDelegationManager public delegationManager;
    MockServiceManager public serviceManager;
    address public operator;
    address public user;
    bytes public operatorBtcPubKey;
    bytes public userBtcAddress;

    function deployProxiedServiceManager() internal returns (MockServiceManager) {
    // Deploy ProxyAdmin if not already deployed
    ProxyAdmin proxyAdmin = new ProxyAdmin();
    
    // Deploy implementation
    MockServiceManager impl = new MockServiceManager();

    // Deploy and initialize proxy in one step
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        address(impl),
        address(proxyAdmin),
        abi.encodeWithSelector(
            MockServiceManager.initialize.selector,
            address(podManager)
        )
    );
    return MockServiceManager(address(proxy));
    }
    function setUp() public {
        delegationManager = new MockDelegationManager();
        bitDSMRegistry = new BitDSMRegistry(IDelegationManager(address(delegationManager)));
        appRegistry = new MockAppRegistry();
        owner = address(this);
        appRegistry.initialize(owner);
        podManager = new BitcoinPodManager();
        serviceManager = deployProxiedServiceManager();
        podManager.initialize(address(appRegistry), address(bitDSMRegistry), address(serviceManager));
      //  serviceManager = new MockServiceManager(address(podManager));
       
        // initialize strategy
        IStrategy mockStrategy = IStrategy(address(0x1234));
        Quorum memory quorum = Quorum({strategies: new StrategyParams[](1)});
        quorum.strategies[0] = StrategyParams({
            strategy: mockStrategy,
            multiplier: 10_000
        });
        
        bitDSMRegistry.initialize(address(serviceManager), 100, quorum); 
        operator = address(0x1);
        user = address(0x2);
        operatorBtcPubKey = hex"02a1633cafcc01ebfb6d78e39f687a1f0995c62fc95f51ead10a02ee0be551b5dc";
        userBtcAddress = hex"76a914ca29dfa9e97fa4f0623742e4f7b90f81bfe5671b88ac";
    }

    function testPodCreation() public {
        // First, register the operator
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);

        // Now, create a pod as the user
        vm.prank(user);
        podManager.createPod(operator, userBtcAddress);

        address podAddress = podManager.getUserPod(user);
        assertTrue(podAddress != address(0), "Pod should be created");

        BitcoinPod pod = BitcoinPod(podAddress);
        assertEq(pod.owner(), user, "Pod owner should be the user");
        assertEq(pod.getOperator(), operator, "Pod operator should be set correctly");
        assertEq(pod.getBitcoinAddress(), userBtcAddress, "Bitcoin address should be set correctly");
        assertEq(pod.getOperatorBtcPubKey(), operatorBtcPubKey, "Operator BTC public key should be set correctly");
    }

    function testCannotCreatePodWithUnregisteredOperator() public {
        vm.prank(user);
        vm.expectRevert("Invalid operator");
        podManager.createPod(operator, userBtcAddress);
    }

    function testCannotCreateMultiplePods() public {
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;  
        // Register operator
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);

        // Create first pod
        vm.prank(user);
        podManager.createPod(operator, userBtcAddress);

        // Try to create second pod
        vm.prank(user);
        vm.expectRevert("User already has a pod");
        podManager.createPod(operator, userBtcAddress);
    }

    function testUserCannotMintBurnOrDeposit() public {
        // Register operator and create pod
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        vm.prank(user);
        podManager.createPod(operator, userBtcAddress);
        
        address podAddress = podManager.getUserPod(user);
        BitcoinPod pod = BitcoinPod(podAddress);

        vm.startPrank(user);
        
        // Test mint
        vm.expectRevert("Only manager can perform this action");
        pod.mint(operator, 100);

        // Test burn
        vm.expectRevert("Only manager can perform this action");
        pod.burn(operator, 50);

        // Remove the deposit test as it's not part of the BitcoinPod contract

        vm.stopPrank();
    }

    function testArbitraryAddressCannotMintOrBurn() public {
        // Register operator and create pod
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator,operatorBtcPubKey);
        vm.prank(user);
        podManager.createPod(operator, userBtcAddress);
        
        address podAddress = podManager.getUserPod(user);
        BitcoinPod pod = BitcoinPod(podAddress);

        address arbitraryAddress = address(0x1234);
        vm.startPrank(arbitraryAddress);
        
        // Test mint
        vm.expectRevert("Only manager can perform this action");
        pod.mint(operator, 100);

        // Test burn
        vm.expectRevert("Only manager can perform this action");
        pod.burn(operator, 50);

        vm.stopPrank();
    }

    function testPodCreationAndOwnership() public {
        // Register operator
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);

        // Create pod as user
        vm.prank(user);
        podManager.createPod(operator, userBtcAddress);

        // Get the pod address
        address podAddress = podManager.getUserPod(user);

        // Check if the pod address is a contract
        assertTrue(podAddress.code.length > 0, "Pod address should be a contract");
    }

    function testDepositFlow() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);
        
        bytes32 txId = bytes32("test_tx_id");
        uint256 depositAmount = 1 ;

        // User initiates deposit request
        vm.prank(user);
        podManager.verifyBitcoinDepositRequest(podAddress, txId, depositAmount);

        // Verify deposit request state
        BitcoinPodManager.BitcoinDepositRequest memory request = podManager.getBitcoinDepositRequest(podAddress);
        assertEq(request.transactionId, txId);
        assertEq(request.amount, depositAmount);
        assertTrue(request.isPending);

        // Service manager confirms deposit
        vm.prank(address(serviceManager));
        podManager.confirmBitcoinDeposit(podAddress, txId, depositAmount);

        // Verify deposit completion
        BitcoinPod pod = BitcoinPod(podAddress);
        assertEq(pod.getBitcoinBalance(), depositAmount);
        assertEq(podManager.getTotalTVL(), depositAmount);

        // Verify request is cleared
        request = podManager.getBitcoinDepositRequest(podAddress);
        assertEq(request.transactionId, bytes32(0));
        assertFalse(request.isPending);
    }

    function testCannotDepositWhilePreviousRequestPending() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);

        // First deposit request
        vm.prank(user);
        podManager.verifyBitcoinDepositRequest(podAddress, bytes32("tx1"), 1 );

        // Try second deposit request
        vm.prank(user);
        vm.expectRevert("Request already pending");
        podManager.verifyBitcoinDepositRequest(podAddress, bytes32("tx2"), 2 );
    }

    function testWithdrawalPSBTFlow() public {
        // Setup pod with balance
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);
        // create deposit request 
        vm.prank(user);
        podManager.verifyBitcoinDepositRequest(podAddress, bytes32("deposit_tx"), 2 );
        // Add some balance first
        vm.prank(address(serviceManager));
        podManager.confirmBitcoinDeposit(podAddress, bytes32("deposit_tx"), 2);

        // Initiate withdrawal
        string memory withdrawAddress = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa";
        vm.prank(user);
        podManager.withdrawBitcoinPSBTRequest(podAddress, withdrawAddress);

        // Verify withdrawal request state
        assertEq(podManager.getBitcoinWithdrawalAddress(podAddress), withdrawAddress);

        // Service manager processes withdrawal
        bytes memory signedPSBT = "signed_psbt_data";
        vm.prank(address(serviceManager));
        podManager.setSignedBitcoinWithdrawTransactionPod(podAddress, signedPSBT);

        // Complete withdrawal
        vm.prank(address(serviceManager));
        podManager.withdrawBitcoinAsTokens(podAddress);

        // Verify final state
        BitcoinPod pod = BitcoinPod(podAddress);
        assertEq(pod.getBitcoinBalance(), 0);
        assertEq(podManager.getTotalTVL(), 0);
        assertEq(podManager.getBitcoinWithdrawalAddress(podAddress), "");
    }

    function testAppDelegationFlow() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);

        // create deposit request 
        vm.prank(user);
        podManager.verifyBitcoinDepositRequest(podAddress, bytes32("deposit_tx"), 2 );
        // confirm deposit
        vm.prank(address(serviceManager));
        podManager.confirmBitcoinDeposit(podAddress, bytes32("deposit_tx"), 2);

        // Register app
        address app = address(0x123);
        vm.prank(owner);
        appRegistry.registerApp(app);

        // Delegate pod
        vm.prank(user);
        podManager.delegatePod(podAddress, app);
        assertEq(podManager.getPodApp(podAddress), app);

        // Test app locking
        vm.prank(app);
        podManager.lockPod(podAddress);
        assertTrue(BitcoinPod(podAddress).isLocked());

        // Test app unlocking
        vm.prank(app);
        podManager.unlockPod(podAddress);
        assertFalse(BitcoinPod(podAddress).isLocked());

        // Undelegate pod
        vm.prank(user);
        podManager.undelegatePod(podAddress);
        assertEq(podManager.getPodApp(podAddress), address(0));
    }

    function testCannotWithdrawFromLockedPod() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);

        // Register and delegate to app
        address app = address(0x123);
        vm.prank(owner);
        appRegistry.registerApp(app);
        
        vm.prank(user);
        podManager.delegatePod(podAddress, app);

        // Lock pod
        vm.prank(app);
        podManager.lockPod(podAddress);

        // Try withdrawal
        vm.prank(user);
        vm.expectRevert("Pod is locked");
        podManager.withdrawBitcoinPSBTRequest(podAddress, "withdraw_address");
    }

    function testCannotWithdrawFromDelegatedPod() public {
        // Setup
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);

        // Register and delegate to app
        address app = address(0x123);
        vm.prank(owner);
        appRegistry.registerApp(app);
        
        // Add console logs to verify state
        console.log("App registered:", appRegistry.isAppRegistered(app));
        
        vm.prank(user);
        podManager.delegatePod(podAddress, app);
        
        // Verify delegation
        console.log("Pod delegated to:", podManager.getPodApp(podAddress));
        console.log("Expected app:", app);

        // Try withdrawal with specific error message
        vm.prank(user);
        vm.expectRevert("Pod is delegated");
        podManager.withdrawBitcoinPSBTRequest(podAddress, "withdraw_address");
    }

    function testPauseUnpauseFlow() public {
        // Pause contract
        podManager.pause();
        
        // Try to create pod while paused
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        podManager.createPod(operator, userBtcAddress);

        // Unpause and verify operations work
        podManager.unpause();
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);
        assertNotEq(podAddress, address(0));
    }

    function testCompleteWithdrawalFlow() public {
        // Setup pod with balance
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator);
        bitDSMRegistry.registerOperatorWithSignature(operatorSignature, operator, operatorBtcPubKey);
        
        vm.prank(user);
        address podAddress = podManager.createPod(operator, userBtcAddress);
        // create deposit request 
        vm.prank(user);
        podManager.verifyBitcoinDepositRequest(podAddress, bytes32("deposit_tx"), 2 );
        // Add balance
        vm.prank(address(serviceManager));
        podManager.confirmBitcoinDeposit(podAddress, bytes32("deposit_tx"), 2);

        // Initiate complete withdrawal
        string memory withdrawAddress = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa";
        bytes memory preSignedTx = "pre_signed_tx_data";
        vm.prank(user);
        podManager.withdrawBitcoinCompleteTxRequest(podAddress, preSignedTx, withdrawAddress);

        // Service manager completes withdrawal
        bytes memory completeTx = "complete_tx_data";
        vm.startPrank(address(serviceManager));
        podManager.setSignedBitcoinWithdrawTransactionPod(podAddress, completeTx);
        podManager.withdrawBitcoinAsTokens(podAddress);
        vm.stopPrank();

        // Verify final state
        BitcoinPod pod = BitcoinPod(podAddress);
        assertEq(pod.getBitcoinBalance(), 0);
        assertEq(podManager.getTotalTVL(), 0);
        assertEq(podManager.getBitcoinWithdrawalAddress(podAddress), "");
    }
}