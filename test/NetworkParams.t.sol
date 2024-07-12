// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {NetworkParams} from "../src/NetworkParams.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {NoETHMock} from "../lib/solady/ext/wake/NoETHMock.sol";

contract NetworkParamsTest is CommonTest {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    event ParamsSet(uint64 epoch, string params);

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
        emit ParamsSet(100, paramsStr);
        vm.prank(bob);
        _params.setParams(100, paramsStr);

        assertEq(_params.getParams(100), paramsStr);
    }

    function testGetCurrentParams() public {
        vm.prank(alice);
        _params.grantRole(ADMIN_ROLE, bob);

        string memory epoch100ParamsStr = "{epoch100ParamsStr}";
        string memory epoch200ParamsStr = "{epoch200ParamsStr}";
        string memory epoch300ParamsStr = "{epoch300ParamsStr}";

        expectEmit();
        emit ParamsSet(100, epoch100ParamsStr);
        vm.prank(bob);
        _params.setParams(100, epoch100ParamsStr);

        expectEmit();
        emit ParamsSet(300, epoch300ParamsStr);
        vm.prank(bob);
        _params.setParams(300, epoch300ParamsStr);

        expectEmit();
        emit ParamsSet(200, epoch200ParamsStr);
        vm.prank(bob);
        _params.setParams(200, epoch200ParamsStr);

        // Below 100
        assertEq(_params.getParams(50), epoch100ParamsStr);
        //  Equal to 100
        assertEq(_params.getParams(100), epoch100ParamsStr);
        // Between 100 and 200
        assertEq(_params.getParams(150), epoch100ParamsStr);
        // Equal to 200
        assertEq(_params.getParams(200), epoch200ParamsStr);
        // Above 200 but below 300
        assertEq(_params.getParams(250), epoch200ParamsStr);
        // Equal to 300
        assertEq(_params.getParams(300), epoch300ParamsStr);
        // Above 300
        assertEq(_params.getParams(350), epoch300ParamsStr);
    }

    function testSetParamsFail() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ADMIN_ROLE));
        _params.setParams(100, "hello world");
    }

    function testEmptyParams() public {
        assertEq(_params.getParams(100), "");
    }
}
