// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IStaking} from "./interfaces/IStaking.sol";
import {Node} from "./libraries/DataTypes.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IPowerToken {
    function balanceOfPoints(address owner) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract Utilizer {
    address public immutable staking;
    address public immutable powerToken;

    constructor(address _staking, address _powerToken) {
        staking = _staking;
        powerToken = _powerToken;
    }

    function unstake(uint256[] memory chipIds) public {
        for (uint256 i = 0; i < chipIds.length; i++) {
            (address nodeAddr, uint256 tokens,) = IStaking(staking).getChipInfo(chipIds[i]);

            if (tokens > 0) {
                uint256 requestId = IStaking(staking).requestUnstake(nodeAddr, _array(chipIds[i]));
                IStaking(staking).claimUnstake(_array(requestId));
            }
        }
    }

    function withdraw(address[] memory nodeAddrs) public {
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];
            Node memory node = IStaking(staking).getNode(nodeAddr);
            uint256 withdrawAmount = node.operationPoolTokens;

            if (withdrawAmount > 0) {
                uint256 requestId = IStaking(staking).requestWithdrawal(nodeAddr, withdrawAmount);
                IStaking(staking).claimWithdrawal(_array(requestId));
            }
        }
    }

    function exchangeView(address[] memory users) public view returns (uint256[] memory tokens) {
        uint256 length = users.length;
        tokens = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            uint256 points = IPowerToken(powerToken).balanceOfPoints(users[i]);
            uint256 balance = IPowerToken(powerToken).balanceOf(users[i]);

            tokens[i] = (balance - points) / 23;
        }
        return tokens;
    }

    function _array(uint256 value) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = value;
        return arr;
    }
}
