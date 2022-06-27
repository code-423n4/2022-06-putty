// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";
import "openzeppelin/utils/Strings.sol";

import "src/PuttyV2.sol";
import "../shared/Fixture.t.sol";

contract TestNft is Fixture {
    uint256[] internal floorAssetTokenIds;

    function setUp() public {
        deal(address(weth), address(this), 0xffffffff);
        deal(address(weth), babe, 0xffffffff);

        weth.approve(address(p), type(uint256).max);

        vm.prank(babe);
        weth.approve(address(p), type(uint256).max);
    }

    function testItCannotQueryTokenURIForTokenThatDoesNotExist() public {
        vm.expectRevert("URI query for NOT_MINTED token");
        p.tokenURI(2);
    }

    function testTokenURI() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        string memory tokenURI = p.tokenURI(uint256(p.hashOrder(order)));

        // assert
        assertEq(
            tokenURI,
            string.concat("https://testing.org/tokens/", Strings.toString(uint256(p.hashOrder(order)))),
            "Should have returned correct tokenURI"
        );
    }
}
