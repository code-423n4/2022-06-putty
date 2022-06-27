// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

import "src/PuttyV2.sol";
import "../shared/Fixture.t.sol";

contract TestFillOrder is Fixture {
    event FilledOrder(bytes32 indexed orderHash, uint256[] floorAssetTokenIds, PuttyV2.Order order);

    address[] internal whitelist;
    address[] internal floorTokens;
    PuttyV2.ERC20Asset[] internal erc20Assets;
    PuttyV2.ERC721Asset[] internal erc721Assets;
    uint256[] internal floorAssetTokenIds;

    receive() external payable {}

    function setUp() public {
        deal(address(weth), address(this), 0xffffffff);
        deal(address(weth), babe, 0xffffffff);

        weth.approve(address(p), type(uint256).max);

        vm.prank(babe);
        weth.approve(address(p), type(uint256).max);
    }

    function testItCannotUseInvalidSignature() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature;

        // act
        vm.expectRevert("Invalid signature");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItCannotFillOrderThatIsCancelled() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        vm.prank(babe);
        p.cancel(order);

        // act
        vm.expectRevert("Order has been cancelled");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItCannotFillOrderIfNotWhitelisted() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        whitelist.push(bob);
        order.whitelist = whitelist;
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        vm.expectRevert("Not whitelisted");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItCannotFillOrderIfDurationIsTooLong() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.duration = 10_001 days;
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        vm.expectRevert("Duration too long");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItCannotFillOrderIfBaseAssetIsNotContract() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.baseAsset = address(0xdeadbeef);
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        vm.expectRevert("baseAsset is not contract");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItCannotFillOrderWithFloorAssetTokenIdsIfOrderIsNotLongCall() public {
        // arrange
        floorAssetTokenIds.push(0x1337);

        // act
        // long put option order
        PuttyV2.Order memory longPutOrder = defaultOrder();
        longPutOrder.isLong = true;
        longPutOrder.isCall = false;
        bytes memory longPutOrderSignature = signOrder(babePrivateKey, longPutOrder);

        vm.expectRevert("Invalid floor tokens length");
        p.fillOrder(longPutOrder, longPutOrderSignature, floorAssetTokenIds);

        // short put option order
        PuttyV2.Order memory shortPutOrder = longPutOrder;
        shortPutOrder.isLong = false;
        shortPutOrder.isCall = false;
        bytes memory shortPutOrderSignature = signOrder(babePrivateKey, shortPutOrder);

        vm.expectRevert("Invalid floor tokens length");
        p.fillOrder(shortPutOrder, shortPutOrderSignature, floorAssetTokenIds);

        // short call option order
        PuttyV2.Order memory shortCallOrder = longPutOrder;
        shortCallOrder.isLong = false;
        shortCallOrder.isCall = true;
        bytes memory shortCallOrderSignature = signOrder(babePrivateKey, shortCallOrder);

        vm.expectRevert("Invalid floor tokens length");
        p.fillOrder(shortCallOrder, shortCallOrderSignature, floorAssetTokenIds);
    }

    function testItCannotSendIncorrectAmountOfFloorTokenIds() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        order.isCall = true;

        floorTokens.push(bob);
        order.floorTokens = floorTokens;
        bytes memory signature = signOrder(babePrivateKey, order);

        floorAssetTokenIds.push(0x1337);
        floorAssetTokenIds.push(0x1337);

        // act
        vm.expectRevert("Wrong amount of floor tokenIds");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItMintsPositionToMaker() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        bytes32 orderHash = p.hashOrder(order);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(p.ownerOf(uint256(orderHash)), order.maker, "Should have minted position to maker");
    }

    function testItMintsOppositePositionToTaker() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);
        order.isLong = !order.isLong;
        bytes32 oppositeOrderHash = p.hashOrder(order);

        // assert
        assertEq(p.ownerOf(uint256(oppositeOrderHash)), address(this), "Should have minted opposite position to taker");
    }

    function testItSavesFloorAssetTokenIdsIfLongCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        order.isCall = true;

        floorTokens.push(address(bayc));
        floorTokens.push(address(bayc));

        order.floorTokens = floorTokens;

        bytes memory signature = signOrder(babePrivateKey, order);
        bytes32 orderHash = p.hashOrder(order);

        bayc.mint(address(this), 1);
        bayc.mint(address(this), 2);
        bayc.setApprovalForAll(address(p), true);
        floorAssetTokenIds.push(1);
        floorAssetTokenIds.push(2);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(
            p.positionFloorAssetTokenIds(uint256(orderHash), 0),
            floorAssetTokenIds[0],
            "Should have saved first floor asset token id"
        );

        assertEq(
            p.positionFloorAssetTokenIds(uint256(orderHash), 1),
            floorAssetTokenIds[1],
            "Should have saved second floor asset token id"
        );
    }

    function testItSetsExpiration() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        uint256 expectedExpiration = block.timestamp + order.duration;

        // act
        uint256 positionId = p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(
            p.positionExpirations(positionId),
            expectedExpiration,
            "Should have set expiration to block.timestamp + duration"
        );
    }

    function testItSendsPremiumToMakerIfShort() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        bytes memory signature = signOrder(babePrivateKey, order);

        uint256 takerBalanceBefore = weth.balanceOf(address(this));
        uint256 makerBalanceBefore = weth.balanceOf(order.maker);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(
            weth.balanceOf(order.maker) - makerBalanceBefore,
            order.premium,
            "Should have transferred premium to maker"
        );

        assertEq(
            takerBalanceBefore - weth.balanceOf(address(this)),
            order.premium,
            "Should have transferred premium from taker"
        );
    }

    function testItSendsPremiumToTakerIfLong() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        bytes memory signature = signOrder(babePrivateKey, order);

        uint256 takerBalanceBefore = weth.balanceOf(address(this));
        uint256 makerBalanceBefore = weth.balanceOf(order.maker);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(
            weth.balanceOf(address(this)) - takerBalanceBefore,
            order.premium,
            "Should have transferred premium to taker"
        );

        assertEq(
            makerBalanceBefore - weth.balanceOf(order.maker),
            order.premium,
            "Should have transferred premium from maker"
        );
    }

    function testItTransfersStrikeFromMakerToPuttyForShortPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        order.isCall = false;
        bytes memory signature = signOrder(babePrivateKey, order);

        uint256 makerBalanceBefore = weth.balanceOf(order.maker);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        //  assert
        assertEq(
            makerBalanceBefore - weth.balanceOf(order.maker),
            order.strike - order.premium,
            "Should have transferred strike from maker when filling short put"
        );

        assertEq(
            weth.balanceOf(address(p)),
            order.strike,
            "Should have transferred strike to putty when filling short put"
        );
    }

    function testItTransfersStrikeFromTakerToPuttyForLongPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        order.isCall = false;
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        uint256 takerBalanceBefore = weth.balanceOf(address(this));
        p.fillOrder(order, signature, floorAssetTokenIds);

        //  assert
        assertEq(
            takerBalanceBefore - weth.balanceOf(address(this)),
            order.strike - order.premium,
            "Should have transferred strike from taker to Putty when filling short put"
        );

        assertEq(
            weth.balanceOf(address(p)),
            order.strike,
            "Should have transferred strike to putty when filling long put"
        );
    }

    function testItTransfersAssetsFromMakerToPuttyForShortCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        order.isCall = true;

        uint256 tokenAmount = 313;
        uint256 tokenId = 12;
        erc20Assets.push(PuttyV2.ERC20Asset({token: address(link), tokenAmount: tokenAmount}));
        erc721Assets.push(PuttyV2.ERC721Asset({token: address(bayc), tokenId: tokenId}));

        order.erc20Assets = erc20Assets;
        order.erc721Assets = erc721Assets;

        bytes memory signature = signOrder(babePrivateKey, order);

        vm.startPrank(babe);
        link.mint(babe, tokenAmount);
        link.approve(address(p), tokenAmount);
        bayc.mint(babe, tokenId);
        bayc.approve(address(p), tokenId);
        vm.stopPrank();

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(link.balanceOf(address(p)), tokenAmount, "Should have sent link from maker to contract");
        assertEq(bayc.ownerOf(tokenId), address(p), "Should have sent bayc from maker to contract");
    }

    function testItTransfersAssetsFromTakerToPuttyForLongCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        order.isCall = true;

        uint256 tokenAmount = 313;
        uint256 tokenId = 12;
        uint256 floorTokenId = 58;

        erc20Assets.push(PuttyV2.ERC20Asset({token: address(link), tokenAmount: tokenAmount}));
        erc721Assets.push(PuttyV2.ERC721Asset({token: address(bayc), tokenId: tokenId}));
        floorTokens.push(address(bayc));

        order.erc20Assets = erc20Assets;
        order.erc721Assets = erc721Assets;
        order.floorTokens = floorTokens;

        bytes memory signature = signOrder(babePrivateKey, order);

        link.mint(address(this), tokenAmount);
        link.approve(address(p), tokenAmount);
        bayc.mint(address(this), tokenId);
        bayc.approve(address(p), tokenId);
        bayc.mint(address(this), floorTokenId);
        bayc.approve(address(p), floorTokenId);

        // act
        floorAssetTokenIds.push(floorTokenId);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(link.balanceOf(address(p)), tokenAmount, "Should have sent link from taker to contract");
        assertEq(bayc.ownerOf(tokenId), address(p), "Should have sent bayc from taker to contract");
        assertEq(bayc.ownerOf(floorTokenId), address(p), "Should have sent floor bayc from taker to contract");
    }

    function testItCannotFillOrderTwice() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        p.fillOrder(order, signature, floorAssetTokenIds);
        vm.expectRevert("ALREADY_MINTED");
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItTransfersPremiumIfNativeETHIsUsedToFillShort() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        bytes memory signature = signOrder(babePrivateKey, order);

        deal(address(this), order.premium);
        uint256 takerBalanceBefore = address(this).balance;
        uint256 makerBalanceBefore = weth.balanceOf(order.maker);

        // act
        p.fillOrder{value: order.premium}(order, signature, floorAssetTokenIds);

        // assert
        assertEq(
            takerBalanceBefore - address(this).balance,
            order.premium,
            "Should have transferred ETH from taker to contract"
        );

        assertEq(
            weth.balanceOf(order.maker) - makerBalanceBefore,
            order.premium,
            "Should have transferred WETH to maker"
        );
    }

    function testItCannotTransferIncorrectNativeETHForPremium() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        bytes memory signature = signOrder(babePrivateKey, order);
        deal(address(this), order.premium);

        // act
        vm.expectRevert("Incorrect ETH amount sent");
        p.fillOrder{value: order.premium - 1}(order, signature, floorAssetTokenIds);
    }

    function testItTransfersStrikeIfNativeETHIsUsedToFillLongPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        order.isCall = false;
        bytes memory signature = signOrder(babePrivateKey, order);

        deal(address(this), order.strike);
        uint256 takerBalanceBefore = address(this).balance;
        uint256 contractBalanceBefore = weth.balanceOf(address(p));

        // act
        p.fillOrder{value: order.strike}(order, signature, floorAssetTokenIds);

        // assert
        assertEq(
            weth.balanceOf(address(p)) - contractBalanceBefore,
            order.strike,
            "Should have converted deposited WETH to ETH in contract"
        );

        assertEq(
            takerBalanceBefore - address(this).balance,
            order.strike,
            "Should have transferred strike ETH from taker to contract"
        );
    }

    function testItCannotTransferIncorrectNativeETHForStrike() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        order.isCall = false;
        bytes memory signature = signOrder(babePrivateKey, order);
        deal(address(this), order.strike);

        // act
        vm.expectRevert("Incorrect ETH amount sent");
        p.fillOrder{value: order.strike - 1}(order, signature, floorAssetTokenIds);
    }

    function testItEmitsFilledOrder() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        vm.expectEmit(true, true, true, true);
        emit FilledOrder(p.hashOrder(order), floorAssetTokenIds, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
    }

    function testItReturnsPositionId() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);

        // act
        uint256 positionId = p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        order.isLong = !order.isLong;
        assertEq(positionId, uint256(p.hashOrder(order)), "Should have returned position id");
    }

    function testItFillsOrder(PuttyV2.Order memory order) public {
        // arrange
        order.isCall = false;
        order.isLong = false;
        order.maker = babe;
        order.floorTokens = new address[](0);
        order.baseAsset = address(weth);
        order.duration = bound(order.duration, 0, 10_000 days);
        order.premium = bound(order.premium, 0, type(uint256).max - order.strike);
        order.strike = bound(order.strike, 0, type(uint256).max - order.premium);
        order.expiration = block.timestamp + 1 days;

        whitelist.push(address(this));
        order.whitelist = whitelist;
        bytes memory signature = signOrder(babePrivateKey, order);
        bytes32 orderHash = p.hashOrder(order);

        deal(address(weth), address(this), order.premium);
        weth.approve(address(p), order.premium);

        vm.startPrank(babe);
        deal(address(weth), babe, order.strike);
        weth.approve(address(p), order.strike);
        vm.stopPrank();

        // act
        uint256 positionId = p.fillOrder(order, signature, floorAssetTokenIds);

        // assert
        assertEq(weth.balanceOf(address(p)), order.strike);
        assertEq(weth.balanceOf(order.maker), order.premium);
        assertEq(p.ownerOf(uint256(orderHash)), order.maker);
        assertEq(p.ownerOf(positionId), address(this));
    }
}
