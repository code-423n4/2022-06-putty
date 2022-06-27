# Differential tests

These differential tests verify that the EIP-712 implementation in PuttyV2 is correct by comparing against the ethers implementation.
The reference ethers scripts are located in `./scripts`.

By default, these tests are disabled. To run them:

```
forge test --no-match-path None --match-path test/differential/*.sol --ffi
```

Warning: It can take longer than 1 minute to fully run through the whole differential test suite on a M1 mac. This is due to the fact that ffi testing is quite slow when combined with fuzz runs (default fuzz-runs is set to 100). During this process the output to the terminal will be blank until it finishes. Not to worry, the tests are still running!

There are also "sanity check" files in the `./scripts` that just run some example input in the ethers javascript implementation. To run them:

```
$ node ./test/differential/scripts/sign-order/sign-order-sanity-check.js
$ node ./test/differential/scripts/hash-order/hash-order-sanity-check.js
```
