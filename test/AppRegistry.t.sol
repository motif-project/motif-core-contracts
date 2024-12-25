// test/AppRegistry.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/core/AppRegistry.sol";

contract AppRegistryTest is Test {
    event AppRegistrationStatusUpdated(address indexed app, AppRegistrationStatus status);
    event AppMetadataURIUpdated(address indexed app, string newURI);

    enum AppRegistrationStatus {
        UNREGISTERED,
        REGISTERED
    }

    AppRegistry public appRegistry;
    address public owner;
    address public app;
    uint256 private signerPrivateKey;

    function setUp() public {
        signerPrivateKey = vm.envUint("PRIVATE_KEY");
        owner = address(this);
        app = vm.addr(signerPrivateKey);

        appRegistry = new AppRegistry();
        appRegistry.initialize(owner);
    }

    function testRegisterApp() public {
        bytes32 salt = keccak256("test_salt");
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 digestHash = appRegistry.calculateAppRegistrationDigestHash(app, address(appRegistry), salt, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectEmit(true, true, false, true);
        emit AppRegistrationStatusUpdated(app, AppRegistrationStatus.REGISTERED);

        vm.prank(app);
        appRegistry.registerApp(app, signature, salt, expiry);

        assertTrue(appRegistry.isAppRegistered(app));
        assertTrue(appRegistry.appSaltIsSpent(app, salt));
    }

    function testDeregisterApp() public {
        // First, register the app
        testRegisterApp();

        // Now deregister
        vm.prank(owner);
        appRegistry.deregisterApp(app);

        assertFalse(appRegistry.isAppRegistered(app));
    }

    function testCannotRegisterTwice() public {
        testRegisterApp();

        bytes32 salt = keccak256("new_salt");
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 digestHash = appRegistry.calculateAppRegistrationDigestHash(app, address(appRegistry), salt, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(IAppRegistry.AppAlreadyRegistered.selector));
        vm.prank(app);
        appRegistry.registerApp(app, signature, salt, expiry);
    }

    function testCannotUseExpiredSignature() public {
        bytes32 salt = keccak256("test_salt");
        uint256 expiry = block.timestamp - 1; // Expired

        bytes32 digestHash = appRegistry.calculateAppRegistrationDigestHash(app, address(appRegistry), salt, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(IAppRegistry.SignatureExpired.selector));
        vm.prank(app);
        appRegistry.registerApp(app, signature, salt, expiry);
    }

    function testPause() public {
        vm.prank(owner);
        appRegistry.pause();
        assertTrue(appRegistry.paused());

        // Try to register while paused
        bytes32 salt = keccak256("test_salt");
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 digestHash = appRegistry.calculateAppRegistrationDigestHash(app, address(appRegistry), salt, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert("Pausable: paused");
        vm.prank(app);
        appRegistry.registerApp(app, signature, salt, expiry);
    }

    function testUnpause() public {
        vm.prank(owner);
        appRegistry.pause();

        vm.prank(owner);
        appRegistry.unpause();
        assertFalse(appRegistry.paused());
    }

    function testCancelSalt() public {
        bytes32 salt = keccak256("test_salt");

        vm.prank(app);
        appRegistry.cancelSalt(salt);

        // Try to register with cancelled salt
        uint256 expiry = block.timestamp + 1 hours;
        bytes32 digestHash = appRegistry.calculateAppRegistrationDigestHash(app, address(appRegistry), salt, expiry);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, digestHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.expectRevert(abi.encodeWithSelector(IAppRegistry.SaltAlreadySpent.selector));
        vm.prank(app);
        appRegistry.registerApp(app, signature, salt, expiry);
    }

    function testUpdateAppMetadataURI() public {
        // First register the app
        testRegisterApp();

        string memory newURI = "ipfs://newuri";
        vm.prank(app);
        vm.expectEmit(true, true, false, true);
        emit AppMetadataURIUpdated(app, newURI);
        appRegistry.updateAppMetadataURI(newURI);
    }

    function testOnlyOwnerCanPause() public {
        vm.prank(app);
        vm.expectRevert("Ownable: caller is not the owner");
        appRegistry.pause();
    }

    function testOnlyOwnerCanUnpause() public {
        vm.prank(owner);
        appRegistry.pause();

        vm.prank(app);
        vm.expectRevert("Ownable: caller is not the owner");
        appRegistry.unpause();
    }

    function testCannotUpdateMetadataIfNotRegistered() public {
        vm.prank(app);
        vm.expectRevert(abi.encodeWithSelector(IAppRegistry.AppNotRegistered.selector));
        appRegistry.updateAppMetadataURI("ipfs://newuri");
    }

    function testCannotDeregisterUnregisteredApp() public {
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAppRegistry.AppNotRegistered.selector));
        appRegistry.deregisterApp(app);
    }
}
