// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TokenDistributionRelease is Base {
    event Release(bytes32 indexed vestingScheduleId, uint256 indexed amount);

    function test_release_revoked() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), vestingAmount);

        (,,,,,uint256 amountTotalInitial, uint256 releasedInitial,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalInitial, vestingAmount);
        assertEq(releasedInitial, 0);

        uint256 withdrawalAddressInitialBalance = token.balanceOf(DEPLOYER);

        // Revoke
        vm.startPrank(MANAGER);
        tokenDistribution.revoke(id);
        vm.stopPrank();

        vm.startPrank(DEPLOYER);

        vm.expectRevert(bytes("REVOKED"));
        tokenDistribution.release(id, vestingAmount);

        uint256 withdrawalAddressFinalBalance = token.balanceOf(DEPLOYER);

        (,,,,, uint256 amountTotalFinal, uint256 releasedFinal,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalFinal, vestingAmount);
        assertEq(releasedFinal, 0);
        assertEq(withdrawalAddressFinalBalance - withdrawalAddressInitialBalance, 0);

        vm.stopPrank();
    }

    function test_release_notAllowed() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), vestingAmount);

        (,,,,,uint256 amountTotalInitial, uint256 releasedInitial,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalInitial, vestingAmount);
        assertEq(releasedInitial, 0);

        uint256 withdrawalAddressInitialBalance = token.balanceOf(DEPLOYER);

        vm.startPrank(address(DEPLOYER));

        vm.expectRevert(bytes("NOT_ALLOWED"));
        tokenDistribution.release(id, vestingAmount);

        uint256 withdrawalAddressFinalBalance = token.balanceOf(DEPLOYER);

        (,,,,, uint256 amountTotalFinal, uint256 releasedFinal,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalFinal, vestingAmount);
        assertEq(releasedFinal, 0);
        assertEq(withdrawalAddressFinalBalance - withdrawalAddressInitialBalance, 0);

        vm.stopPrank();
    }

    function test_release_notEnoughTokensReleased() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), vestingAmount);

        (,,,,, uint256 amountTotalInitial, uint256 releasedInitial,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalInitial, vestingAmount);
        assertEq(releasedInitial, 0);

        uint256 withdrawalAddressInitialBalance = token.balanceOf(TESTER);

        vm.startPrank(address(TESTER));

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS_RELEASED"));
        tokenDistribution.release(id, vestingAmount);

        uint256 withdrawalAddressFinalBalance = token.balanceOf(TESTER);

        (,,,,,uint256 amountTotalFinal, uint256 releasedFinal,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalFinal, vestingAmount);
        assertEq(releasedFinal, 0);
        assertEq(withdrawalAddressFinalBalance - withdrawalAddressInitialBalance, 0);

        vm.stopPrank();
    }

    function test_release_notEnoughTokens() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), vestingAmount);

        (,,uint256 start,, uint256 duration, uint256 amountTotalInitial, uint256 releasedInitial,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalInitial, vestingAmount);
        assertEq(releasedInitial, 0);

        uint256 withdrawalAddressInitialBalance = token.balanceOf(TESTER);

        // Set wrong amount of tokens on TokenDistribution
        deal(address(token), address(tokenDistribution), 0);

        vm.startPrank(MANAGER);
        vm.warp(start + duration);

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS"));
        tokenDistribution.release(id, vestingAmount);

        uint256 withdrawalAddressFinalBalance = token.balanceOf(TESTER);

        (,,,,,uint256 amountTotalFinal, uint256 releasedFinal,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalFinal, vestingAmount);
        assertEq(releasedFinal, 0);
        assertEq(withdrawalAddressFinalBalance - withdrawalAddressInitialBalance, 0);

        vm.stopPrank();
    }

    function test_release_beneficiary() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), vestingAmount);

        (,,uint256 cliff,,, uint256 amountTotalInitial, uint256 releasedInitial,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalInitial, vestingAmount);
        assertEq(releasedInitial, 0);

        uint256 withdrawalAddressInitialBalance = token.balanceOf(TESTER);

        vm.startPrank(address(TESTER));

        // Unlock cliff
        vm.warp(cliff);
        uint256 cliffAmount = vestingAmount * 10 / 100;
        assertEq(tokenDistribution.computeReleasableAmount(id), cliffAmount);

        tokenDistribution.release(id, cliffAmount);

        uint256 withdrawalAddressFinalBalance = token.balanceOf(TESTER);

        (,,,,,uint256 amountTotalFinal, uint256 releasedFinal,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalFinal, vestingAmount);
        assertEq(releasedFinal, cliffAmount);
        assertEq(withdrawalAddressFinalBalance - withdrawalAddressInitialBalance, cliffAmount);
        assertEq(tokenDistribution.computeReleasableAmount(id), 0);

        vm.stopPrank();
    }

    function test_release_releasor() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), vestingAmount);

        (,,uint256 cliff,,, uint256 amountTotalInitial, uint256 releasedInitial,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalInitial, vestingAmount);
        assertEq(releasedInitial, 0);

        uint256 withdrawalAddressInitialBalance = token.balanceOf(TESTER);

        vm.startPrank(MANAGER);

        // Unlock cliff
        vm.warp(cliff);
        uint256 cliffAmount = vestingAmount * 10 / 100;
        assertEq(tokenDistribution.computeReleasableAmount(id), cliffAmount);

        tokenDistribution.release(id, cliffAmount);

        uint256 withdrawalAddressFinalBalance = token.balanceOf(TESTER);

        (,,,,,uint256 amountTotalFinal, uint256 releasedFinal,) = tokenDistribution.vestingSchedules(id);
        assertEq(amountTotalFinal, vestingAmount);
        assertEq(releasedFinal, cliffAmount);
        assertEq(withdrawalAddressFinalBalance - withdrawalAddressInitialBalance, cliffAmount);
        assertEq(tokenDistribution.computeReleasableAmount(id), 0);

        vm.stopPrank();
    }

    function test_release_event() public {
        // Create initial schedule
        createVestingSchedule(token);

        uint256 vestingAmount = 1000 * 10**18;
        bytes32 id = tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0);

        // Unlock cliff
        (,,uint256 cliff,,,,,) = tokenDistribution.vestingSchedules(id);
        vm.warp(cliff);
        uint256 cliffAmount = vestingAmount * 10 / 100;

        vm.startPrank(MANAGER);

        vm.expectEmit();
        emit Release(id, cliffAmount);

        tokenDistribution.release(id, cliffAmount);
    }
}
