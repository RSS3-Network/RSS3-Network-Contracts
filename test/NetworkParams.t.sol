// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {NetworkParams} from "../src/NetworkParams.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {NoETHMock} from "../lib/solady/ext/wake/NoETHMock.sol";

contract NetworkParamsTest is CommonTest {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event ParamsSet(string params);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    NetworkParams internal _params;

    function setUp() public {
        _params = new NetworkParams();
        _params.initialize(alice);
    }

    function testSetParams() public {
        vm.prank(alice);
        _params.grantRole(ADMIN_ROLE, bob);

        string memory paramsStr = "{hello world}";

        expectEmit();
        emit ParamsSet(paramsStr);
        vm.prank(bob);
        _params.setParams(paramsStr);

        assertEq(_params.getParams(), paramsStr);
    }

    function testSetParamsFail() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ADMIN_ROLE));
        _params.setParams("hello world");
    }
}
