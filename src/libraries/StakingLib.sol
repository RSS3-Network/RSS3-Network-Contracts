// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase,no-empty-blocks
pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IChips} from "../interfaces/IChips.sol";
import {Const} from "./Const.sol";
import {Node, NodeStatus, UnstakeRequest, WithdrawalRequest} from "./DataTypes.sol";
import {
    NodeNotExists,
    DepositForPublicGoodNode,
    StakeAmountTooSmall,
    ChipNotValid,
    ChipNotAuthorized,
    EmptyChipIds,
    ChipsNotSameOwner,
    ChipIdsLengthTooShort,
    ClaimTimeNotReady,
    ClaimIdNotExists
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {NodeSettingsLib} from "./NodeSettingsLib.sol";
import {StakingCommonLib} from "./StakingCommonLib.sol";
import {StorageLib} from "./StorageLib.sol";

library StakingLib {
    using Address for address;

    /// @dev deposit tokens to a node
    function deposit(address nodeAddr, uint256 amount) external {
        Node storage node = StorageLib.getNode(nodeAddr);

        if (node.account == address(0)) revert NodeNotExists(nodeAddr);
        if (node.publicGood) revert DepositForPublicGoodNode();

        StakingCommonLib.increaseOperationPool(node, amount);

        // set node status
        if (node.operationPoolTokens >= Const.MIN_DEPOSIT) {
            NodeStatus curStatus = NodeSettingsLib._getNodeStatus(node);
            if (curStatus == NodeStatus.None || curStatus == NodeStatus.Exited) {
                node.status = NodeStatus.Registered;
                emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Registered);
            }
        }

        emit Events.Deposited(nodeAddr, amount);
    }

    function stakeToNode(
        Node storage node,
        uint256 amount,
        address nodeAddr,
        address from
    ) external returns (uint256 tokenId) {
        // staking amount must be greater than MIN_STAKE
        if (amount < Const.MIN_STAKE) revert StakeAmountTooSmall();

        uint256 sharesToMint = _tokensToShares(amount, nodeAddr);

        // update staking pool
        StakingCommonLib.increaseStakingPool(node, amount);
        // update pool shares
        _increaseTotalShares(node, sharesToMint);

        // mint chip
        address chips = StorageLib.getChipsContract();
        tokenId = IChips(chips).mint(from);

        // set chip issuer and shares
        StorageLib.chipIssuers()[tokenId] = nodeAddr;
        StorageLib.chipToShares()[tokenId] = sharesToMint;

        // set startTokenId and endTokenId to tokenId, for compatibility with the previous version
        emit Events.Staked(from, node.account, amount, tokenId, tokenId);
    }

    /// @dev unstake from a node by burning chips
    function unstakeFromNode(address nodeAddr, uint256[] calldata chipIds) external returns (uint256 requestId) {
        if (chipIds.length == 0) revert EmptyChipIds();

        address owner = _checkChipsConditions(nodeAddr, chipIds);

        // update pool tokens and shares
        uint256 sharesToBurn;
        uint256 unstakeAmount;
        for (uint256 i = 0; i < chipIds.length; i++) {
            uint256 tokenId = chipIds[i];
            (, uint256 amount, uint256 shares) = _chipInfo(tokenId);
            unstakeAmount += amount;
            sharesToBurn += shares;

            // burn chips and reset corresponding shares
            address chips = StorageLib.getChipsContract();

            IChips(chips).burn(tokenId);

            delete StorageLib.chipIssuers()[tokenId];
            delete StorageLib.chipToShares()[tokenId];
        }
        Node storage node = _getStakingNode(nodeAddr);
        StakingCommonLib.decreaseStakingPool(node, unstakeAmount);
        _decreaseTotalShares(node, sharesToBurn);

        requestId = StorageLib.nextPendingUnstakeId();

        // add to request queue
        UnstakeRequest storage req = StorageLib.getPendingUnstake()[requestId];
        req.owner = owner;
        req.nodeAddr = nodeAddr;
        req.timestamp = block.timestamp;
        req.unstakeAmount = unstakeAmount;

        emit Events.UnstakeRequested(owner, nodeAddr, requestId, unstakeAmount, chipIds);
    }

    function requestWithdrawal(Node storage node, uint256 amount) external returns (uint256 requestId) {
        StakingCommonLib.decreaseOperationPool(node, amount);

        requestId = StorageLib.nextPendingWithdrawalId();

        WithdrawalRequest storage req = StorageLib.getPendingWithdrawal()[requestId];
        req.timestamp = uint40(block.timestamp);
        req.owner = node.account;
        req.amount = amount;

        emit Events.WithdrawRequested(node.account, amount, requestId);

        return requestId;
    }

    /// @dev claim withdrawal request
    function claimWithdrawal(uint256 requestId, uint256 DEPOSIT_UNBONDING_PERIOD) external {
        WithdrawalRequest memory req = StorageLib.getPendingWithdrawal()[requestId];

        if (req.owner == address(0)) revert ClaimIdNotExists(requestId);
        if (block.timestamp < req.timestamp + DEPOSIT_UNBONDING_PERIOD) revert ClaimTimeNotReady();

        delete StorageLib.getPendingWithdrawal()[requestId];

        // transfer tokens
        _transfer(req.owner, req.amount);

        emit Events.WithdrawalClaimed(requestId, req.owner, req.amount);
    }

    /// @dev claim unstake request
    function claimUnstake(uint256 requestId, uint256 STAKE_UNBONDING_PERIOD) external {
        UnstakeRequest memory req = StorageLib.getPendingUnstake()[requestId];

        if (req.owner == address(0)) revert ClaimIdNotExists(requestId);

        if (block.timestamp < req.timestamp + STAKE_UNBONDING_PERIOD) revert ClaimTimeNotReady();

        delete StorageLib.getPendingUnstake()[requestId];

        // transfer tokens
        _transfer(req.owner, req.unstakeAmount);

        emit Events.UnstakeClaimed(requestId, req.nodeAddr, req.owner, req.unstakeAmount);
    }

    function mergeChips(uint256[] calldata chipIds) external returns (uint256 newTokenId) {
        if (chipIds.length < 2) revert ChipIdsLengthTooShort();

        address chips = StorageLib.getChipsContract();

        address nodeAddr = _issuerOf(chipIds[0]);
        address owner = _checkChipsConditions(nodeAddr, chipIds);
        uint256 totalShares;
        for (uint256 i = 0; i < chipIds.length; i++) {
            uint256 tokenId = chipIds[i];
            (, , uint256 shares) = _chipInfo(tokenId);
            totalShares += shares;

            // burn chips and reset corresponding shares
            IChips(chips).burn(tokenId);

            delete StorageLib.chipToShares()[tokenId];
            delete StorageLib.chipIssuers()[tokenId];
        }

        // mint new chip
        newTokenId = IChips(chips).mint(owner);
        StorageLib.chipIssuers()[newTokenId] = nodeAddr;
        StorageLib.chipToShares()[newTokenId] = totalShares;

        emit Events.ChipsMerged(owner, nodeAddr, newTokenId, chipIds);
    }

    function getChipInfo(uint256 tokenId) external view returns (address nodeAddr, uint256 tokens, uint256 shares) {
        (nodeAddr, tokens, shares) = _chipInfo(tokenId);
    }

    /// @dev increase total shares of a node
    function _increaseTotalShares(Node storage node, uint256 amount) internal {
        node.totalShares += amount;
    }

    /// @dev decrease total shares of a node
    function _decreaseTotalShares(Node storage node, uint256 amount) internal {
        node.totalShares -= amount;
    }

    /// @dev transfer native tokens by a low-level call.
    /// _transfer should always be at the end of the function,
    /// to apply the checks-effects-interactions pattern
    function _transfer(address to, uint256 amount) internal {
        Address.sendValue(payable(to), amount);
    }

    /// @dev checks that:
    /// 1. caller has the authorization to unstake the chips
    /// 2. chips are issued by the same node
    /// 3. chips have the same owner
    function _checkChipsConditions(address nodeAddr, uint256[] calldata chipIds) internal view returns (address) {
        address lastOwner;
        for (uint256 i = 0; i < chipIds.length; i++) {
            uint256 tokenId = chipIds[i];
            address chips = StorageLib.getChipsContract();

            address owner = IERC721(chips).ownerOf(tokenId);
            if (lastOwner != address(0) && owner != lastOwner) revert ChipsNotSameOwner();
            lastOwner = owner;

            if (!_isAuthorized(owner, tokenId, msg.sender)) revert ChipNotAuthorized(tokenId);

            if (_issuerOf(tokenId) != nodeAddr) revert ChipNotValid(tokenId, nodeAddr);
        }

        return lastOwner;
    }

    /// @dev convert tokens to equivalent shares
    function _tokensToShares(uint256 tokens, address nodeAddr) internal view returns (uint256) {
        Node storage node = _getStakingNode(nodeAddr);
        if (node.stakingPoolTokens == 0) {
            return tokens;
        }

        return (tokens * node.totalShares) / node.stakingPoolTokens;
    }

    function _sharesToTokens(uint256 shares, address nodeAddr) internal view returns (uint256) {
        Node storage node = _getStakingNode(nodeAddr);
        if (node.totalShares == 0) {
            return 0;
        }

        return (shares * node.stakingPoolTokens) / node.totalShares;
    }

    function _getStakingNode(address nodeAddr) internal view returns (Node storage _node) {
        Node storage node = StorageLib.getNode(nodeAddr);
        Node storage publicPool = StorageLib.publicPool();

        _node = node.publicGood ? publicPool : node;
    }

    function _chipInfo(uint256 tokenId) internal view returns (address nodeAddr, uint256 tokens, uint256 shares) {
        nodeAddr = _issuerOf(tokenId);
        if (nodeAddr == address(0)) return (address(0), 0, 0);

        shares = StorageLib.chipToShares()[tokenId];

        if (shares == 0) {
            // old chip is always:  1 token = SHARES_PER_CHIP shares
            shares = Const.SHARES_PER_CHIP;
        }

        tokens = _sharesToTokens(shares, nodeAddr);
    }

    /// @dev returns whether user is token owner or approved
    function _isAuthorized(address owner, uint256 tokenId, address user) internal view returns (bool) {
        address chips = StorageLib.getChipsContract();

        return
            owner == user ||
            IERC721(chips).getApproved(tokenId) == user ||
            IERC721(chips).isApprovedForAll(owner, user);
    }

    /// @dev returns the node address which issued the chips
    function _issuerOf(uint256 tokenId) internal view returns (address) {
        // return address(0) if the chip is not existing or burned
        address chips = StorageLib.getChipsContract();
        try IERC721(chips).ownerOf(tokenId) returns (address) {} catch (bytes memory) {
            return address(0);
        }

        // fetch issuer, if not found in families, then fetch from chipIssuers
        address issuer = StorageLib.getIssuerFromFamilies(tokenId);
        return issuer != address(0) ? issuer : StorageLib.chipIssuers()[tokenId];
    }
}
