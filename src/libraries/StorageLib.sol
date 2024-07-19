// SPDX-License-Identifier: MIT
// solhint-disable no-inline-assembly
pragma solidity 0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {DataTypes} from "../libraries/DataTypes.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

library StorageLib {
    using Checkpoints for Checkpoints.Trace160;
    using SafeCast for uint256;

    // address chips, bool _isSettlementPhase, bool _isAlphaPhase
    uint256 public constant CHIPS_CONTRACT_ADDRESS_SLOT = 4;
    uint256 public constant IS_ALPHA_PHASE_SLOT = 4;

    uint256 public constant IS_ALPHA_PHASE_OFFSET = 21;

    uint256 public constant NODES_ADDRESS_SET_SLOT = 5; // EnumerableSet.AddressSet _nodeAddrs
    uint256 public constant NODES_MAPPING_BY_NODE_ADDRESS_SLOT = 7; // mapping(address nodeAddr => DataTypes.Node)_nodes
    uint256 public constant NODE_ID_COUNTER_SLOT = 8; // uint256 _nodeIdCounter
    uint256 public constant PENDING_WITHDRAWAL_COUNTER_SLOT = 9;
    uint256 public constant PENDING_WITHDRAWAL_MAPPING_BY_REQUEST_ID_SLOT = 10;
    uint256 public constant PENDING_UNSTAKE_COUNTER_SLOT = 11;
    uint256 public constant PENDING_UNSTAKE_MAPPING_BY_REQUEST_ID_SLOT = 12;

    uint256 public constant PUBLIC_POOL_SLOT = 13; // DataTypes.Node _publicPool;

    uint256 public constant TOTAL_OPERATION_POOL_TOKENS_SLOT = 21;
    uint256 public constant TOTAL_STAKING_POOL_TOKENS_SLOT = 22;

    uint256 public constant FAMILIES_SLOT = 23;

    uint256 public constant CHIP_ISSUERS_MAPPING_SLOT = 24;
    uint256 public constant CHIP_TO_SHARES_MAPPING_SLOT = 25;

    uint256 public constant TOTAL_SLASHING_POOL_TOKENS_SLOT = 26;
    uint256 public constant SLASH_RECORDS_SLOT = 27;

    function setTotalOperationPoolTokens(uint256 totalOperatingPoolTokens) external {
        assembly {
            sstore(TOTAL_OPERATION_POOL_TOKENS_SLOT, totalOperatingPoolTokens)
        }
    }

    function setTotalStakingPoolTokens(uint256 totalStakingPoolTokens) external {
        assembly {
            sstore(TOTAL_STAKING_POOL_TOKENS_SLOT, totalStakingPoolTokens)
        }
    }

    function setChipIssuerByTokenId(uint256 tokenId, address nodeAddr) external {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, CHIP_ISSUERS_MAPPING_SLOT)
            let slot := keccak256(0x00, 0x40)

            sstore(slot, nodeAddr)
        }
    }

    function setChipsToSharesByTokenId(uint256 tokenId, uint256 shares) external {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, CHIP_TO_SHARES_MAPPING_SLOT)
            let slot := keccak256(0x00, 0x40)

            sstore(slot, shares)
        }
    }

    function setTotalSlashingPoolTokens(uint256 totalSlashingPoolTokens) external {
        assembly {
            sstore(TOTAL_SLASHING_POOL_TOKENS_SLOT, totalSlashingPoolTokens)
        }
    }

    function deletePendingWithdrawal(uint256 requestId) external {
        assembly {
            mstore(0x00, requestId)
            mstore(0x20, PENDING_WITHDRAWAL_MAPPING_BY_REQUEST_ID_SLOT)
            let slot := keccak256(0x00, 0x40)

            sstore(slot, 0)
            sstore(add(slot, 1), 0)
        }
    }

    function deletePendingUnstake(uint256 requestId) external {
        assembly {
            mstore(0x00, requestId)
            mstore(0x20, PENDING_UNSTAKE_MAPPING_BY_REQUEST_ID_SLOT)
            let slot := keccak256(0x00, 0x40)

            sstore(slot, 0)
            sstore(add(slot, 1), 0)
            sstore(add(slot, 2), 0)
            sstore(add(slot, 3), 0)
        }
    }

    function nextNodeId() external returns (uint256 newCounter) {
        assembly {
            let currentCounter := sload(NODE_ID_COUNTER_SLOT)
            newCounter := add(currentCounter, 1)
            sstore(NODE_ID_COUNTER_SLOT, newCounter)
        }
    }

    function nextPendingUnstakeId() external returns (uint256 newCounter) {
        assembly {
            let currentCounter := sload(PENDING_UNSTAKE_COUNTER_SLOT)
            newCounter := add(currentCounter, 1)
            sstore(PENDING_UNSTAKE_COUNTER_SLOT, newCounter)
        }
    }

    function nextPendingWithdrawlId() external returns (uint256 newCounter) {
        assembly {
            let currentCounter := sload(PENDING_WITHDRAWAL_COUNTER_SLOT)
            newCounter := add(currentCounter, 1)
            sstore(PENDING_WITHDRAWAL_COUNTER_SLOT, newCounter)
        }
    }

    function getChipsContract() external view returns (address chips) {
        assembly {
            chips := sload(CHIPS_CONTRACT_ADDRESS_SLOT)
        }
    }

    function getTotalOperatingPoolTokens() external view returns (uint256 totalOperatingPoolTokens) {
        assembly {
            totalOperatingPoolTokens := sload(TOTAL_OPERATION_POOL_TOKENS_SLOT)
        }
    }

    function getTotalStakingPoolTokens() external view returns (uint256 totalStakingPoolTokens) {
        assembly {
            totalStakingPoolTokens := sload(TOTAL_STAKING_POOL_TOKENS_SLOT)
        }
    }

    function getTotalSlashingPoolTokens() external view returns (uint256 totalSlashingPoolTokens) {
        assembly {
            totalSlashingPoolTokens := sload(TOTAL_SLASHING_POOL_TOKENS_SLOT)
        }
    }

    function getIsAlphaPhase() external view returns (bool isAlphaPhase) {
        assembly {
            let slotValue := sload(IS_ALPHA_PHASE_SLOT)
            isAlphaPhase := and(shr(mul(IS_ALPHA_PHASE_OFFSET, 8), slotValue), 1)
        }
    }

    function getIssuerFromFamilies(uint256 tokenId) external view returns (address issuer) {
        Checkpoints.Trace160 storage families;
        assembly {
            families.slot := FAMILIES_SLOT
        }
        issuer = address(families.lowerLookup(tokenId.toUint96()));
    }

    function getIssuerFromChipIssuers(uint256 tokenId) external view returns (address issuer) {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, CHIP_ISSUERS_MAPPING_SLOT)
            let slot := keccak256(0x00, 0x40)

            issuer := sload(slot)
        }
    }

    function getChipsToSharesByTokenId(uint256 tokenId) external view returns (uint256 shares) {
        assembly {
            mstore(0x00, tokenId)
            mstore(0x20, CHIP_TO_SHARES_MAPPING_SLOT)
            let slot := keccak256(0x00, 0x40)

            shares := sload(slot)
        }
    }

    function getSlashRecord(address nodeAddr, uint256 epochId) external view returns (DataTypes.SlashRecord storage) {
        mapping(address nodeAddr => mapping(uint256 epochId => DataTypes.SlashRecord))
            storage slashRecords = _slashRecords();
        return slashRecords[nodeAddr][epochId];
    }

    function getPendingUnstake(
        uint256 requestId
    ) external pure returns (DataTypes.UnstakeRequest storage unstakeRequest) {
        assembly {
            mstore(0x00, requestId)
            mstore(0x20, PENDING_UNSTAKE_MAPPING_BY_REQUEST_ID_SLOT)
            let slot := keccak256(0x00, 0x40)

            unstakeRequest.slot := slot
        }
    }

    function getPendingWithdrawal(
        uint256 requestId
    ) external pure returns (DataTypes.WithdrawalRequest storage withdrawalRequest) {
        assembly {
            mstore(0x00, requestId)
            mstore(0x20, PENDING_WITHDRAWAL_MAPPING_BY_REQUEST_ID_SLOT)
            let slot := keccak256(0x00, 0x40)

            withdrawalRequest.slot := slot
        }
    }

    function nodeAddrs() external pure returns (EnumerableSet.AddressSet storage _nodeAddrs) {
        assembly {
            _nodeAddrs.slot := NODES_ADDRESS_SET_SLOT
        }
    }

    function nodes() external pure returns (mapping(address => DataTypes.Node) storage _nodes) {
        assembly {
            _nodes.slot := NODES_MAPPING_BY_NODE_ADDRESS_SLOT
        }
    }

    function publicPool() external pure returns (DataTypes.Node storage _publicPool) {
        assembly {
            _publicPool.slot := PUBLIC_POOL_SLOT
        }
    }

    function _slashRecords()
        internal
        pure
        returns (mapping(address nodeAddr => mapping(uint256 epochId => DataTypes.SlashRecord)) storage slashRecords)
    {
        assembly {
            slashRecords.slot := SLASH_RECORDS_SLOT
        }
    }
}
