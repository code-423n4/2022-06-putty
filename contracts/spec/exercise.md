# exercise

Exercises a long order. The NFT representing the position which is being exercised is then burned.
This should only be called at some point after `fillOrder` has been called.

## Diagram

```
                                              checks
                                              ┌───────────────────────────────────────────┐
input                                         │ *check user owns position with id set     │
┌─────────────────────────────┐               │                                           │
│ order: Order                ├───────────────► *check position side is equal to long     |                                       │
│ floorAssetTokeIds: number[] │               │                                           │
└─────────────────────────────┘               │ *check position has not expired in        |                                  │
                                              │  positionExpirations                      │
                                              └──────────────────────┬────────────────────┘
                                                                     │
                                                                     │
                                              effects                │
                                              ┌──────────────────────▼────────────────────────┐
                                              │ *send long position to 0xdead                 │
                                              │                                               │
                                              │ *mark long position as exercised              │
                                              │                                               │
                                              │ *save floor asset token ids to short position │
                                              └───────────────────────────────────────────────┘
                                                                      │
 interactions                                                         │
 ┌────────────────────────────────────────────────────────────────────▼────────────────────────────┐
 │                                  What is the order type?                                        │
 │                                               │                                                 │
 │                       ┌───────────────────────┴─────────────────────────┐                       │
 │                       │                                                 │                       │
 │ ┌─────────────────────▼─────────────────────┐     ┌─────────────────────▼─────────────────────┐ │
 │ │  Type: put                                │     │  Type: call                               │ │
 │ │                                           │     │                                           │ │
 │ │ *transfer strike from contract to sender  │     │ *Transfer strike from sender to contract  │ │
 │ │                                           │     │                                           │ │
 │ │ *transfer erc20s from sender to contract  │     │ *transfer erc20s from contract to sender  │ │
 │ │                                           │     │                                           │ │
 │ │ *transfer erc721s from sender to contract │     │ *transfer erc721s from contract to sender │ │
 │ │                                           │     │                                           │ │
 │ │ *transfer floors from sender to contract  │     │ *transfer floors from contract to sender  │ │
 │ └───────────────────────────────────────────┘     └───────────────────────────────────────────┘ │
 └─────────────────────────────────────────────────────────────────────────────────────────────────┘
```
