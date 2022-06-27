# fillOrder

Takes in an order and settles it on-chain. Minting NFTs for both the short and long position.

## Diagram

```
                                                                   checks
                                                                   ┌────────────────────────────────────────────────────────┐
              input                                                │ *check signature is valid                              │
              ┌─────────────────────────────┐                      │                                                        │
              │ order: Order                │                      │ *check both order side positions don’t exist           │
              │ signature: string           ├──────────────────────►                                                        │
              │ floorAssetTokeIds: number[] │                      │ *check order is not cancelled                          │
              └─────────────────────────────┘                      │                                                        │
                                                                   │ *check sender is in whitelist or whitelist length is 0 │
                                                                   │                                                        │
                                                                   │ *check floor asset token ids length is 0 unless type   │
                                                                   │  is call and side is long                              │
                                                                   │                                                        │
                                                                   │ *check order has not expired                           │
                                                                   └────────────────────────────┬───────────────────────────┘
                                                                                                │
                                                                                                │
                                                                                                │
                                                                  effects                       │
                                                                  ┌─────────────────────────────▼────────────────────────────┐
                                                                  │ *create side position for maker                          │
                                                                  │                                                          │
                                                                  │ *create opposite side position for sender                │
                                                                  │                                                          │
                                                                  │ *save floor asset token ids in positionFloorAssetTokenIds│
                                                                  │                                                          │
                                                                  │ *set position expiration to current time + duration      │
                                                                  │  in positionExpirations                                  │
                                                                  └─────────────────────────────┬────────────────────────────┘
                                                                                                │
                                                                                                │
 interactions                                                                                   │
 ┌──────────────────────────────────────────────────────────────────────────────────────────────▼───────────────────────────────────────────────────────────────────────────────┐
 │                                                              What is the order type and side?                                                                                │
 │                                                                              │                                                                                               │
 │                    ┌────────────────────────────────────────────┬────────────┴────────────────────────────────┬───────────────────────────────────────────┐                  │
 │                    │                                            │                                             │                                           │                  │
 │ ┌──────────────────▼────────────────────┐  ┌────────────────────▼───────────────────┐ ┌───────────────────────▼────────────────┐ ┌────────────────────────▼────────────────┐ │
 │ │ Side: short                           │  │ side: long                             │ │ side: short                            │ │ side: long                              │ │
 │ │ Type: put                             │  │ type: put                              │ │ type: call                             │ │ type: call                              │ │
 │ │                                       │  │                                        │ │                                        │ │                                         │ │
 │ │*transfer premium from sender to maker │  │*transfer premium from maker to sender  │ │*transfer premium from sender to maker  │ │*transfer premium from maker to sender   │ │
 │ │                                       │  │                                        │ │                                        │ │                                         │ │
 │ │*transfer strike from maker to contract│  │*transfer strike from sender to contract│ │*transfer erc20s from maker to contract │ │*transfer erc20s from sender to contract │ │
 │ └───────────────────────────────────────┘  └────────────────────────────────────────┘ │                                        │ │                                         │ │
 │                                                                                       │*transfer erc721s from maker to contract│ │*transfer erc721s from sender to contract│ │
 │                                                                                       └────────────────────────────────────────┘ │                                         │ │
 │                                                                                                                                  │*transfer floors from sender to contract │ │
 │                                                                                                                                  └─────────────────────────────────────────┘ │
 └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```
