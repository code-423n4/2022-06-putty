// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/utils/Strings.sol";

import "src/PuttyV2.sol";
import "../shared/Fixture.t.sol";

contract TestEIP712 is Fixture {
    address[] internal addrArr;
    PuttyV2.ERC20Asset[] internal erc20Assets;
    PuttyV2.ERC721Asset[] internal erc721Assets;

    function testRecoveredSignerMatchesEthersEIP712Implementation() public {
        PuttyV2.Order memory order = PuttyV2.Order({
            maker: babe,
            isCall: false,
            isLong: false,
            baseAsset: bob,
            strike: 1,
            premium: 2,
            duration: 3,
            expiration: 4,
            nonce: 5,
            whitelist: addrArr,
            floorTokens: addrArr,
            erc20Assets: erc20Assets,
            erc721Assets: erc721Assets
        });

        testRecoveredSignerMatchesEthersEIP712Implementation(order);
    }

    function testRecoveredSignerMatchesEthersEIP712Implementation(PuttyV2.Order memory order) public {
        // arrange
        string[] memory runJsInputs = new string[](5);
        runJsInputs[0] = "node";
        runJsInputs[1] = "./test/differential/scripts/sign-order/sign-order-cli.js";
        runJsInputs[2] = toHexString(abi.encode(order));
        runJsInputs[3] = Strings.toHexString(address(p));
        runJsInputs[4] = toHexString(abi.encode(babePrivateKey));

        // act
        bytes memory ethersSignature = vm.ffi(runJsInputs);
        bytes32 orderHash = p.hashOrder(order);
        address recoveredAddress = ECDSA.recover(orderHash, ethersSignature);

        // assert
        assertEq(recoveredAddress, babe, "Should have recovered signing address");
    }

    function testOrderHashMatchesEthersEIP712Implementation() public {
        PuttyV2.Order memory order = PuttyV2.Order({
            maker: babe,
            isCall: false,
            isLong: false,
            baseAsset: bob,
            strike: 1,
            premium: 2,
            duration: 3,
            expiration: 4,
            nonce: 5,
            whitelist: addrArr,
            floorTokens: addrArr,
            erc20Assets: erc20Assets,
            erc721Assets: erc721Assets
        });

        testOrderHashMatchesEthersEIP712Implementation(order);
    }

    function testOrderHashMatchesEthersEIP712Implementation(PuttyV2.Order memory order) public {
        // arrange
        string[] memory runJsInputs = new string[](4);
        runJsInputs[0] = "node";
        runJsInputs[1] = "./test/differential/scripts/hash-order/hash-order-cli.js";
        runJsInputs[2] = toHexString(abi.encode(order));
        runJsInputs[3] = Strings.toHexString(address(p));

        // act
        bytes memory ethersResult = vm.ffi(runJsInputs);
        bytes32 ethersGeneratedHash = abi.decode(ethersResult, (bytes32));
        bytes32 orderHash = p.hashOrder(order);

        // assert
        assertEq(orderHash, ethersGeneratedHash, "Should have generated same hash as ethers implementation");
    }

    function toHexString(bytes memory input) public pure returns (string memory) {
        require(input.length < type(uint256).max / 2 - 1, "Invalid input");
        bytes16 symbols = "0123456789abcdef";
        bytes memory hexBuffer = new bytes(2 * input.length + 2);
        hexBuffer[0] = "0";
        hexBuffer[1] = "x";

        uint256 pos = 2;
        uint256 length = input.length;
        for (uint256 i = 0; i < length; ++i) {
            uint256 _byte = uint8(input[i]);
            hexBuffer[pos++] = symbols[_byte >> 4];
            hexBuffer[pos++] = symbols[_byte & 0xf];
        }

        return string(hexBuffer);
    }
}
