// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {NetworkParams} from "../src/NetworkParams.sol";
import {CommonTest} from "./helpers/CommonTest.sol";

contract NetworkParamsTest is CommonTest {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    NetworkParams internal _params;

    event ParamsSet(uint64 indexed epoch, string params);

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

    // solhint-disable-next-line function-max-lines
    function testGetCurrentParams() public {
        vm.prank(alice);
        _params.grantRole(ADMIN_ROLE, bob);

        string memory epoch100ParamsStr = "{epoch100ParamsStr}";
        string memory epoch200ParamsStr = "{epoch200ParamsStr}";
        string memory epoch200ParamsStrModified = "{epoch200ParamsStrModified}";
        string memory epoch300ParamsStr = "{epoch300ParamsStr}";
        string memory epoch30ParamsStr = "{epoch30ParamsStr}";

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
        // Pass epoch 0
        assertEq(_params.getParams(0), epoch100ParamsStr);

        // Update existing epoch 200
        expectEmit();
        emit ParamsSet(200, epoch200ParamsStrModified);
        vm.prank(bob);
        _params.setParams(200, epoch200ParamsStrModified);

        // Equal to 200
        assertEq(_params.getParams(200), epoch200ParamsStrModified);

        // Update earlier epoch
        expectEmit();
        emit ParamsSet(30, epoch30ParamsStr);
        vm.prank(bob);
        _params.setParams(30, epoch30ParamsStr);

        // Pass epoch 30
        assertEq(_params.getParams(0), epoch30ParamsStr);
        // Pass epoch 99
        assertEq(_params.getParams(99), epoch30ParamsStr);
        // Pass epoch 100
        assertEq(_params.getParams(100), epoch100ParamsStr);
    }

    function testSetParamsFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ADMIN_ROLE
            )
        );
        _params.setParams(100, "hello world");
    }

    function testEmptyParams() public view {
        assertEq(_params.getParams(100), "");
    }
}
