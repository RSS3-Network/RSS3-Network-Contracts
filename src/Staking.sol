// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {IChips} from "./interfaces/IChips.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {Events} from "./libraries/Events.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract Staking is IStaking, IErrors, Pausable, Initializable, AccessControlEnumerable {
    using Math for uint256;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace160;

    uint256 public constant SHARES_PER_CHIP = 500 * 10 ** 18;

    /// @dev the staking token contract
    address public immutable TOKEN; // solhint-disable-line private-vars-leading-underscore

    /// @dev the ratio of total tokens to deposited tokens, 25 by default.
    /// node operator can receive its full tax if it deposits at least 1/25 of the tokens staked by external delegators
    uint256 public immutable STAKE_RATIO; // solhint-disable-line private-vars-leading-underscore

    /// @dev the treasury receives all unqualified rewards, e.g. the exceeding part of the tax
    address public immutable TREASURY; // solhint-disable-line private-vars-leading-underscore

    /// @dev slash fraction
    uint256 public immutable NODE_SLASH_FRACTION;
    uint256 public immutable USER_SLASH_FRACTION;

    /// @dev the minimal tokens for deposit, 10,000 by default.
    /// node operator can receive its full tax if it stakes at least 10,000 tokens
    uint256 public immutable MIN_DEPOSIT;

    /// @dev the period of time that node operator can't withdraw staked tokens
    uint256 public immutable DEPOSIT_UNBONDING_PERIOD;
    /// @dev the period of time that user can't withdraw staked tokens
    uint256 public immutable STAKE_UNBONDING_PERIOD;

    /// @dev the chips contract
    address internal _chips;

    /// @dev all node addresses
    EnumerableSet.AddressSet internal _nodeAddrs;
    /// @dev all node info
    mapping(address nodeAddr => DataTypes.Node) internal _nodes;

    /// @dev pending withdrawal request counter
    uint256 internal _pendingWithdrawalCounter;
    /// @dev pending withdrawal request
    mapping(uint256 requestId => DataTypes.WithdrawalRequest) internal _pendingWithdrawals;

    /// @dev unstake request queue counter
    uint256 internal _pendingUnstakeCounter;
    /// @dev unstake request queue
    mapping(uint256 requestId => DataTypes.UnstakeRequest) internal _pendingUnstake;

    /// @dev public pool
    DataTypes.Node internal _publicPool;

    uint256 internal _totalOperatingPool;

    uint256 internal _totalStakingPool;

    /// @dev the issuers of chips
    Checkpoints.Trace160 internal _families;

    /// @dev current epoch
    uint256 internal _currentEpoch;

    /// ACL
    // keccak256("PAUSE_ROLE");
    bytes32 public constant PAUSE_ROLE = 0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;
    // keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    /**
     * @notice constructor.
     * @param token The address of staking token.
     * @param treasury The address of treasury.
     * @param stakeRatio The stake ratio of the node operator.
     * @param stakeUnbondingPeriod Time in seconds user need to wait to unstake its stake.
     * @param depositUnbondingPeriod Time in seconds node operator need to wait to withdraw its deposit.
     * @param nodeSlashFraction Slash fraction for node operator.
     * @param userSlashFraction Slash fraction for user.
     * @param stakeRatio The stake ratio of the node operator.
     * @param minDeposit The deposit base line of the node operator.
     */
    constructor(
        address token,
        address treasury,
        uint256 stakeRatio,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        uint256 nodeSlashFraction,
        uint256 userSlashFraction,
        uint256 minDeposit
    ) {
        TOKEN = token;

        TREASURY = treasury;
        STAKE_RATIO = stakeRatio;

        STAKE_UNBONDING_PERIOD = stakeUnbondingPeriod;
        DEPOSIT_UNBONDING_PERIOD = depositUnbondingPeriod;

        NODE_SLASH_FRACTION = nodeSlashFraction;
        USER_SLASH_FRACTION = userSlashFraction;

        MIN_DEPOSIT = minDeposit;
    }

    /// @inheritdoc IStaking
    function initialize(address chips, address pauseAccount, address oracleAccount) external override initializer {
        _chips = chips;

        _grantRole(PAUSE_ROLE, pauseAccount);
        _setRoleAdmin(PAUSE_ROLE, PAUSE_ROLE);

        _grantRole(ORACLE_ROLE, oracleAccount);
        _setRoleAdmin(ORACLE_ROLE, ORACLE_ROLE);
    }

    /// @inheritdoc IStaking
    function pause() external override onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @inheritdoc IStaking
    function unpause() external override whenPaused onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    /// @inheritdoc IStaking
    function createNode(
        address to,
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint
    ) external override {
        _createNode(to, name, description, taxFraction, publicGood, endpoint);
    }

    /// @inheritdoc IStaking
    function deleteNode(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a node not operated by msg.sender
        if (msg.sender != node.account) revert CallerNotNodeOwner();

        // can't delete a node with staked or deposited tokens
        if (node.operatingPool > 0 || node.stakingPool > 0) revert NodeStakedOrDeposited();

        delete _nodes[nodeAddr];
        _nodeAddrs.remove(nodeAddr);

        emit Events.NodeDeleted(nodeAddr);
    }

    /// @inheritdoc IStaking
    function createNodeAndDeposit(
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint,
        uint256 amount
    ) external override whenNotPaused {
        if (publicGood) revert PublicGoodNodeNotDeposited();

        _createNode(msg.sender, name, description, taxFraction, publicGood, endpoint);
        _deposit(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function deposit(uint256 amount) external override whenNotPaused {
        _deposit(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function requestWithdrawal(uint256 amount) external override whenNotPaused returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert NodeNotExists();

        //  deposited tokens has been slashed completely
        if (amount > node.operatingPool) revert DepositedTokensSlashedAll();

        _decreaseOperatingPool(node, amount);

        requestId = ++_pendingWithdrawalCounter;

        DataTypes.WithdrawalRequest storage req = _pendingWithdrawals[requestId];
        req.timestamp = uint40(block.timestamp);
        req.owner = msg.sender;
        req.amount = amount;

        emit Events.WithdrawRequested(msg.sender, amount, requestId);
    }

    /// @inheritdoc IStaking
    function setTaxFraction4Node(address nodeAddr, uint64 taxFraction) external override {
        if (taxFraction > _denominator()) revert TaxFractionTooLarge();

        DataTypes.Node storage node = _nodes[nodeAddr];
        if (msg.sender != node.account) revert CallerNotNodeOwner();

        node.taxFraction = taxFraction;

        emit Events.NodeTaxFractionSet(nodeAddr, taxFraction);
    }

    /// @inheritdoc IStaking
    function setTaxFraction4PublicPool(uint64 taxFraction) external override onlyRole(ORACLE_ROLE) {
        if (taxFraction > _denominator()) revert TaxFractionTooLarge();

        _publicPool.taxFraction = taxFraction;

        emit Events.PublicPoolTaxFractionSet(taxFraction);
    }

    /// @inheritdoc IStaking
    function claimWithdrawal(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimWithdrawal(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function stake(
        address nodeAddr,
        uint256 amount
    ) external override whenNotPaused returns (uint256 startTokenId, uint256 endTokenId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // validate node
        if (node.account == address(0)) revert NodeNotExists();
        if (node.publicGood) revert PublicGoodNodeNotStaked(nodeAddr);

        (startTokenId, endTokenId) = _stakeToNode(node, amount, nodeAddr);
    }

    /// @inheritdoc IStaking
    function requestUnstake(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external override whenNotPaused returns (uint256 requestId) {
        return _unstakeFromNode(nodeAddr, chipsIds, false);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimUnstake(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function distributeRewards(
        uint256 epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestBonuses,
        uint256[] calldata stakingRewards,
        uint256 publicPoolReward
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeAddrs.length != requestFees.length ||
            nodeAddrs.length != requestBonuses.length ||
            nodeAddrs.length != stakingRewards.length
        ) revert InvalidArrayLength();

        if (epoch != ++_currentEpoch) revert InvalidEpoch(_currentEpoch, epoch);

        // distribute rewards for public pool
        uint256 publicPoolTax = _distributePublicPoolRewards(publicPoolReward);
        emit Events.PublicGoodRewardDistributed(epoch, startTimestamp, endTimestamp, publicPoolReward, publicPoolTax);

        // distribute rewards for other nodes
        uint256[] memory taxAmounts = _distributeNodesRewards(nodeAddrs, requestFees, requestBonuses, stakingRewards);

        emit Events.RewardDistributed(
            epoch,
            startTimestamp,
            endTimestamp,
            nodeAddrs,
            requestFees,
            requestBonuses,
            stakingRewards,
            taxAmounts
        );
    }

    /// @inheritdoc IStaking
    function requestUnstakeFromPublicPool(uint256[] calldata chipsIds) external override returns (uint256 requestId) {
        return _unstakeFromNode(address(0), chipsIds, true);
    }

    /// @inheritdoc IStaking
    function stakeToPublicPool(
        address nodeAddr,
        uint256 amount
    ) external override whenNotPaused returns (uint256 startTokenId, uint256 endTokenId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert NodeNotExists();
        if (!node.publicGood) revert NodeNotPublicGood(nodeAddr);
        (startTokenId, endTokenId) = _stakeToNode(_publicPool, amount, nodeAddr);
    }

    /// @inheritdoc IStaking
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) revert NodeNotExists();

            // slash operator pool tokens
            uint256 slashedOperatingPool = (node.operatingPool * NODE_SLASH_FRACTION) / _denominator();
            _decreaseOperatingPool(node, slashedOperatingPool);

            // slash reward pool tokens
            uint256 slashedStakingPool = (node.stakingPool * USER_SLASH_FRACTION) / _denominator();
            _decreaseStakingPool(node, slashedStakingPool);

            node.slashedAmount += slashedOperatingPool + slashedStakingPool;

            emit Events.NodeSlashed(nodeAddrs[i], slashedOperatingPool, slashedStakingPool);
        }
    }

    /// @inheritdoc IStaking
    function withdraw2Treasury() external override {
        uint256 amount = _getTreasuryAmount();
        IERC20(TOKEN).safeTransfer(TREASURY, amount);
    }

    /// @inheritdoc IStaking
    function getPendingWithdrawal(
        uint256 requestId
    ) external view override returns (DataTypes.WithdrawalRequest memory) {
        return _pendingWithdrawals[requestId];
    }

    /// @inheritdoc IStaking
    function getPendingUnstake(uint256 requestId) external view override returns (DataTypes.UnstakeRequest memory) {
        return _pendingUnstake[requestId];
    }

    /// @inheritdoc IStaking
    function minTokensToStake(address nodeAddr) external view override returns (uint256) {
        // Tokens per share
        return _minTokensToStake(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getChipsInfo(uint256 tokenId) external view override returns (address nodeAddr, uint256 tokens) {
        nodeAddr = _issuerOf(tokenId);
        tokens = _minTokensToStake(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getPublicPool() external view override returns (DataTypes.Node memory) {
        return _publicPool;
    }

    /// @inheritdoc IStaking
    function getNodeCount() external view override returns (uint256) {
        return _nodeAddrs.length();
    }

    /// @inheritdoc IStaking
    function getNodes(uint256 offset, uint256 limit) external view override returns (DataTypes.Node[] memory nodes) {
        uint256 totalNodes = _nodeAddrs.length();
        uint256 len = (totalNodes - offset).min(limit);
        nodes = new DataTypes.Node[](len);

        if (offset >= totalNodes) return nodes;

        for (uint256 i = offset; i < len + offset; i++) {
            address nodeAddr = _nodeAddrs.at(i);
            nodes[i - offset] = _nodes[nodeAddr];
        }
    }

    /// @inheritdoc IStaking
    function getPoolInfo() external view override returns (uint256, uint256, uint256) {
        return (_totalOperatingPool, _totalStakingPool, _getTreasuryAmount());
    }

    /// @inheritdoc IStaking
    function currentEpoch() external view override returns (uint256) {
        return _currentEpoch;
    }

    /// @inheritdoc IStaking
    function stakingToken() external view override returns (address) {
        return TOKEN;
    }

    /// @inheritdoc IStaking
    function chipsContract() external view override returns (address) {
        return _chips;
    }

    /// @inheritdoc IStaking
    function getMinDeposit() external view override returns (uint256) {
        return MIN_DEPOSIT;
    }

    function _increaseOperatingPool(DataTypes.Node storage node, uint256 amount) internal {
        node.operatingPool += amount;
        _totalOperatingPool += amount;
    }

    function _decreaseOperatingPool(DataTypes.Node storage node, uint256 amount) internal {
        node.operatingPool -= amount;
        _totalOperatingPool -= amount;
    }

    function _increaseStakingPool(DataTypes.Node storage node, uint256 amount) internal {
        node.stakingPool += amount;
        _totalStakingPool += amount;
    }

    function _decreaseStakingPool(DataTypes.Node storage node, uint256 amount) internal {
        node.stakingPool -= amount;
        _totalStakingPool -= amount;
    }

    function _distributePublicPoolRewards(uint256 publicPoolReward) internal returns (uint256) {
        // rewards for public pool
        uint256 tax = _getFullTax(publicPoolReward, _publicPool.taxFraction);

        _increaseStakingPool(_publicPool, publicPoolReward - tax);

        return tax;
    }

    function _distributeNodesRewards(
        address[] memory nodeAddrs,
        uint256[] memory requestFees,
        uint256[] memory requestBonuses,
        uint256[] memory stakingRewards
    ) internal returns (uint256[] memory) {
        uint256 remainedTax;
        uint256[] memory taxAmounts = new uint256[](nodeAddrs.length);
        // update node rewards
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) {
                continue;
            }

            // request bonus and staking rewards are sent to reward pool
            uint256 rewards = requestBonuses[i] + stakingRewards[i];

            uint256 fullTax;
            uint256 receivedTax;
            (fullTax, receivedTax) = _getTax(rewards, node.taxFraction, node.operatingPool, node.stakingPool);
            rewards -= fullTax;

            // request fee and tax are sent to operator pool
            uint256 operatingPool = requestFees[i] + receivedTax;
            taxAmounts[i] = receivedTax;
            remainedTax += fullTax - receivedTax;

            // update node
            _increaseOperatingPool(node, operatingPool);
            // all after-tax rewards and request bonus are sent to the reward pool
            _increaseStakingPool(node, rewards);
        }
        return taxAmounts;
    }

    function _unstakeFromNode(
        address nodeAddr,
        uint256[] calldata chipsIds,
        bool isPublicNode
    ) internal returns (uint256 requestId) {
        DataTypes.Node storage node = isPublicNode ? _publicPool : _nodes[nodeAddr];

        // check and burn chips
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender && IERC721(_chips).getApproved(tokenId) != msg.sender)
                revert ChipNotAuthorized(tokenId);

            if (isPublicNode) {
                nodeAddr = _issuerOf(tokenId);
                if (!_nodes[nodeAddr].publicGood) revert ChipNotPublicGood(tokenId);
            } else if (_issuerOf(tokenId) != nodeAddr) revert ChipNotValid(tokenId, nodeAddr);

            IChips(_chips).burn(tokenId);
        }

        requestId = ++_pendingUnstakeCounter;

        // update rewards
        uint256 shares = SHARES_PER_CHIP * chipsIds.length;
        uint256 unstakeAmount = _sharesToTokens(shares, node.totalShares, node.stakingPool);
        _decreaseStakingPool(node, unstakeAmount);
        node.totalShares -= shares;

        // add to request queue
        DataTypes.UnstakeRequest storage req = _pendingUnstake[requestId];
        req.timestamp = block.timestamp;
        req.owner = msg.sender;
        req.nodeAddr = node.account;
        req.unstakeAmount = unstakeAmount;

        emit Events.UnstakeRequested(msg.sender, node.account, requestId, chipsIds);
    }

    /// @dev create a node
    function _createNode(
        address nodeAddr,
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint
    ) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (address(0) != node.account) revert NodeExists();
        node.account = nodeAddr;
        node.name = name;
        node.description = description;
        node.taxFraction = taxFraction;
        node.publicGood = publicGood;
        node.endpoint = endpoint;

        // add to node list
        _nodeAddrs.add(nodeAddr);

        emit Events.NodeCreated(nodeAddr, name, description, taxFraction, publicGood, endpoint);
    }

    function _deposit(address nodeAddr, uint256 amount) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert NodeNotExists();

        // update operator pool
        _increaseOperatingPool(node, amount);

        // transfer tokens
        IERC20(TOKEN).safeTransferFrom(nodeAddr, address(this), amount);

        emit Events.Deposited(nodeAddr, amount);
    }

    /// @dev stakes tokens to a node
    function _stakeToNode(
        DataTypes.Node storage node,
        uint256 amount,
        address nodeAddr
    ) internal returns (uint256 startTokenId, uint256 endTokenId) {
        uint256 shares = _tokensToShares(amount, node.stakingPool, node.totalShares);
        uint256 chipsCount = shares / SHARES_PER_CHIP;
        if (chipsCount == 0) revert AmountTooSmall(amount);
        // mint chips
        (startTokenId, endTokenId) = IChips(_chips).mintBatch(msg.sender, chipsCount);

        // update stakedAmount
        uint256 stakedAmount = _sharesToTokens(chipsCount * SHARES_PER_CHIP, node.totalShares, node.stakingPool);
        _increaseStakingPool(node, stakedAmount);

        // update total shares
        node.totalShares += (chipsCount * SHARES_PER_CHIP);
        // transfer tokens
        IERC20(TOKEN).safeTransferFrom(msg.sender, address(this), stakedAmount);

        // update chips issuers
        _families.push(endTokenId.toUint96(), uint160(nodeAddr));

        emit Events.Staked(msg.sender, node.account, stakedAmount, startTokenId, endTokenId);
    }

    /// @dev claim unstake request
    function _claimUnstake(uint256 requestId) internal {
        DataTypes.UnstakeRequest memory req = _pendingUnstake[requestId];
        if (req.owner == address(0)) revert ClaimIdNotExists(requestId);

        if (block.timestamp < req.timestamp + STAKE_UNBONDING_PERIOD) revert ClaimTimeNotReady();

        // transfer
        IERC20(TOKEN).safeTransfer(req.owner, req.unstakeAmount);

        // delete request
        delete _pendingUnstake[requestId];

        emit Events.UnstakeClaimed(requestId, req.nodeAddr, req.owner, req.unstakeAmount);
    }

    /// @dev claim withdrawal request
    function _claimWithdrawal(uint256 requestId) internal {
        DataTypes.WithdrawalRequest memory req = _pendingWithdrawals[requestId];

        if (req.owner == address(0)) revert ClaimIdNotExists(requestId);

        if (block.timestamp < req.timestamp + DEPOSIT_UNBONDING_PERIOD) revert ClaimTimeNotReady();

        // transfer staked tokens
        IERC20(TOKEN).safeTransfer(req.owner, req.amount);

        // delete request
        delete _pendingWithdrawals[requestId];

        emit Events.WithdrawalClaimed(requestId);
    }

    function _issuerOf(uint256 tokenId) internal view returns (address) {
        // check the token was not burned, and fetch ownership from the anchors
        // Note: no need for safe cast, we know that tokenId <= type(uint96).max
        return address(_families.lowerLookup(tokenId.toUint96()));
    }

    function _getTreasuryAmount() internal view returns (uint256) {
        uint256 balance = IERC20(TOKEN).balanceOf(address(this));
        uint256 amount = balance - _totalOperatingPool - _totalStakingPool;
        return amount;
    }

    /// @dev get minimal tokens to stake for a node
    function _minTokensToStake(address nodeAddr) internal view returns (uint256) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.totalShares == 0) {
            return SHARES_PER_CHIP;
        }

        return (SHARES_PER_CHIP * node.stakingPool) / node.totalShares;
    }

    /**
     * @dev get tax amount
     *  For a node operator to receive its full tax,
     * it needs to stake at least 1/25 of the tokens staked by external delegators,
     * or the exceeding part of the tax will be sent to the reward pool.
     */
    function _getTax(
        uint256 rewards,
        uint64 taxFraction,
        uint256 operatingPool,
        uint256 rewardPool
    ) internal view returns (uint256, uint256) {
        uint256 fullTax = _getFullTax(rewards, taxFraction);

        if (operatingPool < MIN_DEPOSIT) {
            // node will receive no tax
            return (fullTax, 0);
        } else if (operatingPool >= MIN_DEPOSIT && operatingPool * STAKE_RATIO >= rewardPool) {
            // node will receive its full tax
            return (fullTax, fullTax);
        } else {
            // node will receive part of its tax
            uint256 partialTax = (fullTax * operatingPool * STAKE_RATIO) / rewardPool;
            return (fullTax, partialTax);
        }
    }

    function _getFullTax(uint256 rewards, uint64 taxFraction) internal pure returns (uint256) {
        return (rewards * taxFraction) / _denominator();
    }

    /// @dev convert shares to equivalent tokens
    function _sharesToTokens(uint256 shares, uint256 totalShares, uint256 totalAmount) internal pure returns (uint256) {
        if (totalShares == 0) {
            return shares;
        }

        return (shares * totalAmount) / totalShares;
    }

    /// @dev convert tokens to equivalent shares
    function _tokensToShares(uint256 amount, uint256 totalAmount, uint256 totalShares) internal pure returns (uint256) {
        if (totalAmount == 0) {
            return amount;
        }

        return (amount * totalShares) / totalAmount;
    }

    /**
     * @dev doniminator
     */
    function _denominator() internal pure virtual returns (uint64) {
        return 10000;
    }
}
