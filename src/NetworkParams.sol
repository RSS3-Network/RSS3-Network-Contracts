// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract NetworkParams is Initializable, AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Mapping from epoch to configuration parameters
    mapping(uint64 epoch => string params) private _params;
    uint64[] private _orderedEpochs;

    event ParamsSet(uint64 indexed epoch, string params);

    /**
     * @notice Initializes the NetworkParams contract.
     * @param adminAccount Address who can set params to the NetworkParams contract.
     */
    function initialize(address adminAccount) external initializer {
        _grantRole(ADMIN_ROLE, adminAccount);
        _grantRole(0x00, adminAccount);
    }

    /**
     * @notice Sets configuration parameters for a specific epoch.
     * @dev Adds the epoch to the sorted list and maps it to the provided parameters.
     * @param epoch The epoch (as a uint64) to which the parameters should be associated.
     * @param params The configuration parameters (as a string) to be set.
     */
    function setParams(uint64 epoch, string calldata params) external onlyRole(ADMIN_ROLE) {
        if (bytes(_params[epoch]).length == 0) {
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

    /**
     * @notice inserts the epoch into the ordered list of epochs.
     * @param epoch The epoch to be inserted.
     */
    function _insertOrderedEpoch(uint64 epoch) private {
        uint256 insertIndex = _findInsertIndex(epoch);
        _orderedEpochs.push(0);

        for (uint256 i = _orderedEpochs.length - 1; i > insertIndex; i--) {
            _orderedEpochs[i] = _orderedEpochs[i - 1];
        }
        _orderedEpochs[insertIndex] = epoch;
    }

    /**
     * @notice Finds the index at which the epoch should be inserted in the ordered list of epochs.
     * @param epoch The epoch for which the index is to be found.
     * @return The index at which the epoch should be inserted.
     */
    function _findInsertIndex(uint64 epoch) private view returns (uint256) {
        uint256 low = 0;
        uint256 high = _orderedEpochs.length;
        while (low < high) {
            uint256 mid = Math.average(low, high);
            if (_orderedEpochs[mid] < epoch) {
                low = mid + 1;
            } else {
                high = mid;
            }
        }
        return high;
    }

    /**
     * @notice Finds the nearest epoch to the target epoch.
     * @param targetEpoch The epoch for which the nearest epoch is to be found.
     * @return The nearest epoch to the target epoch.
     */
    function _findNearestEpoch(uint64 targetEpoch) private view returns (uint64) {
        uint256 low = 0;
        uint256 high = _orderedEpochs.length - 1;
        while (low < high) {
            uint256 mid = Math.average(low, high + 1);
            if (_orderedEpochs[mid] <= targetEpoch) {
                low = mid;
            } else {
                high = mid - 1;
            }
        }
        return _orderedEpochs[low];
    }
}
