// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Events {
    /**
     * @dev Emitted on createNode()
     * @param nodeId The unique identifier of the node.
     * @param nodeAddr Address of node operator.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxRateBasisPoints Tax rate measured in basis points. Each basis point represents 0.01%.
     * @param publicGood Flag indicating if the node is a public good.
     * @param alpha Flag indicating if the node is an alpha node.
     */
    event NodeCreated(
        uint256 indexed nodeId,
        address indexed nodeAddr,
        string name,
        string description,
        uint64 taxRateBasisPoints,
        bool publicGood,
        bool alpha
    );

    /**
     * @dev Emitted on update2PublicGood()
     * @param nodeAddr Address of node operator.
     */
    event NodeUpdated2PublicGood(address indexed nodeAddr);

    /**
     * @dev Emitted on deposit()
     * @param nodeAddr Address of node operator.
     * @param amount Amount of tokens deposited by node operator.
     */
    event Deposited(address indexed nodeAddr, uint256 indexed amount);

    /**
     * @dev Emitted on requestWithdraw()
     * @param nodeAddr Address of node operator.
     * @param amount Amount of tokens to withdraw.
     * @param requestId The created withdraw request id.
     */
    event WithdrawRequested(address indexed nodeAddr, uint256 indexed amount, uint256 indexed requestId);

    /**
     * @dev Emitted on setTaxRateBasisPoints4Node().
     * @param nodeAddr Address of node operator.
     * @param taxRateBasisPoints The new tax rate measured in basis points of node operator.
     */
    event NodeTaxRateBasisPointsSet(address indexed nodeAddr, uint64 indexed taxRateBasisPoints);
    /**
     * @dev Emitted on setTaxRateBasisPoints4PublicPool().
     * @param taxRateBasisPoints The new tax rate measured in basis points of public pool.
     */
    event PublicPoolTaxRateBasisPointsSet(uint64 indexed taxRateBasisPoints);

    /**
     * @dev Emitted on distributeRewards()
     * @param epoch The current epoch number.
     * @param startTimestamp The start timestamp of the epoch.
     * @param endTimestamp The end timestamp of the epoch.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param operationRewards Amount of bonuses to staking pool.
     * @param stakingRewards Amount of rewards to staking pool.
     * @param taxAmounts Amount of tax to node operator.
     * @param requestCounts The number of requests each node operator processed.
     */
    event RewardDistributed(
        uint256 indexed epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address[] nodeAddrs,
        uint256[] operationRewards,
        uint256[] stakingRewards,
        uint256[] taxAmounts,
        uint256[] requestCounts
    );

    /**
     * @dev Emitted on distributePublicPoolRewards()
     * @param epoch The current epoch number.
     * @param startTimestamp The start timestamp of the epoch.
     * @param endTimestamp The end timestamp of the epoch.
     * @param publicPoolRewards Amount of rewards to public pool.
     * @param publicPoolTax Amount of tax to public pool.
     */
    event PublicGoodRewardDistributed(
        uint256 indexed epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 publicPoolRewards,
        uint256 publicPoolTax
    );

    /**
     * @dev Emitted on claimWithdrawal()
     * @param requestId The withdrawal request id.
     */
    event WithdrawalClaimed(uint256 indexed requestId);

    /**
     * @dev Emitted on stake()
     * @param user Address of user who stake tokens.
     * @param nodeAddr The address of node to stake.
     * @param amount Amount of tokens to stake.
     * @param startTokenId The start of new minted chips token ids.
     * @param endTokenId The end of new minted chips token ids.
     */
    event Staked(
        address indexed user,
        address indexed nodeAddr,
        uint256 indexed amount,
        uint256 startTokenId,
        uint256 endTokenId
    );

    /**
     * @dev Emitted on requestUnstake()
     * @param user Address of user who unstake tokens.
     * @param nodeAddr The address of node to unstake.
     * @param requestId The created unstake request id.
     * @param unstakeAmount Amount of tokens to unstake.
     * @param chipsIds The chips token ids to unstake.
     */
    event UnstakeRequested(
        address indexed user,
        address indexed nodeAddr,
        uint256 indexed requestId,
        uint256 unstakeAmount,
        uint256[] chipsIds
    );
    /**
     * @dev Emitted on delegate()
     * @param user Address of user who delegate Chips.
     * @param nodeAddr The address of node to delegate.
     * @param chipsIds The chips token ids to delegate.
     */
    event Delegated(address indexed user, address indexed nodeAddr, uint256[] chipsIds);
    /**
     * @dev Emitted on undelegate()
     * @param user Address of user who undelegate tokens.
     * @param nodeAddr The address of node to undelegate.
     * @param chipsIds The chips token ids to undelegate.
     */
    event Undelegated(address indexed user, address indexed nodeAddr, uint256[] chipsIds);

    /**
     * @dev Emitted on claimUnstake()
     * @param requestId The unstake request id.
     * @param nodeAddr The address of node to unstake.
     * @param user Address of user who unstaked tokens.
     * @param unstakeAmount Amount of tokens unstaked.
     */
    event UnstakeClaimed(
        uint256 indexed requestId,
        address indexed nodeAddr,
        address indexed user,
        uint256 unstakeAmount
    );

    /**
     * @dev Emitted on slashNode()
     * @param nodeAddr The address of node to slash.
     * @param slashedOperationPool Amount of operation pool tokens slashed.
     * @param slashedStakingPool Amount of staking pool tokens slashed.
     */
    event NodeSlashed(
        address indexed nodeAddr,
        uint256 indexed slashedOperationPool,
        uint256 indexed slashedStakingPool
    );
}
