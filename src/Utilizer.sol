// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IStaking} from "./interfaces/IStaking.sol";
import {Node} from "./libraries/DataTypes.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Utilizer {
    address public immutable staking;

    constructor(address _staking) {
        staking = _staking;
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

    function withdraw(address nodeAddr) public {
        Node memory node = IStaking(staking).getNode(nodeAddr);
        uint256 withdrawAmount = node.operationPoolTokens;

        if (withdrawAmount > 0) {
            uint256 requestId = IStaking(staking).requestWithdrawal(nodeAddr, withdrawAmount);
            IStaking(staking).claimWithdrawal(_array(requestId));
        }
    }

    function _array(uint256 value) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = value;
        return arr;
    }
}
