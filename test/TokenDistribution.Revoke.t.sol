// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Token} from "./mock/Token.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenDistributionRevoke is Base {
    event VestingScheduleRevoked(bytes32 indexed vestingScheduleId);

    function test_revoke_onlyOwner() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        vm.startPrank(TESTER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(TESTER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tokenDistribution.revoke(id);

        vm.stopPrank();
    }

    function test_revoke_revoked() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        vm.startPrank(MANAGER);

        tokenDistribution.revoke(id);

        vm.expectRevert(bytes("REVOKED"));
        tokenDistribution.revoke(id);

        vm.stopPrank();
    }

    function test_revoke_noTokens() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        (,,,,,,, bool revokedInitial) = tokenDistribution.vestingSchedules(id);
        assertFalse(revokedInitial);
        assertEq(tokenDistribution.computeReleasableAmount(id), 0);

        vm.startPrank(MANAGER);
        tokenDistribution.revoke(id);
        vm.stopPrank();

        (,,,,,,, bool revokedFinal) = tokenDistribution.vestingSchedules(id);
        assertTrue(revokedFinal);
    }

    function test_revoke_tokens() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        (,, uint256 cliff,,, uint256 amountTotal,, bool revokedInitial) = tokenDistribution.vestingSchedules(id);
        assertFalse(revokedInitial);
        assertEq(tokenDistribution.computeReleasableAmount(id), 0);
        uint256 balanceInitial = token.balanceOf(TESTER);

        vm.warp(cliff);
        assertEq(tokenDistribution.computeReleasableAmount(id), amountTotal * 10 / 100);

        vm.startPrank(MANAGER);
        tokenDistribution.revoke(id);
        vm.stopPrank();

        (,,,,,,, bool revokedFinal) = tokenDistribution.vestingSchedules(id);
        assertTrue(revokedFinal);
        uint256 balanceFinal = token.balanceOf(TESTER);
        assertEq(balanceFinal - balanceInitial, amountTotal * 10 / 100);
    }

    function test_revoke_event() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        vm.startPrank(MANAGER);

        vm.expectEmit();
        emit VestingScheduleRevoked(id);

        tokenDistribution.revoke(id);

        vm.stopPrank();
    }
}
