// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {Test, console} from "forge-std/Test.sol";
import "../src/core/BitDSMRegistry.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IBitDSMRegistry} from "../src/interfaces/IBitDSMRegistry.sol";

import {ISignatureUtils} from "@eigenlayer/src/contracts/interfaces/ISignatureUtils.sol";
import {IDelegationManager} from "@eigenlayer/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "@eigenlayer/src/contracts/interfaces/IStrategy.sol";

import {ECDSAStakeRegistry} from "../src/libraries/ECDSAStakeRegistry.sol";
import {
    ECDSAStakeRegistryEventsAndErrors,
    Quorum,
    StrategyParams
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";

contract MockServiceManager {
    // solhint-disable-next-line
    function deregisterOperatorFromAVS(address) external {}

    function registerOperatorToAVS(
        address,
        ISignatureUtils.SignatureWithSaltAndExpiry memory // solhint-disable-next-line
    ) external {}
}

contract MockDelegationManager {
    function operatorShares(address, address) external pure returns (uint256) {
        return 1000; // Return a dummy value for simplicity
    }

    function getOperatorShares(address, address[] memory strategies) external pure returns (uint256[] memory) {
        uint256[] memory response = new uint256[](strategies.length);
        for (uint256 i; i < strategies.length; i++) {
            response[i] = 1000;
        }
        return response; // Return a dummy value for simplicity
    }
}

contract BitDSMRegistryTest is Test, ECDSAStakeRegistryEventsAndErrors {
    BitDSMRegistry public registry;
    // address public owner;
    MockDelegationManager public mockDelegationManager;
    MockServiceManager public mockServiceManager;
    uint256 public operatorPrvKey;
    address public operator;
    bytes public validBtcPublicKey;
    bytes public validBtcPublicKey2;
    address internal operator1;
    address internal operator2;
    uint256 internal operator1PrvKey;
    uint256 internal operator2PrvKey;
    bytes internal signature1;
    bytes internal signature2;
    address[] internal signers;
    bytes[] internal signatures;
    bytes32 internal msgHash;

    function setUp() public {
        //owner = address(this);
        (operator, operatorPrvKey) = makeAddrAndKey("Signer");
        (operator1, operator1PrvKey) = makeAddrAndKey("Signer 1");
        (operator2, operator2PrvKey) = makeAddrAndKey("Signer 2");
        validBtcPublicKey = hex"02a0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcde";
        validBtcPublicKey2 = hex"03a0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcde";
        // initialize mock contracts
        mockDelegationManager = new MockDelegationManager();
        mockServiceManager = new MockServiceManager();

        // initialize strategy
        IStrategy mockStrategy = IStrategy(address(0x1234));
        Quorum memory quorum = Quorum({strategies: new StrategyParams[](1)});
        quorum.strategies[0] = StrategyParams({strategy: mockStrategy, multiplier: 10_000});

        // Deploy registry
        registry = new BitDSMRegistry(IDelegationManager(address(mockDelegationManager)));

        registry.initialize(address(mockServiceManager), 100, quorum);
        // register operator1
        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;
        vm.prank(operator1);
        registry.registerOperatorWithSignature(operatorSignature, operator1, validBtcPublicKey);
        vm.prank(operator2);
        registry.registerOperatorWithSignature(operatorSignature, operator2, validBtcPublicKey2);
        vm.roll(block.number + 1);
    }

    function testRegisterOperator() public {
        // Create signature
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;

        vm.prank(operator);

        registry.registerOperatorWithSignature(signature, operator, validBtcPublicKey);
        assertTrue(registry.operatorRegistered(operator));
        assertTrue(registry.isOperatorBtcKeyRegistered(operator));
        assertEq(registry.getOperatorBtcPublicKey(operator), validBtcPublicKey);
        assertEq(registry.getLastCheckpointOperatorWeight(operator), 1000);
    }

    function testFailRegisterWithInvalidBtcKey() public {
        bytes memory invalidBtcKey = new bytes(32); // Wrong length

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        vm.prank(operator);
        registry.registerOperatorWithSignature(operatorSignature, operator, invalidBtcKey);
    }

    function testDeregisterOperator() public {
        // operator1 is already registered in setUp

        assertEq(registry.getLastCheckpointOperatorWeight(operator1), 1000);
        vm.prank(operator1);

        registry.deregisterOperator();

        assertFalse(registry.isOperatorBtcKeyRegistered(operator1));
        assertEq(registry.getLastCheckpointOperatorWeight(operator1), 0);
        vm.expectRevert("Operator not registered");
        registry.getOperatorBtcPublicKey(operator1);
    }

    function test_RevertsWhen_NotOperator_DeregisterOperator() public {
        address notOperator = address(0x2);
        vm.prank(notOperator);
        vm.expectRevert("Operator not registered");
        registry.deregisterOperator();
    }

    function test_RegisterOperatorWithSignature() public {
        address operatorLocal = address(0x125);
        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        vm.prank(operatorLocal);
        registry.registerOperatorWithSignature(signature, operatorLocal, validBtcPublicKey);
        assertTrue(registry.operatorRegistered(operatorLocal));
        assertEq(registry.getLastCheckpointOperatorWeight(operatorLocal), 1000);
    }

    function test_RevertsWhen_AlreadyRegistered_RegisterOperatorWithSignature() public {
        assertEq(registry.getLastCheckpointOperatorWeight(operator1), 1000);
        assertEq(registry.getLastCheckpointTotalWeight(), 2000);

        ISignatureUtils.SignatureWithSaltAndExpiry memory signature;
        vm.expectRevert("Operator already registered");
        vm.prank(operator1);
        registry.registerOperatorWithSignature(signature, operator1, validBtcPublicKey);
    }

    function test_RevertsWhen_SignatureIsInvalid_RegisterOperatorWithSignature() public {
        bytes memory signatureData;
        vm.mockCall(
            address(mockServiceManager),
            abi.encodeWithSelector(
                MockServiceManager.registerOperatorToAVS.selector,
                operator1,
                ISignatureUtils.SignatureWithSaltAndExpiry({
                    signature: signatureData,
                    salt: bytes32(uint256(0x120)),
                    expiry: 10
                })
            ),
            abi.encode(50)
        );
    }

    // Define private and public keys for operator3 and signer
    uint256 private operator3PrvKey = 3;
    address private operator3 = address(vm.addr(operator3PrvKey));
    uint256 private signerPrvKey = 4;
    address private signer = address(vm.addr(signerPrvKey));

    function test_WhenUsingSigningKey_RegierOperatorWithSignature() public {
        address operatorLocal = operator3;

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        // Register operator with a different signing key
        vm.prank(operatorLocal);
        registry.registerOperatorWithSignature(operatorSignature, signer, validBtcPublicKey);

        // Verify that the signing key has been successfully registered for the operator
        address registeredSigningKey = registry.getLastestOperatorSigningKey(operatorLocal);
        assertEq(registeredSigningKey, signer, "The registered signing key does not match the provided signing key");
    }

    function test_Twice_RegierOperatorWithSignature() public {
        address operatorLocal = operator3;

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        // Register operator with a different signing key
        vm.prank(operatorLocal);
        registry.registerOperatorWithSignature(operatorSignature, signer, validBtcPublicKey);

        /// Register a second time
        vm.prank(operatorLocal);
        registry.updateOperatorSigningKey(address(420));

        // Verify that the signing key has been successfully registered for the operator
        address registeredSigningKey = registry.getLastestOperatorSigningKey(operatorLocal);

        vm.roll(block.number + 1);
        registeredSigningKey = registry.getOperatorSigningKeyAtBlock(operatorLocal, uint32(block.number - 1));
        assertEq(
            registeredSigningKey, address(420), "The registered signing key does not match the provided signing key"
        );
    }

    function test_WhenUsingSigningKey_CheckSignatures() public {
        address operatorLocal = operator3;

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature;

        // Register operator with a different signing key
        vm.prank(operatorLocal);
        registry.registerOperatorWithSignature(operatorSignature, signer, validBtcPublicKey);
        vm.roll(block.number + 1);

        // Prepare data for signature
        bytes32 dataHash = keccak256("data");
        address[] memory operators = new address[](1);
        operators[0] = operatorLocal;
        bytes[] memory signaturesLocal = new bytes[](1);

        // Generate signature using the signing key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrvKey, dataHash);
        signaturesLocal[0] = abi.encodePacked(r, s, v);

        // Check signatures using the registered signing key
        registry.isValidSignature(dataHash, abi.encode(operators, signaturesLocal, block.number - 1));
    }

    function test_UpdateQuorumConfig() public {
        IStrategy mockStrategy = IStrategy(address(420));

        Quorum memory oldQuorum = registry.quorum();
        Quorum memory newQuorum = Quorum({strategies: new StrategyParams[](1)});
        newQuorum.strategies[0] = StrategyParams({strategy: mockStrategy, multiplier: 10_000});
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        vm.expectEmit(true, true, false, true);
        emit QuorumUpdated(oldQuorum, newQuorum);

        registry.updateQuorumConfig(newQuorum, operators);
    }

    function test_RevertsWhen_InvalidQuorum_UpdateQuourmConfig() public {
        Quorum memory invalidQuorum = Quorum({strategies: new StrategyParams[](1)});
        invalidQuorum.strategies[0] = StrategyParams({
            /// TODO: Make mock strategy
            strategy: IStrategy(address(420)),
            multiplier: 5000 // This should cause the update to revert as it's not the total required
        });
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        vm.expectRevert(ECDSAStakeRegistryEventsAndErrors.InvalidQuorum.selector);
        registry.updateQuorumConfig(invalidQuorum, operators);
    }

    function test_RevertsWhen_NotOwner_UpdateQuorumConfig() public {
        Quorum memory validQuorum = Quorum({strategies: new StrategyParams[](1)});
        validQuorum.strategies[0] = StrategyParams({strategy: IStrategy(address(420)), multiplier: 10_000});

        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        address nonOwner = address(0x123);
        vm.prank(nonOwner);

        vm.expectRevert("Ownable: caller is not the owner");
        registry.updateQuorumConfig(validQuorum, operators);
    }

    function test_When_Empty_UpdateOperators() public {
        address[] memory operators = new address[](0);
        registry.updateOperators(operators);
    }

    function test_When_OperatorNotRegistered_UpdateOperators() public {
        address[] memory operators = new address[](3);
        address operatorTmp = address(0xBEEF);
        operators[0] = operator1;
        operators[1] = operator2;
        operators[2] = operatorTmp;
        registry.updateOperators(operators);
        assertEq(registry.getLastCheckpointOperatorWeight(operatorTmp), 0);
    }

    function test_When_SingleOperator_UpdateOperators() public {
        address[] memory operators = new address[](1);
        operators[0] = operator1;

        registry.updateOperators(operators);
        uint256 updatedWeight = registry.getLastCheckpointOperatorWeight(operator1);
        assertEq(updatedWeight, 1000);
    }

    function test_RevertSWhen_Duplicate_UpdateQuorumConfig() public {
        Quorum memory invalidQuorum = Quorum({strategies: new StrategyParams[](2)});
        invalidQuorum.strategies[0] = StrategyParams({strategy: IStrategy(address(420)), multiplier: 5000});
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        invalidQuorum.strategies[1] = StrategyParams({strategy: IStrategy(address(420)), multiplier: 5000});
        vm.expectRevert(ECDSAStakeRegistryEventsAndErrors.NotSorted.selector);
        registry.updateQuorumConfig(invalidQuorum, operators);
    }

    function test_RevertSWhen_NotSorted_UpdateQuorumConfig() public {
        Quorum memory invalidQuorum = Quorum({strategies: new StrategyParams[](2)});
        invalidQuorum.strategies[0] = StrategyParams({strategy: IStrategy(address(420)), multiplier: 5000});
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        invalidQuorum.strategies[1] = StrategyParams({strategy: IStrategy(address(419)), multiplier: 5000});
        vm.expectRevert(ECDSAStakeRegistryEventsAndErrors.NotSorted.selector);
        registry.updateQuorumConfig(invalidQuorum, operators);
    }

    function test_RevertSWhen_OverMultiplierTotal_UpdateQuorumConfig() public {
        Quorum memory invalidQuorum = Quorum({strategies: new StrategyParams[](1)});
        invalidQuorum.strategies[0] = StrategyParams({strategy: IStrategy(address(420)), multiplier: 10_001});
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;

        vm.expectRevert(ECDSAStakeRegistryEventsAndErrors.InvalidQuorum.selector);
        registry.updateQuorumConfig(invalidQuorum, operators);
    }

    function test_UpdateMinimumWeight() public {
        uint256 initialMinimumWeight = registry.minimumWeight();
        uint256 newMinimumWeight = 5000;

        assertEq(initialMinimumWeight, 0); // Assuming initial state is 0

        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;
        registry.updateMinimumWeight(newMinimumWeight, operators);

        uint256 updatedMinimumWeight = registry.minimumWeight();
        assertEq(updatedMinimumWeight, newMinimumWeight);
    }

    function test_RevertsWhen_NotOwner_UpdateMinimumWeight() public {
        uint256 newMinimumWeight = 5000;
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;
        vm.prank(address(0xBEEF)); // An arbitrary non-owner address
        vm.expectRevert("Ownable: caller is not the owner");
        registry.updateMinimumWeight(newMinimumWeight, operators);
    }

    function test_When_SameWeight_UpdateMinimumWeight() public {
        uint256 initialMinimumWeight = 5000;
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;
        registry.updateMinimumWeight(initialMinimumWeight, operators);

        uint256 updatedMinimumWeight = registry.minimumWeight();
        assertEq(updatedMinimumWeight, initialMinimumWeight);
    }

    function test_When_Weight0_UpdateMinimumWeight() public {
        uint256 initialMinimumWeight = 5000;
        address[] memory operators = new address[](2);
        operators[0] = operator1;
        operators[1] = operator2;
        registry.updateMinimumWeight(initialMinimumWeight, operators);

        uint256 newMinimumWeight = 0;

        registry.updateMinimumWeight(newMinimumWeight, operators);

        uint256 updatedMinimumWeight = registry.minimumWeight();
        assertEq(updatedMinimumWeight, newMinimumWeight);
    }

    function testUpdateThresholdStake_UpdateThresholdStake() public {
        uint256 thresholdWeight = 10_000_000_000;
        vm.prank(registry.owner());
        registry.updateStakeThreshold(thresholdWeight);
    }

    function test_RevertsWhen_NotOwner_UpdateThresholdStake() public {
        uint256 thresholdWeight = 10_000_000_000;
        address notOwner = address(0x123);
        vm.prank(notOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        registry.updateStakeThreshold(thresholdWeight);
    }

    function testPauseUnpause() public {
        registry.pause();
        assertTrue(registry.paused());

        registry.unpause();
        assertFalse(registry.paused());
    }

    function testFailPauseByNonOwner() public {
        vm.prank(address(0xdead));
        registry.pause();
    }
}
