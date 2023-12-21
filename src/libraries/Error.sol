// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

/// @dev Caller is not staking contract
error ErrCallerNotStaking();

/// @dev Node already exists
error ErrNodeExists();

/// @dev Node not exists
error ErrNodeNotExists();

/// @dev Caller is not node owner
error ErrCallerNotNodeOwner();
