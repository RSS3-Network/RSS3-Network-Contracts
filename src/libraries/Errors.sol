// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/// @dev Caller is not staking contract.
error CallerNotStaking();

/// @dev Node already exists.
error NodeExists();

/// @dev Node staked or deposited.
error NodeStakedOrDeposited();

/// @dev Node deposit is below the minimum amount
error NodeDepositBelowMinimum();

/// @dev Node not exists.
error NodeNotExists();

error TaxRateBasisPointsTooSmall();

/// @dev Invalid array length.
error InvalidArrayLength();

/// @dev Invalid epoch number.
error InvalidEpochNumber(uint256 current, uint256 got);

/// @dev Submission interval has not elapsed.
error SubmissionIntervalNotElapsed();

/// @dev Request already claimed.
error AlreadyClaimed();

/// @dev Claim time not ready.
error ClaimTimeNotReady();

/// @dev Claim time not ready.
error ClaimIdNotExists(uint256 claimId);

/// @dev Staking amount is less than 500 ethers.
error StakeAmountTooSmall();

/// @dev Node is in exit status
error NodeInExitStatus();

/// @dev Not chips owner or approver.
error ChipNotAuthorized(uint256 tokenId);

/// @dev ChipIds are empty.
error EmptyChipIds();

/// @dev ChipIds array length is too short.
error ChipIdsLengthTooShort();

/// @dev Chips are not same owner.
error ChipsNotSameOwner();

/// @dev Token is not valid for the node
error ChipNotValid(uint256 tokenId, address nodeAddr);

/// @dev Chips are not public good.
error ChipNotPublicGood(uint256 tokenId);

/// @dev Node is not public good node.
error NodeNotPublicGood(address nodeAddr);

/// @dev Node is already public good node.
error NodeAlreadyPublicGood(address nodeAddr);

/// @dev Excess withdrawal amount.
error ExcessWithdrawalAmount();

/// @dev Withdrawal amount exceeds operationPoolTokens
error WithdrawalAmountExceedsOperationPoolTokens();

/// @dev Node is already in an exit status
error NodeAlreadyInExitStatus();

/// @dev Node is not in an exit status
error NodeNotInExitStatus();

/// @dev Deposit is not allowed for public good node.
error DepositForPublicGoodNode();

/// @dev Public good node cannot be staked.
error StakeToPublicGoodNode(address nodeAddr);

/// @dev Tax rate is not zero for public good node.
error PublicGoodNodeTaxNotZero();

/// @dev Batch size is zero.
error BatchSizeZero();

/// @dev Invalid epoch.
error InvalidEpoch(uint256 expected, uint256 actual);

///@dev Node list is empty.
error EmptyNodeList();

/// @dev Chips id overflow.
error ChipsIdOverflow();

/// @dev Insufficient value to stake.
error InsufficientValue();

/// @dev Transfer failed.
error TransferFailed();

/// @dev Distributed staking rewards exceed limit.
error StakingRewardsExceed();

/// @dev Distributed operation rewards exceed limit.
error OperationRewardsExceed();

/// @dev Invalid trait id.
error InvalidTraitId(uint256 traitId);

/// @dev Rewards already distributed.
error RewardsAlreadyDistributed(address nodeAddr);

/// @dev Settlement phase, stake/requestUnstakce is not allowed.
error SettlementPhase();

/// @dev Node is not staked.
error AlphaWithdrawNotAllowed();

/// @dev Slash is not able to be revoked.
error UnableToRevoke(uint256 id);

/// @dev Slash is non-existent.
error SlashRecordNotExists(address nodeAddr, uint256 epochId);

/// @dev Slash is not able to be committed or revoked.
error SlashStatusNotRecorded(address nodeAddr, uint256 epochId);

/// @dev Slash Public Good node.
error SlashPublicGoodNode(address);

/// @dev Slash more than once in one epoch for nodeAddr
error SlashMoreThanOnce(address nodeAddr, uint256 epoch);

/// @dev Basis points of tax rate too large.
error TaxRateBasisPointsTooLarge();

/// @dev Can't set tax for public good node
error NodeIsPublicGood();

/// @dev Create node to zero address.
error CreateNodeToZeroAddress();
