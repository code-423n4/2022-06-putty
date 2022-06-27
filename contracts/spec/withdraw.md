# Withdraw

Withdraws a short position's assets from the contract. Either the strike amount or the underlying assets themselves are withdrawn depending on whether the option is a call/put and if it is exercised/expired.

## Diagram

```
                                                 checks
                                                 ┌────────────────────────────────────────────┐
    input                                        │ *check position side is equal to short     │
    ┌─────────────────────────────┐              │                                            │
    │ order: Order                ├──────────────► *check position has expired OR it has been │
    │ floorAssetTokeIds: number[] │              │  exercised                                 │
    └─────────────────────────────┘              │                                            │
                                                 │ *check user owns position                  │
                                                 └───────────────────────┬────────────────────┘
                                                                         │
                                                                         │
                                                  effects                │
                                                  ┌──────────────────────▼─────────┐
                                                  │ *send short position to 0xdead │
                                                  └────────────────┬───────────────┘
                                                                   │
                                                                   │
      Interactions                                                 │
      ┌────────────────────────────────────────────────────────────▼───────────────────────────────────┐
      │                      Is the order exercised and what is the order type?                        │
      │                                             │                                                  │
      │                      ┌──────────────────────┴─────────────────────────┐                        │
      │                      │                                                │                        │
      │ ┌────────────────────▼──────────────────────┐    ┌────────────────────▼──────────────────────┐ │
      │ │  type: put         OR   type: call        │    │  type: call        OR  type: put          │ │
      │ │  exercised: false       exercised: true   │    │  exercised: false      exercised: true    │ │
      │ │                                           │    │                                           │ │
      │ │ *transfer strike from contract to sender  │    │ *transfer erc20s from contract to sender  │ │
      │ └───────────────────────────────────────────┘    │                                           │ │
      │                                                  │ *transfer erc721s from contract to sender │ │
      │                                                  │                                           │ │
      │                                                  │ *transfer floors from contract to sender  │ │
      │                                                  │                                           │ │
      │                                                  └───────────────────────────────────────────┘ │
      └────────────────────────────────────────────────────────────────────────────────────────────────┘
```
