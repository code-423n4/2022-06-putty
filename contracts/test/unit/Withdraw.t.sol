// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "openzeppelin/utils/cryptography/ECDSA.sol";

import "src/PuttyV2.sol";
import "../shared/Fixture.t.sol";

contract TestWithdraw is Fixture {
    event WithdrawOrder(bytes32 indexed orderHash, PuttyV2.Order order);

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

    function testItCannotWithdrawShortPosition() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = true;

        // act
        vm.expectRevert("Must be short position");
        p.withdraw(order);
    }

    function testItCannotWithdrawPositionThatDoesNotExist() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;

        // act
        vm.expectRevert("NOT_MINTED");
        p.withdraw(order);
    }

    function testItCannotWithdrawPositionThatYouDontOwn() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        vm.prank(bob);
        vm.expectRevert("Not owner");
        p.withdraw(order);
    }

    function testItCannotWithdrawPositionThatIsNotExercisedOrExpired() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        // act
        vm.prank(babe);
        vm.expectRevert("Must be exercised or expired");
        p.withdraw(order);
    }

    function testItTransfersPositionTo0xdead() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        skip(order.duration + 1);

        // act
        vm.prank(babe);
        p.withdraw(order);

        // assert
        assertEq(p.ownerOf(uint256(p.hashOrder(order))), address(0xdead), "Should have sent position to 0xdead");
    }

    function testItWithdrawsBaseAssetIfPutExpired() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        order.isCall = false;
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        skip(order.duration + 1);

        uint256 balanceBefore = weth.balanceOf(babe);

        // act
        vm.prank(babe);
        p.withdraw(order);

        // assert
        assertEq(
            weth.balanceOf(babe) - balanceBefore,
            order.strike,
            "Should have sent strike from putty to withdrawer if put has expired"
        );
    }

    function testItWithdrawsBaseAssetIfCallExercised() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        order.isLong = false;
        order.isCall = true;
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);

        PuttyV2.Order memory longOrder = abi.decode(abi.encode(order), (PuttyV2.Order)); // decode/encode to get a copy instead of reference
        longOrder.isLong = true;
        p.exercise(longOrder, floorAssetTokenIds);

        uint256 balanceBefore = weth.balanceOf(babe);

        // act
        vm.prank(babe);
        p.withdraw(order);

        // assert
        assertEq(
            weth.balanceOf(babe) - balanceBefore,
            order.strike,
            "Should have sent strike from putty to withdrawer if call has been exercised"
        );
    }

    function testItWithdrawsAssetsIfPutExercised() public {
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

        uint256 floorTokenId = 35;
        floorAssetTokenIds.push(floorTokenId);
        bayc.mint(address(this), floorTokenId);
        PuttyV2.Order memory longOrder = abi.decode(abi.encode(order), (PuttyV2.Order)); // decode/encode to get a copy instead of reference
        longOrder.isLong = true;
        p.exercise(longOrder, floorAssetTokenIds);

        // act
        vm.prank(babe);
        p.withdraw(order);

        // assert
        assertEq(bayc.ownerOf(floorTokenId), babe, "Should have sent floor asset to withdrawer from Putty");
        assertEq(bayc.ownerOf(erc721TokenId), babe, "Should have sent bayc token to withdrawer from Putty");
        assertEq(link.balanceOf(babe), erc20Amount, "Should have sent link tokens to withdrawer from Putty");
    }

    function testItWithdrawsAssetsIfCallExpired() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();

        order.isCall = true;
        order.isLong = true;

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

        uint256 floorTokenId = 35;
        floorAssetTokenIds.push(floorTokenId);
        bayc.mint(address(this), floorTokenId);
        p.fillOrder(order, signature, floorAssetTokenIds);

        PuttyV2.Order memory shortOrder = abi.decode(abi.encode(order), (PuttyV2.Order)); // decode/encode to get a copy instead of reference
        shortOrder.isLong = false;

        skip(order.duration + 1);

        // act
        p.withdraw(shortOrder);

        // assert
        assertEq(bayc.ownerOf(floorTokenId), address(this), "Should have sent floor asset from putty to withdrawer");
        assertEq(bayc.ownerOf(erc721TokenId), address(this), "Should have sent bayc token from putty to withdrawer");
        assertEq(link.balanceOf(address(this)), erc20Amount, "Should have sent link tokens from putty to withdrawer");
    }

    function testItEmitsWithdrawOrder() public {
        // arrange
        PuttyV2.Order memory order = defaultOrder();
        bytes memory signature = signOrder(babePrivateKey, order);
        p.fillOrder(order, signature, floorAssetTokenIds);
        skip(order.duration + 1);

        // act
        vm.expectEmit(true, true, true, true);
        emit WithdrawOrder(p.hashOrder(order), order);
        vm.prank(babe);
        p.withdraw(order);
    }
}
