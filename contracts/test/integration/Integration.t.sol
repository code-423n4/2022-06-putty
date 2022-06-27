// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

import "src/PuttyV2.sol";
import "../shared/Fixture.t.sol";

contract TestIntegration is Fixture {
    address[] internal whitelist;
    uint256[] internal floorAssetTokenIds;

    function setUp() public {
        weth.approve(address(p), type(uint256).max);
        link.approve(address(p), type(uint256).max);
        bayc.setApprovalForAll(address(p), true);

        vm.startPrank(babe);
        weth.approve(address(p), type(uint256).max);
        link.approve(address(p), type(uint256).max);
        bayc.setApprovalForAll(address(p), true);
        vm.stopPrank();
    }

    receive() external payable {}

    function testItFillsExercisesAndWithdrawsPut(PuttyV2.Order memory order) public {
        // arrange
        order.maker = babe;
        order.duration = bound(order.duration, 0, 10_000 days);
        order.premium = bound(order.premium, 0, type(uint256).max - order.strike);
        order.strike = bound(order.strike, 0, type(uint256).max - order.premium);
        order.baseAsset = address(weth);
        order.expiration = block.timestamp + 1 days;
        order.duration = 1 days;
        order.isLong = true;
        order.isCall = false;
        whitelist = order.whitelist;
        whitelist.push(address(this));
        order.whitelist = whitelist;

        for (uint256 i = 0; i < order.erc721Assets.length; i++) {
            order.erc721Assets[i].token = address(bayc);
            order.erc721Assets[i].tokenId = uint256(
                keccak256(abi.encodePacked(block.timestamp, i, order.erc721Assets[i].tokenId))
            );
            bayc.mint(babe, order.erc721Assets[i].tokenId);
        }

        for (uint256 i = 0; i < order.erc20Assets.length; i++) {
            order.erc20Assets[i].token = address(link);
            order.erc20Assets[i].tokenAmount = i + 1;
            deal(address(link), babe, link.balanceOf(babe) + order.erc20Assets[i].tokenAmount);
        }

        for (uint256 i = 0; i < order.floorTokens.length; i++) {
            order.floorTokens[i] = address(bayc);
        }

        bytes memory signature = signOrder(babePrivateKey, order);
        deal(address(weth), address(this), order.strike);
        deal(address(weth), babe, order.premium);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        for (uint256 i = 0; i < order.floorTokens.length; i++) {
            floorAssetTokenIds.push(i);
            bayc.mint(babe, i);
        }

        vm.prank(babe);
        p.exercise(order, floorAssetTokenIds);

        PuttyV2.Order memory shortOrder = abi.decode(abi.encode(order), (PuttyV2.Order)); // decode/encode to get a copy instead of reference
        shortOrder.isLong = false;
        p.withdraw(shortOrder);

        // assert
        uint256 longPositionId = uint256(p.hashOrder(order));
        uint256 shortPositionId = uint256(p.hashOrder(shortOrder));
        assertEq(p.ownerOf(longPositionId), address(0xdead), "Should have burned long position");
        assertEq(p.ownerOf(shortPositionId), address(0xdead), "Should have burned short position");
        assertEq(weth.balanceOf(babe), order.strike, "Should have sent strike to exerciser");
    }

    function testItFillsExercisesAndWithdrawsCall(PuttyV2.Order memory order) public {
        // arrange
        order.maker = babe;
        order.duration = bound(order.duration, 0, 10_000 days);
        order.premium = bound(order.premium, 0, type(uint256).max - order.strike);
        order.strike = bound(order.strike, 0, type(uint256).max - order.premium);
        order.baseAsset = address(weth);
        order.expiration = block.timestamp + 1 days;
        order.duration = 1 days;
        order.isLong = true;
        order.isCall = true;
        whitelist = order.whitelist;
        whitelist.push(address(this));
        order.whitelist = whitelist;

        for (uint256 i = 0; i < order.erc721Assets.length; i++) {
            order.erc721Assets[i].token = address(bayc);
            order.erc721Assets[i].tokenId = uint256(
                keccak256(abi.encodePacked(block.timestamp, i, order.erc721Assets[i].tokenId))
            );
            bayc.mint(address(this), order.erc721Assets[i].tokenId);
        }

        for (uint256 i = 0; i < order.erc20Assets.length; i++) {
            order.erc20Assets[i].token = address(link);
            order.erc20Assets[i].tokenAmount = i + 1;
            deal(address(link), address(this), link.balanceOf(address(this)) + order.erc20Assets[i].tokenAmount);
        }

        for (uint256 i = 0; i < order.floorTokens.length; i++) {
            order.floorTokens[i] = address(bayc);
        }

        bytes memory signature = signOrder(babePrivateKey, order);
        deal(address(weth), babe, order.premium + order.strike);

        // act
        for (uint256 i = 0; i < order.floorTokens.length; i++) {
            floorAssetTokenIds.push(i);
            bayc.mint(address(this), i);
        }

        p.fillOrder(order, signature, floorAssetTokenIds);

        vm.prank(babe);
        floorAssetTokenIds = new uint256[](0);
        p.exercise(order, floorAssetTokenIds);

        PuttyV2.Order memory shortOrder = abi.decode(abi.encode(order), (PuttyV2.Order)); // decode/encode to get a copy instead of reference
        shortOrder.isLong = false;
        p.withdraw(shortOrder);

        // assert
        uint256 longPositionId = uint256(p.hashOrder(order));
        uint256 shortPositionId = uint256(p.hashOrder(shortOrder));
        assertEq(p.ownerOf(longPositionId), address(0xdead), "Should have burned long position");
        assertEq(p.ownerOf(shortPositionId), address(0xdead), "Should have burned short position");
        assertEq(
            weth.balanceOf(address(this)),
            order.strike + order.premium,
            "Should have transferred strike and premium to short owner"
        );
    }
}
