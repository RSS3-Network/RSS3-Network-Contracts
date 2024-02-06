// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IErrors {
    /// @dev Caller is not staking contract
    error CallerNotStaking();

    /// @dev Create node to zero address
    error CreateNodeToZeroAddress();

    /// @dev Node already exists
    error NodeExists();

    /// @dev Node staked or deposited
    error NodeStakedOrDeposited();

    /// @dev Node not exists
    error NodeNotExists();

    /// @dev Invalid array length
    error InvalidArrayLength();

    /// @dev Submission interval has not elapsed
    error SubmissionIntervalNotElapsed();

    /// @dev Request already claimed
    error AlreadyClaimed();

    /// @dev Claim time not ready
    error ClaimTimeNotReady();

    /// @dev Claim time not ready
    error ClaimIdNotExists(uint256 claimId);

    /// @dev Staking amount too small
    error AmountTooSmall(uint256 amount);

    /// @dev Not chips owner or approver
    error ChipNotAuthorized(uint256 tokenId);

    /// @dev Token is not valid for the node
    error ChipNotValid(uint256 tokenId, address nodeAddr);

    /// @dev Chips are not public good.
    error ChipNotPublicGood(uint256 tokenId);

    /// @dev Node is not public good node.
    error NodeNotPublicGood(address nodeAddr);

    /// @dev Excess withdrawal amount.
    error ExcessWithdrawalAmount();

    /// @dev Deposit is not allowed for public good node.
    error PublicGoodNodeNotDeposited();

    /// @dev Public good node cannot be staked
    error StakeToPublicGoodNode(address nodeAddr);

    /// @dev Basis points of tax rate too large
    error TaxRateBasisPointsTooLarge();

    /// @dev Batch size is zero
    error BatchSizeZero();

    /// @dev Invalid epoch
    error InvalidEpoch(uint256 expected, uint256 actual);

    ///@dev Node list is empty
    error EmptyNodeList();

    /// @dev Chips id overflow
    error ChipsIdOverflow();

    /// @dev Reward distribution failed
    error RewardDistributionFailed();

    /// @dev Inffucient value to stake
    error InsufficientValue();

    /// @dev Transfer failed
    error TransferFailed();
}
