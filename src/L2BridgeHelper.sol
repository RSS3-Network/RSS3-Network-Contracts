// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract L2BridgeHelper is Initializable {
    address public immutable MESSENGER;

    address public staking;
    address public otherBridge;

    modifier onlyOtherBridge() {
        require(
            msg.sender == MESSENGER && ICrossDomainMessenger(MESSENGER).xDomainMessageSender() == address(otherBridge),
            "StandardBridge: function can only be called from the other bridge"
        );
        _;
    }

    constructor(address _xDomainAddress) {
        MESSENGER = _xDomainAddress;
    }

    function initialize(address _staking, address _otherBridge) public initializer {
        staking = _staking;
        otherBridge = _otherBridge;
    }

    function stakeFor(
        address nodeAddr,
        uint256 amount,
        address to
    ) external onlyOtherBridge returns (uint256 startTokenId, uint256 endTokenId) {
        (startTokenId, endTokenId) = IStaking(staking).stakeFor{value: amount}(nodeAddr, to);
    }
}
