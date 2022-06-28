# Putty contest details
- $47,500 USDC main award pot
- $2,500 USDC gas optimization award pot
- Join [C4 Discord](https://discord.gg/code4rena) to register
- Submit findings [using the C4 form](https://code4rena.com/contests/2022-06-putty-contest/submit)
- [Read our guidelines for more details](https://docs.code4rena.com/roles/wardens)
- Starts June 29, 2022 20:00 UTC
- Ends July 04, 2022 20:00 UTC

# Putty V2

An order-book based american options market for NFTs and ERC20s.
This project uses the foundry framework for testing/deployment.

## Getting started

1. Install `foundry`, refer to [foundry](https://github.com/foundry-rs/foundry)
2. Install `nodejs`, refer to [nodejs](https://nodejs.org/en/)
3. Install `yarn`, `npm install --global yarn`

Clone the repo and then run:

```
cd contracts
yarn
forge install
forge test --gas-report
```

Note: earlier versions of foundry may cause the tests to fail.

---

```
feel free to have a cuppa and slice of pie while you continue to read through :)

             ;,'                     ,
     _o_    ;:;'     , ,               ;'
 ,-.'---`.__ ;        ,';             ' ;
((j`=====',-'       :----:           _.-._
_`-\     / ________C|====|________.:::::::::.______
    `-=-'           `----'        ~\_______/~
```

## Links

- **Rinkeby demo site:** https://rinkeby.putty.finance
- **Rinkeby etherscan:** https://rinkeby.etherscan.io/address/0xc67dbd1f722edc4b7f409f287ed6f7d928aa730c
- **Twitter:** https://twitter.com/puttyfi
- **Discord:** https://discord.gg/rxppJYj4Jp

## Contact

Feel free to contact if you have questions.

**out.eth (engineer)** - online from 08:00 BST-23:30 BST

- twitter: [@outdoteth](https://twitter.com/outdoteth)
- telegram: [@outdoteth](https://t.me/outdoteth)
- discord: out.eth#2001

Will usually answer within 45 mins.

## Contracts Overview

| Name               | LOC | Purpose                                                   |
| ------------------ | --- | --------------------------------------------------------- |
| **PuttyV2.sol**    | 327 | Entry point to the protocol. Holds the business logic.    |
| **PuttyV2Nft.sol** | 30  | NFT contract to represent Putty short and long positions. |

## Flow

There are four types of off-chain orders that a user can create.

1. long put
2. short put
3. long call
4. short call

When an order is filled, 2 option contracts are minted in the form of NFTs. One NFT represents the short position, and the other NFT represents the long position. All options are fully collateralised and physically settled.

Here is an example flow for filling a long put option.

- Alice creates and signs a long put option order off-chain for 2 Bored Ape floors with a duration of 30 days, a strike of 124 WETH and a premium of 0.8 WETH
- Bob takes Alice's order and fills it by sumbitting it to the Putty smart contract using `fillOrder()`
- He sends 124 ETH to cover the strike which is converted to WETH. 0.8 WETH is transferred from Alice's wallet to Bob's wallet.
- A long NFT is sent to Alice and a short NFT is sent to Bob which represents their position in the trade
- 17 days pass and the floor price for Bored Apes has dropped to 54 ETH - (`2 * 54 = 108 ETH. 124 - 108 = 16 ETH profit for Alice.`)
- Alice decides to exercise her long put contract and lock in her 16 ETH profit
  - She purchases BAYC #541 and BAYC #8765 from the open market for a combined total of 108 ETH
  - She calls exercise() on Putty and sends her BAYC id's of [#541, #8765]
  - BAYC #541 and BAYC #8765 are transferred from her wallet to Putty
  - Her long option is marked as exercised (`exercisedPositions`)
  - The 124 WETH strike is transferred to Alice
  - Alice's long option is voided and burned
- A few hours later, Bob sees that Alice has exercised her option
- He decides to withdraw (`withdraw()`) - BAYC #541 and BAYC #8765 are sent from Putty to his wallet
- His short option NFT is voided and burned

At a high level, there are 4 main entry points:

- `fillOrder(Order memory order, bytes calldata signature, uint256[] memory floorAssetTokenIds)`
- `exercise(Order memory order, uint256[] calldata floorAssetTokenIds)`
- `withdraw(Order memory order)`
- `cancel(Order memory order)`

All orders are stored off-chain until they are settled on chain through `fillOrder`.
There exists much more rigorous specification files in `./contracts/spec` with diagrams included.

## Libraries

- [openzeppelin/utils/cryptography/SignatureChecker.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6766b2de3bd0473bb7107fd8f83ef8c83c5b1fb3/contracts/utils/cryptography/SignatureChecker.sol)

- [openzeppelin/utils/cryptography/draft-EIP712.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6766b2de3bd0473bb7107fd8f83ef8c83c5b1fb3/contracts/utils/cryptography/draft-EIP712.sol)

- [openzeppelin/utils/Strings.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6766b2de3bd0473bb7107fd8f83ef8c83c5b1fb3/contracts/utils/Strings.sol)

- [openzeppelin/utils/access/Ownable.sol](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6766b2de3bd0473bb7107fd8f83ef8c83c5b1fb3/contracts/access/Ownable.sol)

- [solmate/utils/SafeTransferLib.sol](https://github.com/Rari-Capital/solmate/blob/eaaccf88ac5290299884437e1aee098a96583d54/src/utils/SafeTransferLib.sol)

- [solmate/tokens/ERC721.sol](https://github.com/Rari-Capital/solmate/blob/eaaccf88ac5290299884437e1aee098a96583d54/src/tokens/ERC721.sol)

## Optimisations

**There are various optimizations that may make the contracts harder to reason about. These are done to reduce gas costs but at the expense of code readability. Here are some helpful explanations of those optimizations.**

### Removing balanceOf

When an order is filled, Putty creates NFTs to represent both the long and short position.
All balanceOf modifications have been removed from the Putty NFTs.
Given our use-case, it is a reasonable tradeoff.
The `balanceOf` for each user is set to be defaulted to `type(uint256).max` instead of `0`.

```solidity
// set balanceOf to max for all users
function balanceOf(address owner) public pure override returns (uint256) {
  require(owner != address(0), "ZERO_ADDRESS");
  return type(uint256).max;
}
```

This was done to save gas since not tracking the `balanceOf` avoids a single storage modification or initialisation on each transfer/mint/burn.

## Notes

### Floor options

There is one area of the code that is perhaps not so intuitive. That is, `floorTokenIds` and `positionFloorAssetTokenIds`. This is a way for us to support floor NFT options.

The idea is that Alice can create a put option with 3 `floorTokens (address[])` and then when Bob wants to exercise he can send _any_ 3 tokens from the collections listed in `floorTokens`. Because he can use _any_ token from the collection, it essentially replicates a floor option; when exercising, he will always choose the lowest value tokens - floors.

Similarly Alice can create an off-chain order for a long call option with 5 `floorTokens (address[])`. Bob can fill this order (`fillOrder`) and send any 5 tokens (`floorTokenIds`) from the collections listed in `floorTokens` as collateral.

When an exercise or fillOrder happens, we save the floorTokenIds that Bob used in `positionFloorAssetTokenIds`. This is so that we can reference them later for the following situations;

a) Bob exercised his put option. Alice then can withdraw the floor tokens that Bob used.

b) Alice exercised her long call option. The floor tokens are sent to Alice.

c) Alice let her long call option expire. The floor tokens are sent back to Bob.

### Rebase and fee-on-transfer tokens

There are various tokens with custom implementations of how user balances are updated over time.
The most common of these are fee-on-transfer and rebase tokens.
Due to the complexity and cost of persistent accounting we don't intend to support these tokens.

## Areas of concern for wardens

There are a few places in the code where we have a lower confidence that things are correct. These may potentially serve as low-hanging fruit:

- Incorrect EIP-712 implementation

- External contract calls via token transfers leading to re-entrancy

- Incorrect handling of native ETH to WETH in `fillOrder` and `exercise`

- Timestamp manipulation
