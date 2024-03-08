# RSS3-Network-Contracts
[![Docs](https://github.com/NaturalSelectionLabs/RSS3-Network-Contracts/actions/workflows/docs.yml/badge.svg)](https://github.com/NaturalSelectionLabs/RSS3-Network-Contracts/actions/workflows/docs.yml)
[![Tests](https://github.com/NaturalSelectionLabs/RSS3-Network-Contracts/actions/workflows/tests.yml/badge.svg)](https://github.com/NaturalSelectionLabs/RSS3-Network-Contracts/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/NaturalSelectionLabs/RSS3-Network-Contracts/graph/badge.svg?token=9TUYUQOCA5)](https://codecov.io/gh/NaturalSelectionLabs/RSS3-Network-Contracts)

## Usage

### Build

```shell
npm i
forge install
forge build
```

### Test

```shell
forge test
```


### Deploy

```shell
forge script script/Deploy.s.sol:Deploy \
--chain-id $CHAIN_ID \
--rpc-url $RPC_URL \
--private-key $PRIVATE_KEY \
--verifier-url $VERIFIER_URL \
--verifier $VERIFIER \
--verify \
--broadcast --ffi -vvvv 

# generate easily readable abi to /deployments
forge script script/Deploy.s.sol:Deploy --sig 'sync()' --rpc-url $RPC_URL --broadcast --ffi
```
