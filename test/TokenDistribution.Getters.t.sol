// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Token} from "./mock/Token.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenDistributionGetters is Base {
    function test_getVestingSchedulesCountByBeneficiary() public {
        createVestingSchedule(token);

        assertEq(tokenDistribution.getVestingSchedulesCountByBeneficiary(OWNER), 0);
        assertEq(tokenDistribution.getVestingSchedulesCountByBeneficiary(TESTER), 1);
    }

    function test_computeReleasableAmount_notRevoked() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        // Revoke
        vm.startPrank(MANAGER);
        tokenDistribution.revoke(id);
        vm.stopPrank();

        vm.expectRevert(bytes("REVOKED"));
        tokenDistribution.computeReleasableAmount(id);
    }

    function test_computeReleasableAmount() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        (,,uint256 cliff,,, uint256 amountTotal,,) = tokenDistribution.vestingSchedules(id);
        vm.warp(cliff);

        assertEq(tokenDistribution.computeReleasableAmount(id), amountTotal * 10 / 100);
    }

    function test_getVestingIdAtIndex_wrongIndex() public {
        createVestingSchedule(token);

        vm.expectRevert(bytes("WRONG_INDEX"));
        tokenDistribution.getVestingIdAtIndex(1);
    }

    function test_getVestingIdAtIndex() public {
        createVestingSchedule(token);

        assertEq(tokenDistribution.getVestingIdAtIndex(0), tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0));
    }

    function test_getVestingScheduleByAddressAndIndex() public {
        createVestingSchedule(token);

        TokenDistribution.VestingSchedule memory vestingSchedule = tokenDistribution.getVestingScheduleByAddressAndIndex(TESTER, 0);
        assertEq(vestingSchedule.beneficiary, TESTER);
        assertEq(vestingSchedule.cliff, 61);
        assertEq(vestingSchedule.start, 1);
        assertEq(vestingSchedule.duration, 600);
        assertEq(vestingSchedule.amountTotal, 1000 * 10**18);
        assertEq(vestingSchedule.released, 0);
    }

    function test_getVestingSchedulesCount() public {
        createVestingSchedule(token);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 1);
    }

    function test_getVestingSchedule() public {
        createVestingSchedule(token);
        bytes32 id = tokenDistribution.getVestingIdAtIndex(0);

        TokenDistribution.VestingSchedule memory vestingSchedule = tokenDistribution.getVestingSchedule(id);
        assertEq(vestingSchedule.beneficiary, TESTER);
        assertEq(vestingSchedule.cliff, 61);
        assertEq(vestingSchedule.start, 1);
        assertEq(vestingSchedule.duration, 600);
        assertEq(vestingSchedule.amountTotal, 1000 * 10**18);
        assertEq(vestingSchedule.released, 0);
    }

    function test_getLastVestingSchedule() public {
        createVestingSchedule(token);

        TokenDistribution.VestingSchedule memory vestingSchedule = tokenDistribution.getLastVestingScheduleForHolder(TESTER);
        assertEq(vestingSchedule.beneficiary, TESTER);
        assertEq(vestingSchedule.cliff, 61);
        assertEq(vestingSchedule.start, 1);
        assertEq(vestingSchedule.duration, 600);
        assertEq(vestingSchedule.amountTotal, 1000 * 10**18);
        assertEq(vestingSchedule.released, 0);
    }
}
