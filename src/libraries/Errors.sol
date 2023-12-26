// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

library Errors {
    /// @dev Caller is not staking contract
    error CallerNotStaking();

    /// @dev Node already exists
    error NodeExists();

    /// @dev Node staked or delegated
    error NodeStakedOrDelegated();

    /// @dev Node not exists
    error NodeNotExists();

    /// @dev Caller is not node owner
    error CallerNotNodeOwner();

    /// @dev Invalid array length
    error InvalidArrayLength();

    /// @dev Request already claimed
    error AlreadyClaimed();

    /// @dev Claim time not ready
    error ClaimTimeNotReady();

    /// @dev Staking amount too small
    error AmountTooSmall();

    /// @dev Not chips owner
    error NotChipsOwner();

    /// @dev Token is not issued by node
    error NotTokenIssuer(uint256 tokenId, address nodeAddr);

    /// @dev Staking tokens was slashed completely
    error StakingTokensSlashedAll();
}
