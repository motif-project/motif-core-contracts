// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/libraries/BitcoinUtils.sol";

contract BitcoinUtilsTest is Test {
    using BitcoinUtils for bytes;

    event ScriptProcessed(bytes32 indexed witnessProgram);

    function testConvertBits() public pure {
        //Test case 1: Convert 8-bit to 5-bit
        bytes memory input1 = hex"FF"; // 11111111 in binary
        bytes memory expected1 = hex"1F1C"; // 11111 11100
        bytes memory result1 = BitcoinUtils._convertBits(input1, 8, 5, true);
        assertEq(result1.length, expected1.length, "Length mismatch for 8->5 conversion");
        assertEq(result1, expected1, "Incorrect 8->5 bit conversion");

        // Test case 2: Multiple bytes
        bytes memory input2 = hex"FFFF"; // 11111111 11111111
        bytes memory expected2 = hex"1F1F1F10"; // 11111 11111 11111 10000
        bytes memory result2 = BitcoinUtils._convertBits(input2, 8, 5, true);
        assertEq(result2.length, expected2.length, "Length mismatch for multiple bytes");
        assertEq(result2, expected2, "Incorrect multiple byte conversion");

        // Test case 3: Empty input
        bytes memory input3 = "";
        bytes memory result3 = BitcoinUtils._convertBits(input3, 8, 5, true);
        assertEq(result3.length, 0, "Empty input should return empty output");

        // test case 4: reference test case
        bytes memory input4 = hex"ab38e9a92e1bdabd59bb4095f6e0a16f9e1e95c71b47465e86f480a80c536813"; 
        bytes memory expected4 = hex"150c1c0e130a090e030f0d0b1a160d1b08020a1f0d1805010d1e0f011d050e07030d03140c1714061e12000a100302130d000910";
        bytes memory result4 = BitcoinUtils._convertBits(input4, 8, 5, true);
        assertEq(result4, expected4, "Incorrect reference test case");
    
    }

    function testCreateChecksum() public pure{
        // Test case for signet address
        bytes memory hrp = "tb";
        bytes memory data = hex"00150c1c0e130a090e030f0d0b1a160d1b08020a1f0d1805010d1e0f011d050e07030d03140c1714061e12000a100302130d000910"; // Example data
       
        bytes memory checksum = BitcoinUtils._createChecksum(hrp, data);
        assertEq(checksum.length, 6, "Checksum should be 6 bytes");
        
        // Known good checksum for this combination
        bytes memory expectedChecksum = hex"03100e001510"; // Replace with actual expected checksum
        assertEq(checksum.length, expectedChecksum.length, "Checksum length mismatch");
        assertEq(checksum, expectedChecksum, "Checksum mismatch");
    }

    function testConvertScriptPubKeyToBech32Address() public pure{
        
        // creaate withness script
        bytes memory script = hex"522103cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b02103809fa6d4203620e2532d27d482082de8ec866845124038c38bb02e2229dc6cdb52ae";
        bytes32 scriptPubKey = BitcoinUtils.getWitnessProgram(script);
        // convert scriptPubKey to bytes
        bytes memory scriptPubKeyBytes = new bytes(32);
        assembly {
            mstore(add(scriptPubKeyBytes, 32), scriptPubKey)
        }
        // Test case 1: P2WSH address
        //bytes32 scriptPubKey = bytes32(hex"ab38e9a92e1bdabd59bb4095f6e0a16f9e1e95c71b47465e86f480a80c536813");
        string memory expected = "tb1q3tndt980zwsmg8veckdqp8z6es5vsdz95f2rpu63dcn3lea27k3q2lx63u";
       // bytes scriptPubKey = hex"0xbfcca6233013df0aa07a900170f479172eb19076";
        string memory result = BitcoinUtils.convertScriptPubKeyToBech32Address(scriptPubKeyBytes);
        console.log("Result:", result);
        console.log("Result lenght", bytes(result).length);
        assertEq(result, expected, "Incorrect bech32 address conversion");

    }
    function testExtractPublicKeys() public pure{
        bytes memory script = hex"522103cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b02103809fa6d4203620e2532d27d482082de8ec866845124038c38bb02e2229dc6cdb52ae";
        bytes memory expectedPubKey1 = hex"03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
        bytes memory expectedPubKey2 = hex"03809fa6d4203620e2532d27d482082de8ec866845124038c38bb02e2229dc6cdb";
        (bytes memory pubKey1, bytes memory pubKey2) = BitcoinUtils.extractPublicKeys(script);
        assertEq(pubKey1.length, expectedPubKey1.length, "pubKey length should be equal");
        assertEq(pubKey1, expectedPubKey1, "pubKey should be equal");
        assertEq(pubKey2.length, expectedPubKey2.length, "pubKey length should be equal");
        assertEq(pubKey2, expectedPubKey2, "pubKey should be equal");
    }
    function testExtractVoutFromPSBT() public pure{
        bytes memory psbt = hex"70736274ff01005202000000010ae75c05525a16550f06a871ae31b5ecbfc778c0f7fc33e7d15cb956cb2479370000000000f5ffffff017f25000000000000160014bfcca6233013df0aa07a900170f479172eb19076000000000001007d0200000001c70045a2d38337557c4fc9bf65c11dee5c9334328d80bfc040bdc9f57ba1491e0100000000ffffffff021027000000000000220020a816306ea7aa56b85c885244b4b42af2204c2c0b8716734bc7c9e327dc93b2b25e0201000000000016001479f554a3171903aae7a975d7b5de42bf45ee12500000000001012b1027000000000000220020a816306ea7aa56b85c885244b4b42af2204c2c0b8716734bc7c9e327dc93b2b2220203cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b047304402206e62db59302da26342fa718b51bf6f7f49c77413dc6ad0954c7f667fe3d48e2a02200b8d4c61ad840563dd08aeaa47d092d4c4733b195a2e20339699237c7475923881010547522103cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b02103d00e88ffd1282cc378398d624566e76a1c631858cadfc7dc6c06e517f22fa48d52ae220603cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b018aba9403b5400008001000080000000800000000000000000220603d00e88";
        uint256 expectedAmount  =  9599;
        string memory expectedBech32Address = "tb1qhlx2vgesz00s4gr6jqqhparezuhtryrkpnd7tm";
        // extract output/s from PSBT
        BitcoinUtils.Output[] memory outputs = BitcoinUtils.extractVoutFromPSBT(psbt);
        // extract scriptPubKey from output
        bytes memory scriptPubKey = outputs[0].scriptPubKey;
        // extract amount from output
        uint256 amount = outputs[0].value;
      
        //convert scriptPubKey to bech32 address
        string memory bech32Address = BitcoinUtils.convertScriptPubKeyToBech32Address(scriptPubKey);
        assertEq(bech32Address, expectedBech32Address, "Bech32 Address should be equal");
        assertEq(amount, expectedAmount, "Output Value should be equal");
    }
    // Test vectors for specific Bitcoin addresses
    function testKnownAddresses() public pure{
        // Test vector 1: Native SegWit P2WSH
        bytes memory script1 = hex"0020a1c56d436c786b7288c70576f2f9dae9b4f4b3a99f5c26e2c14c57aa6d19e1c7";
        string memory expected1 = "tb1qqqs2r3tdgdk8s6mj3rrs2ahjl8dwnd85kw5e7hpxutq5c4a2d5v7r3cskcr2m";
        string memory result1 = BitcoinUtils.convertScriptPubKeyToBech32Address(script1);
        assertEq(result1, expected1, "Test vector 1 failed");

        // Test vector 2: Native SegWit P2WPKH
        bytes memory script2 = hex"b6a9c8dc23010b515c667baad3bcd72206af4747";
        string memory expected2 = "tb1qk65u3hprqy94zhrx0w4d80xhygr27368m3jr4a";
        string memory result2 = BitcoinUtils.convertScriptPubKeyToBech32Address(script2);
        assertEq(result2, expected2, "Test vector 2 failed");

        
    }

    // Test error cases
    function testErrorCases() public{
        // Test empty script
        bytes memory emptyScript = "";
        vm.expectRevert("Invalid scriptPubKey length");
        BitcoinUtils.convertScriptPubKeyToBech32Address(emptyScript);
    }
    // test bytes array eqality 
    function testAreEqualHash() public pure{
        string memory key1 = "03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
        string memory key2 = "03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
       assertEq(keccak256(bytes(key1)), keccak256(bytes(key2)), "Keys are not equal");
    }
    function testAreEqual() public pure{
        bytes memory key1 = "03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
        bytes memory key2 = "03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
        bool result = true;
        for (uint256 i = 0; i < key1.length; i++) {
            if (key1[i] != key2[i]) {
                result = false;
                break;
            }
        }
        assertEq(result, true, "Keys are not equal");
    }

    function compareStringsAssemblyHelper(string memory s1, string memory s2) public pure returns (bool) {
        bool result;
        assembly {
            // Load the length of first string from the first word
            let len1 := mload(s1)
            // Load the length of second string from the first word
            let len2 := mload(s2)
            
            // If lengths not equal, set result to false
            if iszero(eq(len1, len2)) {
                result := 0
            }
            
            // Initialize result to true if lengths match
            result := 1
            
            // Compare word by word
            let wordCount := add(div(len1, 32), 1)  // Round up division
            
            // Skip the length slots
            let ptr1 := add(s1, 32)
            let ptr2 := add(s2, 32)
            
            // Compare each word
            for { let i := 0 } lt(i, wordCount) { i := add(i, 1) } {
                if iszero(eq(mload(add(ptr1, mul(i, 32))), mload(add(ptr2, mul(i, 32))))) {
                    // Set result to false if any word differs
                    result := 0
                }
            }
        }
        return result;
    }

    function testStringComparisonBenchmark() public view{
        string memory key1 = "03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
        string memory key2 = "03cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b0";
        
        // Test hash approach
        uint256 gasStart1 = gasleft();
        keccak256(bytes(key1)) == keccak256(bytes(key2));
        uint256 gasUsed1 = gasStart1 - gasleft();
        
        // Test assembly approach
        uint256 gasStart2 = gasleft();
        compareStringsAssemblyHelper(key1, key2);
        uint256 gasUsed2 = gasStart2 - gasleft();
        
        // check if gasUsed1 is less than gasUsed2
        assertLt(gasUsed1, gasUsed2, "Hash comparison should be faster than assembly comparison");
    }

    function testEventEmission() public {
        bytes memory script = hex"522103cb23542f698ed1e617a623429b585d98fb91e44839949db4126b2a0d5a7320b02103809fa6d4203620e2532d27d482082de8ec866845124038c38bb02e2229dc6cdb52ae";
        bytes32 witnessProgram = BitcoinUtils.getWitnessProgram(script);
        vm.expectEmit(true, false, false, false);
        emit ScriptProcessed(witnessProgram);
    }
} 
