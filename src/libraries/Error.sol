// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

/// @dev Caller is not staking contract
error ErrCallerNotStaking();

/// @dev Node already exists
error ErrNodeExists();

/// @dev Node staked or delegated
error ErrNodeStakedOrDelegated();

/// @dev Node not exists
error ErrNodeNotExists();

/// @dev Caller is not node owner
error ErrCallerNotNodeOwner();

/// @dev Invalid array length
error ErrInvalidArrayLength();

/// @dev Request already claimed
error ErrAlreadyClaimed();

/// @dev Claim time not ready
error ErrClaimTimeNotReady();

/// @dev Staking amount too small
error ErrAmountTooSmall();
