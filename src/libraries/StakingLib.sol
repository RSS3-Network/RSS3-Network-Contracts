// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase,no-empty-blocks
pragma solidity 0.8.24;

import {IChips} from "../interfaces/IChips.sol";
import {Const} from "./Const.sol";
import {Node, NodeStatus, UnstakeRequest, WithdrawalRequest} from "./DataTypes.sol";
import {
    ChipIdsArrayTooSmall,
    ChipNotAuthorized,
    ChipNotValid,
    ChipsNotSameOwner,
    ClaimIdNotExists,
    ClaimTimeNotReady,
    DepositForPublicGoodNode,
    EmptyChipIds,
    ExcessWithdrawalAmount,
    NodeInExitStatus,
    StakeAmountTooSmall,
    WithdrawalAmountExceedsOperationPoolTokens
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {NodePoolLib} from "./NodePoolLib.sol";
import {StorageLib} from "./StorageLib.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

library StakingLib {
    using Address for address;

    /// @dev deposit tokens to a node
    function deposit(address nodeAddr, uint256 amount) external {
        Node storage node = StorageLib.getNodeOrRevert(nodeAddr);
        if (node.publicGood) revert DepositForPublicGoodNode();

        NodePoolLib.increaseOperationPool(node, amount);

        // set node status
        if (node.operationPoolTokens >= Const.MIN_DEPOSIT) {
            NodeStatus curStatus = node.status;
            if (curStatus == NodeStatus.None || curStatus == NodeStatus.Exited) {
                node.status = NodeStatus.Registered;
                emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Registered);
            }
        }

        emit Events.Deposited(nodeAddr, amount);
    }

    function stakeToNode(Node storage node, uint256 amount, address nodeAddr, address staker)
        external
        returns (uint256 tokenId)
    {
        // staking amount must be greater than MIN_STAKE
        if (amount < Const.MIN_STAKE) revert StakeAmountTooSmall();

        // node should not in exit status
        _validateNodeNotInExitStatus(nodeAddr);

        uint256 sharesToMint = _tokensToShares(amount, nodeAddr);

        // update staking pool
        NodePoolLib.increaseStakingPool(node, amount);
        // update pool shares
        _increaseTotalShares(node, sharesToMint);

        // mint chip with shares
        tokenId = _mintChipWithShares(nodeAddr, staker, sharesToMint);

        // set startTokenId and endTokenId to tokenId, for compatibility with the previous version
        emit Events.Staked(staker, node.account, amount, tokenId, tokenId);
    }

    /// @dev unstake from a node by burning chips
    function unstakeFromNode(address nodeAddr, uint256[] calldata chipIds)
        external
        returns (uint256 requestId)
    {
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

            // burn chips and clear corresponding shares
            _burnChipWithShares(tokenId);
        }
        Node storage node = _getStakingNode(nodeAddr);
        NodePoolLib.decreaseStakingPool(node, unstakeAmount);
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

    function requestWithdrawal(address nodeAddr, uint256 amount)
        external
        returns (uint256 requestId)
    {
        Node storage node = StorageLib.getNodeOrRevert(nodeAddr);

        //  withdrawal amount should not exceed the operation pool tokens
        if (amount > node.operationPoolTokens) revert WithdrawalAmountExceedsOperationPoolTokens();

        // deposit balance must >= MIN_DEPOSIT when node is not in `Exited` status
        NodeStatus status = node.status;
        if (NodeStatus.Exited != status && node.operationPoolTokens - amount < Const.MIN_DEPOSIT) {
            revert ExcessWithdrawalAmount();
        }

        NodePoolLib.decreaseOperationPool(node, amount);

        requestId = StorageLib.nextPendingWithdrawalId();

        // save withdrawal request
        WithdrawalRequest storage req = StorageLib.getPendingWithdrawal()[requestId];
        req.timestamp = uint40(block.timestamp);
        req.owner = node.account;
        req.amount = amount;

        emit Events.WithdrawRequested(node.account, amount, requestId);
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

    /// @dev merge chips into a new chip
    function mergeChips(uint256[] calldata chipIds) external returns (uint256 newTokenId) {
        if (chipIds.length < 2) revert ChipIdsArrayTooSmall(chipIds.length);

        address nodeAddr = _issuerOf(chipIds[0]);
        address owner = _checkChipsConditions(nodeAddr, chipIds);
        uint256 totalShares;
        for (uint256 i = 0; i < chipIds.length; i++) {
            uint256 tokenId = chipIds[i];
            (,, uint256 shares) = _chipInfo(tokenId);
            totalShares += shares;

            // burn chips and clear corresponding shares
            _burnChipWithShares(tokenId);
        }

        // mint new chip with total shares
        newTokenId = _mintChipWithShares(nodeAddr, owner, totalShares);

        emit Events.ChipsMerged(owner, nodeAddr, newTokenId, chipIds);
    }

    /// @dev get chip info: node address, tokens, shares
    function getChipInfo(uint256 tokenId)
        external
        view
        returns (address nodeAddr, uint256 tokens, uint256 shares)
    {
        (nodeAddr, tokens, shares) = _chipInfo(tokenId);
    }

    /**
     * @dev Mints a new chip token and associate it with the specified shares.
     * It also sets the issuer of the chip token and shares corresponding to the staking tokens.
     * @param issuer The address of the issuer of the chip token, which is the node address.
     * @param to The address to which the minted chip token will be transferred.
     * @param shares The number of shares associated with the minted chip token.
     * @return tokenId The ID of the minted chip token.
     */
    function _mintChipWithShares(address issuer, address to, uint256 shares)
        internal
        returns (uint256 tokenId)
    {
        address chips = StorageLib.getChipsContract();
        tokenId = IChips(chips).mint(to);

        StorageLib.chipIssuers()[tokenId] = issuer;
        StorageLib.chipToShares()[tokenId] = shares;
    }

    /**
     * @dev Burns a chip token and removes associated shares, issuer.
     * @param tokenId The ID of the chip token to burn.
     */
    function _burnChipWithShares(uint256 tokenId) internal {
        address chips = StorageLib.getChipsContract();
        IChips(chips).burn(tokenId);

        delete StorageLib.chipToShares()[tokenId];
        delete StorageLib.chipIssuers()[tokenId];
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
    /// 1. caller has the authorization to unstake/merge the chips
    /// 2. chips are issued by the same node
    /// 3. chips have the same owner
    function _checkChipsConditions(address nodeAddr, uint256[] calldata chipIds)
        internal
        view
        returns (address)
    {
        address chips = StorageLib.getChipsContract();
        address lastOwner;
        for (uint256 i = 0; i < chipIds.length; i++) {
            uint256 tokenId = chipIds[i];
            // check if all the chips have the same owner
            address owner = IERC721(chips).ownerOf(tokenId);
            if (lastOwner != address(0) && owner != lastOwner) revert ChipsNotSameOwner();
            lastOwner = owner;

            // check if the caller is authorized to unstake/merge the chips
            if (!_isAuthorized(owner, tokenId, msg.sender)) revert ChipNotAuthorized(tokenId);

            // check if the chip is issued by the node
            if (_issuerOf(tokenId) != nodeAddr) revert ChipNotValid(tokenId, nodeAddr);
        }

        return lastOwner;
    }

    /// @dev convert staking tokens to equivalent shares
    function _tokensToShares(uint256 tokens, address nodeAddr) internal view returns (uint256) {
        Node storage node = _getStakingNode(nodeAddr);
        if (node.stakingPoolTokens == 0) {
            return tokens;
        }

        return (tokens * node.totalShares) / node.stakingPoolTokens;
    }

    /// @dev convert shares to equivalent staking tokens
    function _sharesToTokens(uint256 shares, address nodeAddr) internal view returns (uint256) {
        Node storage node = _getStakingNode(nodeAddr);
        if (node.totalShares == 0) {
            return 0;
        }

        return (shares * node.stakingPoolTokens) / node.totalShares;
    }

    /// @dev get node by address, if the node is public good, return public pool
    function _getStakingNode(address nodeAddr) internal view returns (Node storage node) {
        node = StorageLib.getNode(nodeAddr);

        // if the node is public good, return public pool
        if (node.publicGood) {
            node = StorageLib.publicPool();
        }
    }

    /// @dev returns chip info: node address, tokens, shares
    function _chipInfo(uint256 tokenId)
        internal
        view
        returns (address nodeAddr, uint256 tokens, uint256 shares)
    {
        nodeAddr = _issuerOf(tokenId);
        // return (0, 0, 0) if the chip issuer is not found
        if (nodeAddr == address(0)) return (address(0), 0, 0);

        shares = StorageLib.chipToShares()[tokenId];

        // if shares is 0, it always mean the chip is old version, and the shares is fixed to
        // SHARES_PER_CHIP
        if (shares == 0) {
            shares = Const.SHARES_PER_CHIP;
        }

        // calculate tokens from shares
        tokens = _sharesToTokens(shares, nodeAddr);
    }

    /// @dev returns whether user is token owner or approved
    function _isAuthorized(address owner, uint256 tokenId, address user)
        internal
        view
        returns (bool)
    {
        address chips = StorageLib.getChipsContract();

        return owner == user || IERC721(chips).getApproved(tokenId) == user
            || IERC721(chips).isApprovedForAll(owner, user);
    }

    /// @dev returns the node address which issued the chips
    function _issuerOf(uint256 tokenId) internal view returns (address) {
        // return address(0) if the chip is not existing or burned
        address chips = StorageLib.getChipsContract();
        try IERC721(chips).ownerOf(tokenId) returns (address) {}
        catch (bytes memory) {
            return address(0);
        }

        // fetch issuer, if not found in families, then fetch from chipIssuers
        address issuer = StorageLib.getIssuerFromFamilies(tokenId);
        return issuer != address(0) ? issuer : StorageLib.chipIssuers()[tokenId];
    }

    /// @dev Validates that a node is not in an exit status (Exiting or Exited).
    function _validateNodeNotInExitStatus(address nodeAddr) internal view {
        Node storage node = StorageLib.getNode(nodeAddr);
        NodeStatus status = node.status;
        if (NodeStatus.Exiting == status || NodeStatus.Exited == status) revert NodeInExitStatus();
    }
}
