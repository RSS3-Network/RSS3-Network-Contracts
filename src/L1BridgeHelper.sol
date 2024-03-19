// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICrossDomainMessenger} from "./interfaces/ICrossDomainMessenger.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

interface IL1Bridge {
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    ) external;
}

interface IL2BridgeHelper {
    function stakeFor(
        address nodeAddr,
        uint256 amount,
        address to
    ) external payable returns (uint256 startTokenId, uint256 endTokenId);
}

contract L1BridgeHelper is Initializable {
    address public immutable MESSENGER;
    address public immutable l1Token;
    address public immutable l2Token;
    address public immutable l1Bridge;

    address public otherBridge;

    // events
    event BridgeAndStakeInitiated(address indexed user, address indexed nodeAddr, uint256 indexed amount);

    constructor(address _xDomainAddress, address _l1Bridge, address _l1Token, address _l2Token) {
        MESSENGER = _xDomainAddress;
        l1Bridge = _l1Bridge;
        l1Token = _l1Token;
        l2Token = _l2Token;
    }

    function initialize(address _otherBridge) public initializer {
        otherBridge = _otherBridge;

        IERC20(l1Token).approve(l1Bridge, type(uint256).max);
    }

    function bridgeAndStake(uint256 amount, address nodeAddr, uint32 l2Gas) public {
        IERC20(l1Token).transferFrom(msg.sender, address(this), amount);

        IL1Bridge(l1Bridge).depositERC20To(l1Token, l2Token, otherBridge, amount, 200000, "");

        ICrossDomainMessenger(MESSENGER).sendMessage(
            address(otherBridge),
            abi.encodeWithSelector(IL2BridgeHelper.stakeFor.selector, nodeAddr, amount, msg.sender),
            l2Gas
        );

        emit BridgeAndStakeInitiated(msg.sender, nodeAddr, amount);
    }
}
