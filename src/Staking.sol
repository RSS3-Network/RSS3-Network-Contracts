// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {IChips} from "./interfaces/IChips.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Errors} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant sharesPerChip = 500 * 10 ** 18;
    uint256 public constant firstStakingAmount = 10000 * 10 ** 18;

    uint256 public constant DELEGATION_RATIO = 25;

    /// @dev The period of time that a node can't withdraw staked tokens
    uint256 internal _stakeUnbondingPeriod;
    /// @dev The period of time that a node can't withdraw delegated tokens
    uint256 internal _delegateUnbondingPeriod;

    /// @dev all node addresses
    EnumerableSet.AddressSet internal _nodeAddrs;
    /// @dev all node info
    mapping(address nodeAddr => DataTypes.Node) internal _nodes;

    /// @dev unstake request queue counter
    uint256 internal _unstakeRequestCounter;
    /// @dev unstake request queue
    mapping(uint256 requestId => DataTypes.UnstakeRequest) internal _unstakeQueue;

    /// @dev undelegate request queue counter
    uint256 internal _undelegateRequestCounter;
    /// @dev undelegate request queue
    mapping(uint256 requestId => DataTypes.UndelegateRequest) internal _undelegateQueue;

    /// @dev the chips contract
    address internal _chips;
    /// @dev the staking token contract
    address internal _token;

    /// @dev the issuers of chips
    mapping(uint256 tokenId => address nodeAddr) internal _issuers;

    /// ACL
    bytes32 public constant PAUSE_ROLE =
        0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d; // keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE =
        0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1; // keccak256("ORACLE_ROLE");

    /// @inheritdoc IStaking
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token,
        uint256 stakeUnbondingPeriod,
        uint256 delegateUnbondingPeriod
    ) external override initializer {
        _chips = chips;
        _token = token;

        _stakeUnbondingPeriod = stakeUnbondingPeriod;
        _delegateUnbondingPeriod = delegateUnbondingPeriod;

        _grantRole(PAUSE_ROLE, pauseAccount);
        _grantRole(ORACLE_ROLE, oracleAccount);
    }

    /// @inheritdoc IStaking
    function pause() external override whenNotPaused onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @inheritdoc IStaking
    function unpause() external override whenPaused onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    /// @inheritdoc IStaking
    function createNodeAndStake(
        string calldata name,
        string calldata description,
        uint256 taxFraction,
        string calldata endpoint,
        uint256 amount
    ) external override {
        _createNode(msg.sender, name, description, taxFraction, endpoint);
        _stake(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function createNode(
        string calldata name,
        string calldata description,
        uint256 taxFraction,
        string calldata endpoint
    ) external override {
        _createNode(msg.sender, name, description, taxFraction, endpoint);
    }

    /// @inheritdoc IStaking
    function deleteNode(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (msg.sender != node.account) revert Errors.CallerNotNodeOwner();

        // can't delete a node with staked or delegated tokens
        if (node.delegatedAmount > 0 || node.selfStakedAmount > 0)
            revert Errors.NodeStakedOrDelegated();

        delete _nodes[nodeAddr];
        _nodeAddrs.remove(nodeAddr);

        emit Events.NodeDeleted(nodeAddr);
    }

    /// @inheritdoc IStaking
    function setNodeTaxFraction(address nodeAddr, uint256 taxFraction) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (msg.sender != node.account) revert Errors.CallerNotNodeOwner();

        node.taxFraction = taxFraction;

        emit Events.NodeTaxFractionSet(nodeAddr, taxFraction);
    }

    /// @inheritdoc IStaking
    function stake(uint256 amount) external override {
        _stake(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function requestUnstake(uint256 amount) external override returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        //  staking tokens has been slashed completely
        if (amount > node.selfStakedAmount) revert Errors.StakingTokensSlashedAll();

        node.selfStakedAmount = node.selfStakedAmount - amount;

        requestId = ++_unstakeRequestCounter;

        DataTypes.UnstakeRequest storage request = _unstakeQueue[requestId];
        request.timestamp = uint40(block.timestamp);
        request.owner = msg.sender;
        request.unstakedAmount = amount;

        // withdraw operator pool rewards
        _withdrawOperatorPoolRewards(node);

        emit Events.UnstakeRequested(msg.sender, amount, requestId);
    }

    /// @inheritdoc IStaking
    function withdrawOperatorPoolRewards(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        _withdrawOperatorPoolRewards(node);
    }

    /// @inheritdoc IStaking
    function withdrawTax(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        uint256 claimableTax = node.tax - node.claimedTax;

        IERC20(_token).safeTransfer(node.account, claimableTax);

        emit Events.TaxWithdrawn(node.account, claimableTax);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimUnstake(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function delegate(
        address nodeAddr,
        uint256 amount
    ) external override returns (uint256 startTokenId, uint256 endTokenId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        uint256 shares = _getShares(node, amount);
        uint256 chipsCount = shares / sharesPerChip;
        if (chipsCount == 0) revert Errors.AmountTooSmall();

        // mint chips
        (startTokenId, endTokenId) = IChips(_chips).mintBatch(msg.sender, chipsCount);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            _issuers[i] = nodeAddr;
        }

        uint256 remainder = (shares % sharesPerChip) * (_getPoolTokens(node) / node.totalShares);
        uint256 delegatedAmount = amount - remainder;
        // update reward pool
        node.delegatedAmount = node.delegatedAmount + delegatedAmount;

        // transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), delegatedAmount);

        emit Events.Delegated(msg.sender, nodeAddr, delegatedAmount, startTokenId, endTokenId);

        return (startTokenId, endTokenId);
    }

    /// @inheritdoc IStaking
    function requestUndelegate(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external override returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        // check and burn chips
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert Errors.NotChipsOwner();

            if (_issuers[tokenId] != nodeAddr) revert Errors.NotTokenIssuer(tokenId, nodeAddr);

            IChips(_chips).burn(tokenId);
        }

        requestId = ++_undelegateRequestCounter;

        // update rewards
        uint256 shares = sharesPerChip * chipsIds.length;
        uint256 rewards = (shares * node.rewardPoolTotalRewards) / node.totalShares;
        uint256 undelegatedAmount = (shares * node.delegatedAmount) / node.totalShares;

        // add to request queue
        DataTypes.UndelegateRequest storage request = _undelegateQueue[requestId];
        request.timestamp = block.timestamp;
        request.owner = msg.sender;
        request.nodeAddr = nodeAddr;
        request.rewards = rewards;
        request.undelegatedAmount = undelegatedAmount;

        emit Events.UndelegateRequested(msg.sender, nodeAddr, requestId, chipsIds);
    }

    /// @inheritdoc IStaking
    function claimUndelegate(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimUndelegate(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function distributeRewards(
        uint256 epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address[] calldata nodeAddrs,
        uint256[] calldata operatorPoolRewards,
        uint256[] calldata rewardPoolRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeAddrs.length != operatorPoolRewards.length ||
            nodeAddrs.length != rewardPoolRewards.length
        ) revert Errors.InvalidArrayLength();

        uint256[] memory taxAmounts = new uint256[](nodeAddrs.length);
        uint256[] memory stakingRewards = new uint256[](nodeAddrs.length);

        // update node rewards
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];
            DataTypes.Node storage node = _nodes[nodeAddr];
            node.operatorPoolTotalRewards = node.operatorPoolTotalRewards + operatorPoolRewards[i];

            // update tax
            uint256 tax = _getTax(
                rewardPoolRewards[i],
                node.taxFraction,
                node.selfStakedAmount,
                node.delegatedAmount
            );
            node.tax = node.tax + tax;
            taxAmounts[i] = tax;

            // update staking rewards
            uint256 rewardsAfterTax = rewardPoolRewards[i] - tax;
            node.rewardPoolTotalRewards = node.rewardPoolTotalRewards + rewardsAfterTax;
            stakingRewards[i] = rewardsAfterTax;
        }

        emit Events.RewardDistributed(
            epoch,
            startTimestamp,
            endTimestamp,
            nodeAddrs,
            operatorPoolRewards,
            stakingRewards,
            taxAmounts
        );
    }

    /// @inheritdoc IStaking
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) revert Errors.NodeNotExists();

            // TODO: slash node
            uint256 slashedAmount;

            emit Events.NodeSlashed(nodeAddrs[i], slashedAmount);
        }
    }

    /// @inheritdoc IStaking
    function minTokensToDelegate(address nodeAddr) external view override returns (uint256) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.totalShares == 0) {
            return sharesPerChip;
        }

        return (sharesPerChip * _getPoolTokens(node)) / node.totalShares;
    }

    /// @inheritdoc IStaking
    function getChipsInfo(
        uint256 tokenId
    ) external view override returns (address nodeAddr, uint256 tokens) {
        nodeAddr = _issuers[tokenId];

        if (nodeAddr != address(0)) {
            DataTypes.Node storage node = _nodes[nodeAddr];
            tokens = (_getPoolTokens(node) / node.totalShares) * sharesPerChip;
        }
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getNodes() external view override returns (DataTypes.Node[] memory) {
        uint256 len = _nodeAddrs.length();
        DataTypes.Node[] memory res = new DataTypes.Node[](len);
        for (uint256 i = 0; i < len; i++) {
            address nodeAddr = _nodeAddrs.at(i);
            res[i] = _nodes[nodeAddr];
        }
        return res;
    }

    /// @dev create a node
    function _createNode(
        address nodeAddr,
        string calldata name,
        string calldata description,
        uint256 taxFraction,
        string calldata endpoint
    ) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (address(0) != node.account) revert Errors.NodeExists();

        node.account = nodeAddr;
        node.name = name;
        node.description = description;
        node.taxFraction = taxFraction;
        node.endpoint = endpoint;

        emit Events.NodeCreated(nodeAddr, name, description, taxFraction, endpoint);
    }

    function _stake(address nodeAddr, uint256 amount) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        if (node.selfStakedAmount == 0 && amount < firstStakingAmount)
            revert Errors.AmountTooSmall();

        // update operator pool
        node.selfStakedAmount = node.selfStakedAmount + amount;
        // TODO: update shares by staking amount
        // transfer tokens
        IERC20(_token).safeTransferFrom(nodeAddr, address(this), amount);

        emit Events.Staked(nodeAddr, amount);
    }

    /// @dev claim undelegate request
    function _claimUndelegate(uint256 requestId) internal {
        DataTypes.UndelegateRequest storage request = _undelegateQueue[requestId];

        if (request.claimed) revert Errors.AlreadyClaimed();
        if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
            revert Errors.ClaimTimeNotReady();

        // set claimed status
        request.claimed = true;

        // transfer
        IERC20(_token).safeTransfer(request.owner, request.undelegatedAmount);
        IERC20(_token).safeTransfer(request.owner, request.rewards);

        emit Events.UndelegateClaimed(
            requestId,
            request.nodeAddr,
            request.owner,
            request.undelegatedAmount,
            request.rewards
        );
    }

    /// @dev claim unstake request
    function _claimUnstake(uint256 requestId) internal {
        DataTypes.UnstakeRequest storage request = _unstakeQueue[requestId];

        if (request.claimed) revert Errors.AlreadyClaimed();
        if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
            revert Errors.ClaimTimeNotReady();

        // set claimed status
        request.claimed = true;

        // transfer staked tokens
        IERC20(_token).safeTransfer(request.owner, request.unstakedAmount);

        emit Events.UnstakeClaimed(requestId);
    }

    /// @dev withdraw operator pool rewards
    function _withdrawOperatorPoolRewards(DataTypes.Node storage node) internal {
        // get rewards
        uint256 rewards = _getOperatorPoolRewards(node);

        // update claimed rewards
        node.claimedOperatorPoollRewards = node.operatorPoolTotalRewards;

        // transfer rewards
        IERC20(_token).safeTransfer(node.account, rewards);

        emit Events.OperatorPoolRewardsWithdrawn(node.account, node.account, rewards);
    }

    function _getPoolTokens(DataTypes.Node memory node) internal pure returns (uint256) {
        return node.rewardPoolTotalRewards + node.delegatedAmount;
    }

    /// @dev get operator pool rewards
    function _getOperatorPoolRewards(DataTypes.Node memory node) internal pure returns (uint256) {
        return node.operatorPoolTotalRewards - node.claimedOperatorPoollRewards;
    }

    /// @dev get shares amount
    function _getShares(
        DataTypes.Node memory node,
        uint256 delegateAmount
    ) internal pure returns (uint256 sharesAmount) {
        if (node.totalShares == 0) {
            sharesAmount = delegateAmount;
        } else {
            sharesAmount = (delegateAmount * _getPoolTokens(node)) / _getPoolTokens(node);
        }
    }

    /// @dev get tax amount
    function _getTax(
        uint256 rewards,
        uint256 taxFraction,
        uint256 selfStakedAmount,
        uint256 delegatedAmount
    ) internal pure returns (uint256) {
        uint256 delegationCapacity = selfStakedAmount * DELEGATION_RATIO;
        if (delegatedAmount <= delegationCapacity) {
            // node will receive its full tax
            return (rewards * taxFraction) / _taxDenominator();
        }
        return (delegationCapacity * taxFraction) / _taxDenominator();
    }

    /**
     * @dev The denominator with which to interpret the tax as a fraction.
     * Defaults to 10000 so tax is expressed in basis points.
     */
    function _taxDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
