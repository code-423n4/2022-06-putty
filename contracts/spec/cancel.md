# Cancel

Cancels an order so that it cannot be filled in `fillOrder`.
A user should use this function in case they have previously posted an offchain order that they no longer want to be filled.

## Diagram

```

                        checks
 input
 ┌──────────────┐       ┌───────────────────────────────────────────────────┐
 │ order: Order ├───────► *check sender is equal to order details creator   │
 └──────────────┘       └───────────────────────┬───────────────────────────┘
                                                │
                                                │
                         effects                │
                         ┌──────────────────────▼─────────────────┐
                         │ *mark hash(order details) as cancelled │
                         └────────────────────────────────────────┘
```
