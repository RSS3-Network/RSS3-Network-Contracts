// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library Events {
    /**
     * @dev Emitted on createNode()
     * @param nodeAddr Address of node operator.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxFraction Tax percentage measured in basis points. Each basis point represents 0.01%.
     * @param endpoint API endpoint of node.
     */
    event NodeCreated(
        address indexed nodeAddr,
        string name,
        string description,
        uint256 taxFraction,
        string endpoint
    );

    /**
     * @dev Emitted on deleteNode()
     * @param nodeAddr Address of node operator deleted.
     */
    event NodeDeleted(address indexed nodeAddr);

    /**
     * @dev Emitted on setNodeRewardAddress()
     * @param nodeAddr Address of node operator.
     * @param rewardAddress New reward address of node operator.
     */
    event NodeRewardAddressSet(address indexed nodeAddr, address indexed rewardAddress);

    /**
     * @dev Emitted on setNodeTaxFraction()
     * @param nodeAddr Address of node operator.
     * @param taxFraction The new tax fraction of node operator.
     */
    event NodeTaxFractionSet(address indexed nodeAddr, uint256 indexed taxFraction);

    /**
     * @dev Emitted on stake()
     * @param nodeAddr Address of node operator.
     * @param amount Amount of tokens staked.
     */
    event Staked(address indexed nodeAddr, uint256 indexed amount);

    /**
     * @dev Emitted on requestUnstake()
     * @param nodeAddr Address of node operator.
     * @param amount Amount of tokens to unstake.
     * @param requestId The created unstake request id.
     */
    event UnstakeRequested(
        address indexed nodeAddr,
        uint256 indexed amount,
        uint256 indexed requestId
    );

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
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param operatorPoolRewards Amount of rewards to operator pool.
     * @param rewardPoolRewards Amount of rewards to reward pool.
     */
    event RewardDistributed(
        uint256 indexed epoch,
        address[] nodeAddrs,
        uint256[] operatorPoolRewards,
        uint256[] rewardPoolRewards
    );

    /**
     * @dev Emitted on claimUnstake()
     * @param requestId The unstake request id.
     */
    event UnstakeClaimed(uint256 indexed requestId);

    /**
     * @dev Emitted on delegate()
     * @param user Address of user who delegated tokens.
     * @param nodeAddr The address of node to delegate.
     * @param amount Amount of tokens to delegate.
     * @param startTokenId The start of new minted chips token ids.
     * @param endTokenId The end of new minted chips token ids.
     */
    event Delegated(
        address indexed user,
        address indexed nodeAddr,
        uint256 indexed amount,
        uint256 startTokenId,
        uint256 endTokenId
    );

    /**
     * @dev Emitted on requestUndelegate()
     * @param user Address of user who undelegated tokens.
     * @param nodeAddr The address of node to delegate.
     * @param requestId The created undelegate request id.
     * @param chipsIds The chips token ids to undelegate.
     */
    event UndelegateRequested(
        address indexed user,
        address indexed nodeAddr,
        uint256 indexed requestId,
        uint256[] chipsIds
    );

    /**
     * @dev Emitted on claimUndelegate()
     * @param requestId The undelegate request id.
     */
    event UndelegateClaimed(uint256 indexed requestId);
}
