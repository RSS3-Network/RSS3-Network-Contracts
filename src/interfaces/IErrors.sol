// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

interface IErrors {
    /// @dev Caller is not staking contract
    error CallerNotStaking();

    /// @dev Node already exists
    error NodeExists();

    /// @dev Node staked or deposited
    error NodeStakedOrDeposited();

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

    /// @dev Claim time not ready
    error ClaimIdNotExists();

    /// @dev Staking amount too small
    error AmountTooSmall(uint256 amount);

    /// @dev Not chips owner
    error NotChipsOwner(uint256 tokenId);

    /// @dev Token is not issued by node
    error NotTokenIssuer(uint256 tokenId, address nodeAddr);

    /// @dev Deposited tokens was slashed completely
    error DepositedTokensSlashedAll();

    /// @dev Deposit is not allowed for public good node.
    error PublicGoodNotAllowed();

    /// @dev Chips are delegated or not public good.
    error ChipsDelegatedOrNotPublicGood(uint256 tokenId);

    /// @dev Tax fraction too large
    error TaxFractionTooLarge();

    /// @dev Batch size is zero
    error BatchSizeZero();
}
