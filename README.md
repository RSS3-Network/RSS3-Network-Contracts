# RSS3-Network-Contracts


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
--etherscan-api-key $ETHERSCAN_API_KEY \
--verifier-url $VERIFIER_URL \
--broadcast --legacy --ffi --verify -vvvv #--resume

forge script script/Deploy.s.sol:Deploy --sig 'sync()' --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast --legacy --ffi
```

### Contracts

Params need to be configured during initialization.
- pauseAccount: Address who can pause/unpause the Staking contract.
- oracleAccount: Address who can distribute rewards to the Staking contract.
- chips: Chips contract.
- token: Staking token contract.
- stakeUnbondingPeriod: Time in seconds user need to wait to unstake its stake.
- depositUnbondingPeriod: Time in seconds node operator need to wait to withdraw its deposit.
- nodeSlashFraction: Slash fraction for node operator.
- userSlashFraction: Slash fraction for user.
- stakeRatio: The stake ratio of the node operator.
- stakeBaseline: The stake base line of the node operator.
- depositBaseline: The deposit base line of the node operator.
- treasury: The treasury address.

For a node operator, available methods are:

- createNodeAndDeposit: start either a public good node or a normal node. 
- createNode
- deleteNode(only node operator)
- deposit(only node operator)
- requestWithdrawal(only node operator)
- claimWithdrawal(only node operator)
- setNodeTaxFraction(only node operator)

For all users,

- stake
- requestUnstake
- claimUnstake
- stakeToPublicPool
- requestUnstakeFromPublicPool
- delegate
- undelegate

For admin,

- setTaxFraction4PublicPool
- distributeRewards
- pause
- unpause
- slashNodes
