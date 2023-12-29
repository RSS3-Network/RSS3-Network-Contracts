// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library Events {
    /**
     * @dev Emitted on createNode()
     * @param nodeAddr Address of node operator.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxFraction Tax percentage measured in basis points. Each basis point represents 0.01%.
     * @param publicGood Flag indicating if the node is a public good.
     * @param endpoint API endpoint of node.
     */
    event NodeCreated(
        address indexed nodeAddr,
        string name,
        string description,
        uint64 taxFraction,
        bool publicGood,
        string endpoint
    );

    /**
     * @dev Emitted on deleteNode()
     * @param nodeAddr Address of node operator deleted.
     */
    event NodeDeleted(address indexed nodeAddr);

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
    event WithdrawRequested(
        address indexed nodeAddr,
        uint256 indexed amount,
        uint256 indexed requestId
    );

    /**
     * @dev Emitted on setNodeTaxFraction().
     * @param nodeAddr Address of node operator.
     * @param taxFraction The new tax fraction of node operator.
     */
    event NodeTaxFractionSet(address indexed nodeAddr, uint64 indexed taxFraction);

    /**
     * @dev Emitted on withdrawOperatorPoolRewards()
     * @param nodeAddr Address of node operator.
     * @param rewardAddress Reward address to receive the rewards.
     * @param rewards Amount of rewards withdrawn.
     */
    event OperatorPoolRewardsWithdrawn(
        address indexed nodeAddr,
        address indexed rewardAddress,
        uint256 indexed rewards
    );

    /**
     * @dev Emitted on distributeRewards()
     * @param epoch The current epoch number.
     * @param startTimestamp The startTimestamp of the epoch.
     * @param endTimestamp The endTimestamp of the epoch.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param requestFees Amount of request fees to operator pool.
     * @param requestBonuses Amount of bonuses to reward pool.
     * @param stakingRewards Amount of rewards to reward pool.
     * @param taxAmounts Amount of tax to node operator.
     */
    event RewardDistributed(
        uint256 indexed epoch,
        uint256 indexed startTimestamp,
        uint256 indexed endTimestamp,
        address[] nodeAddrs,
        uint256[] requestFees,
        uint256[] requestBonuses,
        uint256[] stakingRewards,
        uint256[] taxAmounts
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
     * @param chipsIds The chips token ids to unstake.
     */
    event UnstakeRequested(
        address indexed user,
        address indexed nodeAddr,
        uint256 indexed requestId,
        uint256[] chipsIds
    );

    /**
     * @dev Emitted on claimUnstake()
     * @param requestId The unstake request id.
     * @param nodeAddr The address of node to unstake.
     * @param user Address of user who unstaked tokens.
     * @param unstakeAmount Amount of tokens unstaked.
     * @param rewards Amount of rewards claimed.
     */
    event UnstakeClaimed(
        uint256 indexed requestId,
        address indexed nodeAddr,
        address indexed user,
        uint256 unstakeAmount,
        uint256 rewards
    );
    /**
     * @dev Emitted on withdrawTax()
     * @param nodeAddr The address of node operator.
     * @param tax Amount of tokens withdrawn.
     */
    event TaxWithdrawn(address indexed nodeAddr, uint256 indexed tax);
    /**
     * @dev Emitted on slashNode()
     * @param nodeAddr The address of node to slash.
     * @param slashedAmount Amount of staked tokens slashed.
     * @param slashedRewards Amount of rewards slashed.
     */
    event NodeSlashed(
        address indexed nodeAddr,
        uint256 indexed slashedAmount,
        uint256 indexed slashedRewards
    );
}
