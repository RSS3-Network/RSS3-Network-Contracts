// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract NetworkParams is Initializable, AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    string internal _params;

    event ParamsSet(string params);

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
     * @notice Sets params to the contract.
     * @param params The params to set.
     */
    function setParams(string calldata params) external onlyRole(ADMIN_ROLE) {
        _params = params;

        emit ParamsSet(params);
    }

    /**
     * @notice Gets params from the contract.
     * @return params The params to get.
     */
    function getParams() external view returns (string memory) {
        return _params;
    }
}
