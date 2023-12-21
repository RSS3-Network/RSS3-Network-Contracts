// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title DataTypes
 * @notice A standard library of data types.
 */
library DataTypes {
    struct Node {
        uint256 id;
        address account;
        string name;
        string description;
        address rewardAddress;
    }
}
