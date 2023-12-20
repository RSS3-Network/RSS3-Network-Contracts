// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title DataTypes
 * @notice A standard library of data types.
 */
library DataTypes {
    struct Node {
        address account;
        string name;
        address rewardAddress;
    }
}
