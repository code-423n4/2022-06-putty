// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

import "src/PuttyV2.sol";
import "../shared/Fixture.t.sol";

contract TestExercise is Fixture {
    event ExercisedOrder(bytes32 indexed orderHash, uint256[] floorAssetTokenIds, PuttyV2.Order order);

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

    function testItCannotExercisePositionYouDoNotOwn() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        uint256 positionId = p.fillOrder(order, signature, floorAssetTokenIds);
        p.transferFrom(address(this), address(0xdead), positionId);

        // act
        vm.expectRevert("Not owner");
        p.exercise(order, floorAssetTokenIds);
    }

    function testItCannotExercisePositionThatDoesNotExist() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();

        // act
        vm.expectRevert("NOT_MINTED");
        p.exercise(order, floorAssetTokenIds);
    }

    function testItCannotExercisePositionThatIsNotLong() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        order.isLong = false;
        vm.expectRevert("Can only exercise long positions");
        p.exercise(order, floorAssetTokenIds);
    }

    function testItCannotExerciseExpiredPosition() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        skip(order.duration);

        // act
        order.isLong = true;
        vm.expectRevert("Position has expired");
        p.exercise(order, floorAssetTokenIds);
    }

    function testItCannotSetFloorAssetTokenIdsIfCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isCall = true;
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        floorAssetTokenIds.push(0x123);

        // act
        order.isLong = true;
        vm.expectRevert("Invalid floor tokenIds length");
        p.exercise(order, floorAssetTokenIds);
    }

    function testItCannotSetIncorrectFloorAssetTokenIdsLengthIfPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isCall = false;
        floorTokens.push(address(bayc));
        order.floorTokens = floorTokens;
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        floorAssetTokenIds.push(1137);
        floorAssetTokenIds.push(99);

        // act
        order.isLong = true;
        vm.expectRevert("Wrong amount of floor tokenIds");
        p.exercise(order, floorAssetTokenIds);
    }

    function testItTransfersPositionTo0xdead() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        uint256 positionId = p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        order.isLong = true;
        p.exercise(order, floorAssetTokenIds);

        // assert
        assertEq(p.ownerOf(positionId), address(0xdead), "Should have transferred position to 0xdead");
    }

    function testItMarksPositionAsExercised() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        uint256 positionId = p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        order.isLong = true;
        p.exercise(order, floorAssetTokenIds);

        // assert
        assertEq(p.exercisedPositions(positionId), true, "Should have marked position as exercised");
    }

    function testItSavesThePositionsFloorTokenIdsIfPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();

        order.isCall = false;
        floorTokens.push(address(bayc));
        order.floorTokens = floorTokens;

        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        bayc.setApprovalForAll(address(p), true);
        bayc.mint(address(this), 32);
        floorAssetTokenIds.push(32);

        // act
        order.isLong = true;
        p.exercise(order, floorAssetTokenIds);

        // assert
        order.isLong = false;
        uint256 shortPositionId = uint256(p.hashOrder(order));
        assertEq(
            p.positionFloorAssetTokenIds(shortPositionId, 0),
            floorAssetTokenIds[0],
            "Should have saved floorTokenIds"
        );
    }

    function testItTransfersStrikeToPuttyForCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        uint256 balanceBefore = weth.balanceOf(address(p));

        // act
        order.isLong = true;
        p.exercise(order, floorAssetTokenIds);

        // assert
        assertEq(
            weth.balanceOf(address(p)) - balanceBefore,
            order.strike,
            "Should have transferred strike from exerciser to contract"
        );
    }

    function testItSendsAssetsToExerciserForCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();

        order.isCall = true;
        order.isLong = true;

        floorTokens.push(address(bayc));
        order.floorTokens = floorTokens;

        bayc.setApprovalForAll(address(p), true);
        uint256 floorTokenId = 32;
        bayc.mint(address(this), floorTokenId);
        floorAssetTokenIds.push(floorTokenId);

        uint256 erc721TokenId = 88;
        bayc.mint(address(this), erc721TokenId);
        erc721Assets.push(PuttyV2.ERC721Asset({token: address(bayc), tokenId: erc721TokenId}));
        order.erc721Assets = erc721Assets;

        uint256 erc20Amount = 989887;
        link.mint(address(this), erc20Amount);
        link.approve(address(p), type(uint256).max);
        erc20Assets.push(PuttyV2.ERC20Asset({token: address(link), tokenAmount: erc20Amount}));
        order.erc20Assets = erc20Assets;

        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        uint256 wethBalanceBefore = weth.balanceOf(babe);

        // act
        floorAssetTokenIds = new uint256[](0);
        vm.prank(babe);
        p.exercise(order, floorAssetTokenIds);

        // assert
        assertEq(bayc.ownerOf(floorTokenId), babe, "Should have sent floor asset from Putty to exerciser");
        assertEq(bayc.ownerOf(erc721TokenId), babe, "Should have sent bayc token from Putty to exerciser");
        assertEq(link.balanceOf(babe), erc20Amount, "Should have sent link tokens from Putty to exerciser");
        assertEq(
            wethBalanceBefore - weth.balanceOf(babe),
            order.strike,
            "Should have sent strike from exerciser to Putty"
        );
    }

    function testItTransfersStrikeToExerciserForPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        order.isCall = false;
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        uint256 balanceBefore = weth.balanceOf(address(this));

        // act
        order.isLong = true;
        p.exercise(order, floorAssetTokenIds);

        // assert
        assertEq(
            weth.balanceOf(address(this)) - balanceBefore,
            order.strike,
            "Should have transferred strike to exerciser from contract"
        );
    }

    function testItReceivesAssetsFromExerciserForPut() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();

        order.isCall = false;
        order.isLong = false;

        uint256 erc721TokenId = 88;
        bayc.mint(address(this), erc721TokenId);
        bayc.setApprovalForAll(address(p), true);
        erc721Assets.push(PuttyV2.ERC721Asset({token: address(bayc), tokenId: erc721TokenId}));
        order.erc721Assets = erc721Assets;

        uint256 erc20Amount = 989887;
        link.mint(address(this), erc20Amount);
        link.approve(address(p), type(uint256).max);
        erc20Assets.push(PuttyV2.ERC20Asset({token: address(link), tokenAmount: erc20Amount}));
        order.erc20Assets = erc20Assets;

        floorTokens.push(address(bayc));
        order.floorTokens = floorTokens;

        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        uint256 floorTokenId = 35;
        floorAssetTokenIds.push(floorTokenId);
        bayc.mint(address(this), floorTokenId);
        order.isLong = true;
        p.exercise(order, floorAssetTokenIds);

        // assert
        assertEq(bayc.ownerOf(floorTokenId), address(p), "Should have sent floor asset from exerciser to Putty");
        assertEq(bayc.ownerOf(erc721TokenId), address(p), "Should have sent bayc token from exerciser to Putty");
        assertEq(link.balanceOf(address(p)), erc20Amount, "Should have sent link tokens from exerciser to Putty");
    }

    function testItTransfersNativeETHToPuttyAndConvertsToWETHForCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        uint256 balanceBefore = weth.balanceOf(address(p));

        // act
        order.isLong = true;
        p.exercise{value: order.strike}(order, floorAssetTokenIds);

        // assert
        assertEq(
            weth.balanceOf(address(p)) - balanceBefore,
            order.strike,
            "Should have transferred strike from exerciser to contract and converted to WETH"
        );
    }

    function testItCannotTransferWrongAmountOfNativeETHForCall() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        order.isLong = true;
        vm.expectRevert("Incorrect ETH amount sent");
        p.exercise{value: order.strike - 1}(order, floorAssetTokenIds);
    }

    function testItEmitsExercisedOrder() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        order.isLong = true;
        vm.expectEmit(true, true, true, true);
        emit ExercisedOrder(p.hashOrder(order), floorAssetTokenIds, order);
        p.exercise(order, floorAssetTokenIds);
    }
}
