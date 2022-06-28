# Putty V2

An order-book based american options market for NFTs and ERC20s.
This project uses the foundry framework for testing/deployment.

## Getting started

1. Install `foundry`, refer to [foundry](https://github.com/foundry-rs/foundry)
2. Install `nodejs`, refer to [nodejs](https://nodejs.org/en/)
3. Install `yarn`, `npm install --global yarn`

Clone the repo and then run:

```
yarn
forge install
forge test --gas-report
```

## Tests

There is a full test-suite included in `./test/`. There is also a differential test suite included in `./test/differential/`. By default the differential tests are disabled. To run them follow the instructions in the README in `./test/differential/`.

```
forge test --gas-report
```

## Static analysis

We use [slither](https://github.com/crytic/slither) for static analysis.

Installation:

```
pip3 install slither-analyzer
pip3 install solc-select
solc-select install 0.8.13
solc-select use 0.8.13
```

Then to run:

```
slither ./src/PuttyV2.sol --solc-args "--optimize --optimize-runs 100000"
```