// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract NetworkParams is Initializable, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping from epoch to configuration parameters
    mapping(uint64 => string) private _params;
    // Sorted set of epoch keys using EnumerableSet to maintain order
    EnumerableSet.UintSet private _epochs;
    uint64[] private _orderedEpochs;

    event ParamsSet(uint64 epoch, string params);

    /**
     * @notice Initializes the NetworkParams contract.
     * @dev Emits the `ParamsSet` event.
     * @param adminAccount Address who can set params to the NetworkParams contract.
     */
    function initialize(address adminAccount) external initializer {
        _grantRole(ADMIN_ROLE, adminAccount);
        _grantRole(0x00, adminAccount);
    }

    /**
     * @notice Sets configuration parameters for a specific epoch.
     * @dev Adds the epoch to the sorted set and maps it to the provided parameters.
     * @param epoch The epoch (as a uint64) to which the parameters should be associated.
     * @param params The configuration parameters (as a string) to be set.
     */
    function setParams(uint64 epoch, string calldata params) external onlyRole(ADMIN_ROLE) {
        bool updated = _epochs.contains(epoch);
        if (!updated) {
            _epochs.add(epoch);
            _insertOrderedEpoch(epoch);
        }

        _params[epoch] = params;
        emit ParamsSet(epoch, params);
    }

    /**
     * @notice Retrieves configuration parameters based on the epoch provided.
     * @dev Performs a binary search on the sorted set of epochs to find the closest preceding or exact match.
     * @param epoch The epoch for which the parameters are requested.
     * @return params The configuration parameters associated with the nearest epoch.
     */
    function getParams(uint64 epoch) external view returns (string memory) {
        if (_orderedEpochs.length == 0) {
            return "";
        }

        uint64 nearestEpoch = _findNearestEpoch(epoch);
        return _params[nearestEpoch];
    }

    function _insertOrderedEpoch(uint64 epoch) private {
        uint256 insertIndex = _findInsertIndex(epoch);
        _orderedEpochs.push(0);

        for (uint256 i = _orderedEpochs.length - 1; i > insertIndex; i--) {
            _orderedEpochs[i] = _orderedEpochs[i - 1];
        }

        _orderedEpochs[insertIndex] = epoch;
    }

    function _findInsertIndex(uint64 epoch) private view returns (uint256) {
        uint256 left = 0;
        uint256 right = _orderedEpochs.length;

        while (left < right) {
            uint256 mid = left + (right - left) / 2;
            if (_orderedEpochs[mid] < epoch) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }

        return left;
    }

    function _findNearestEpoch(uint64 targetEpoch) private view returns (uint64) {
        uint256 left = 0;
        uint256 right = _orderedEpochs.length - 1;

        while (left < right) {
            uint256 mid = left + (right - left + 1) / 2;
            if (_orderedEpochs[mid] <= targetEpoch) {
                left = mid;
            } else {
                right = mid - 1;
            }
        }

        return _orderedEpochs[left];
    }
}
