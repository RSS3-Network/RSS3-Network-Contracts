// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.24;

import {NetworkParams} from "../src/NetworkParams.sol";
import {CommonTest} from "./helpers/CommonTest.sol";
import {LibZip} from "@solady/utils/LibZip.sol";

contract NetworkParamsTest is CommonTest {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    NetworkParams internal _params;

    event ParamsSet(uint64 indexed epoch, bytes params);

    function setUp() public {
        _params = new NetworkParams();
        _params.initialize(alice);
    }

    function testSetParams() public {
        vm.prank(alice);
        _params.grantRole(ADMIN_ROLE, bob);

        string memory paramsStr = "{hello world}";
        bytes memory compressedParams = LibZip.flzCompress(bytes(paramsStr));

        expectEmit();
        emit ParamsSet(100, compressedParams);
        vm.prank(bob);
        _params.setParams(100, compressedParams);

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

        bytes memory compressedParams100 = LibZip.flzCompress(bytes(epoch100ParamsStr));
        bytes memory compressedParams200 = LibZip.flzCompress(bytes(epoch200ParamsStr));
        bytes memory compressedParams200Modified =
            LibZip.flzCompress(bytes(epoch200ParamsStrModified));
        bytes memory compressedParams300 = LibZip.flzCompress(bytes(epoch300ParamsStr));
        bytes memory compressedParams30 = LibZip.flzCompress(bytes(epoch30ParamsStr));

        expectEmit();
        emit ParamsSet(100, compressedParams100);
        vm.prank(bob);
        _params.setParams(100, compressedParams100);

        expectEmit();
        emit ParamsSet(300, compressedParams300);
        vm.prank(bob);
        _params.setParams(300, compressedParams300);

        expectEmit();
        emit ParamsSet(200, compressedParams200);
        vm.prank(bob);
        _params.setParams(200, compressedParams200);

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
        emit ParamsSet(200, compressedParams200Modified);
        vm.prank(bob);
        _params.setParams(200, compressedParams200Modified);

        // Equal to 200
        assertEq(_params.getParams(200), epoch200ParamsStrModified);

        // Update earlier epoch
        expectEmit();
        emit ParamsSet(30, compressedParams30);
        vm.prank(bob);
        _params.setParams(30, compressedParams30);

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
