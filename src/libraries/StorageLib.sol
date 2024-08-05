// SPDX-License-Identifier: MIT
// solhint-disable no-inline-assembly
pragma solidity 0.8.20;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

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

    uint256 public constant TOTAL_OPERATION_POOL_TOKENS_SLOT = 21;
    uint256 public constant TOTAL_STAKING_POOL_TOKENS_SLOT = 22;

    uint256 public constant FAMILIES_SLOT = 23;

    uint256 public constant CHIP_ISSUERS_MAPPING_SLOT = 24;
    uint256 public constant CHIP_TO_SHARES_MAPPING_SLOT = 25;

    uint256 public constant TOTAL_SLASHING_POOL_TOKENS_SLOT = 26;
    uint256 public constant SLASH_RECORDS_SLOT = 27;

    // keccak256(abi.encode(uint256(keccak256("staking.storage.public.pool")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 public constant PUBLIC_POOL_SLOT_LOCATION =
        0x8f8113410d98c63dc5c1c4f1ac9eaef4d76f695bf1ef91dca2f23702b51d9400;

    function setTotalOperationPoolTokens(uint256 totalOperatingPoolTokens) internal {
        assembly {
            sstore(TOTAL_OPERATION_POOL_TOKENS_SLOT, totalOperatingPoolTokens)
        }
    }

    function setTotalStakingPoolTokens(uint256 totalStakingPoolTokens) internal {
        assembly {
            sstore(TOTAL_STAKING_POOL_TOKENS_SLOT, totalStakingPoolTokens)
        }
    }

    function setTotalSlashingPoolTokens(uint256 totalSlashingPoolTokens) internal {
        assembly {
            sstore(TOTAL_SLASHING_POOL_TOKENS_SLOT, totalSlashingPoolTokens)
        }
    }

    function nextNodeId() internal returns (uint256 newCounter) {
        assembly {
            let currentCounter := sload(NODE_ID_COUNTER_SLOT)
            newCounter := add(currentCounter, 1)
            sstore(NODE_ID_COUNTER_SLOT, newCounter)
        }
    }

    function nextPendingUnstakeId() internal returns (uint256 newCounter) {
        assembly {
            let currentCounter := sload(PENDING_UNSTAKE_COUNTER_SLOT)
            newCounter := add(currentCounter, 1)
            sstore(PENDING_UNSTAKE_COUNTER_SLOT, newCounter)
        }
    }

    function nextPendingWithdrawalId() internal returns (uint256 newCounter) {
        assembly {
            let currentCounter := sload(PENDING_WITHDRAWAL_COUNTER_SLOT)
            newCounter := add(currentCounter, 1)
            sstore(PENDING_WITHDRAWAL_COUNTER_SLOT, newCounter)
        }
    }

    function getChipsContract() internal view returns (address chips) {
        assembly {
            chips := sload(CHIPS_CONTRACT_ADDRESS_SLOT)
        }
    }

    function getTotalOperatingPoolTokens() internal view returns (uint256 totalOperatingPoolTokens) {
        assembly {
            totalOperatingPoolTokens := sload(TOTAL_OPERATION_POOL_TOKENS_SLOT)
        }
    }

    function getTotalStakingPoolTokens() internal view returns (uint256 totalStakingPoolTokens) {
        assembly {
            totalStakingPoolTokens := sload(TOTAL_STAKING_POOL_TOKENS_SLOT)
        }
    }

    function getTotalSlashingPoolTokens() internal view returns (uint256 totalSlashingPoolTokens) {
        assembly {
            totalSlashingPoolTokens := sload(TOTAL_SLASHING_POOL_TOKENS_SLOT)
        }
    }

    function getIsAlphaPhase() internal view returns (bool isAlphaPhase) {
        assembly {
            let slotValue := sload(IS_ALPHA_PHASE_SLOT)
            isAlphaPhase := and(shr(mul(IS_ALPHA_PHASE_OFFSET, 8), slotValue), 1)
        }
    }

    function getIssuerFromFamilies(uint256 tokenId) internal view returns (address issuer) {
        Checkpoints.Trace160 storage families;
        assembly {
            families.slot := FAMILIES_SLOT
        }
        issuer = address(families.lowerLookup(tokenId.toUint96()));
    }

    function chipIssuers() internal pure returns (mapping(uint256 => address) storage _chipIssuers) {
        assembly {
            _chipIssuers.slot := CHIP_ISSUERS_MAPPING_SLOT
        }
    }

    function chipToShares() internal pure returns (mapping(uint256 => uint256) storage _chipToShares) {
        assembly {
            _chipToShares.slot := CHIP_TO_SHARES_MAPPING_SLOT
        }
    }

    function getSlashRecord(
        address nodeAddr,
        uint256 epochId
    ) internal pure returns (DataTypes.SlashRecord storage record) {
        assembly {
            mstore(0x00, nodeAddr)
            mstore(0x20, SLASH_RECORDS_SLOT)
            mstore(0x20, keccak256(0x00, 0x40))
            mstore(0x00, epochId)
            record.slot := keccak256(0x00, 0x40)
        }
    }

    function getPendingUnstake()
        internal
        pure
        returns (mapping(uint256 => DataTypes.UnstakeRequest) storage _pendingUnstake)
    {
        assembly {
            _pendingUnstake.slot := PENDING_UNSTAKE_MAPPING_BY_REQUEST_ID_SLOT
        }
    }

    function getPendingWithdrawal()
        internal
        pure
        returns (mapping(uint256 => DataTypes.WithdrawalRequest) storage _pendingWithdrawals)
    {
        assembly {
            _pendingWithdrawals.slot := PENDING_WITHDRAWAL_MAPPING_BY_REQUEST_ID_SLOT
        }
    }

    function nodeAddrs() internal pure returns (EnumerableSet.AddressSet storage _nodeAddrs) {
        assembly {
            _nodeAddrs.slot := NODES_ADDRESS_SET_SLOT
        }
    }

    function getNode(address nodeAddr) internal pure returns (DataTypes.Node storage _node) {
        assembly {
            mstore(0x00, nodeAddr)
            mstore(0x20, NODES_MAPPING_BY_NODE_ADDRESS_SLOT)
            _node.slot := keccak256(0x00, 0x40)
        }
    }

    function publicPool() internal pure returns (DataTypes.Node storage $) {
        assembly {
            $.slot := PUBLIC_POOL_SLOT_LOCATION
        }
    }
}
