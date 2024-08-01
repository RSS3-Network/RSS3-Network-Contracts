// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

library Const {
    uint256 public constant SHARES_PER_CHIP = 500 ether;
    uint256 public constant MIN_STAKE = 500 ether;

    /// @dev the minimal tokens for deposit, 10,000 by default.
    /// node operator can receive tax if it stakes at least 10,000 tokens, otherwise nothing
    uint256 public constant MIN_DEPOSIT = 10000 ether;

    /// @dev the ratio of total tokens to deposited tokens, 25 by default.
    /// node operator can receive its full tax if it deposits at least 1/25 of the tokens staked by external delegators
    uint256 public constant STAKE_RATIO = 25;

    /// @dev the minimum value of tax rate basis points
    uint256 public constant MIN_TAX_RATE_BASIS_POINTS = 500;

    uint256 public constant DEMOTION_COUNT_THRESHOLD = 3;

    /// @dev slash rate
    uint256 public constant NODE_SLASH_RATE_BASIS_POINTS = 100;
    uint256 public constant USER_SLASH_RATE_BASIS_POINTS = 50;

    /// @dev the bonus rate basis points for the reporter and burn of slash amount,
    //  the remaining part will be for treasury
    uint256 public constant SLASH_REPORTER_BONUS_RATE_BASIS_POINTS = 2000;
    uint256 public constant SLASH_BURN_RATE_BASIS_POINTS = 3000;

    // denominator
    uint96 public constant DENOMINATOR = 10000;
}
