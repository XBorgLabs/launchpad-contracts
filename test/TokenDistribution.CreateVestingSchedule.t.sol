// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Token} from "./mock/Token.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenDistributionCreateVestingSchedule is Base {
    event VestingScheduleCreated(bytes32 indexed vestingScheduleId, address token, address indexed beneficiary, uint256 start, uint256 cliff, uint256 duration, uint256 indexed amount);

    function test_createVestingSchedule_hasTokens() public {
        uint256 contractBalance = IERC20(token).balanceOf(address(tokenDistribution));
        assertEq(contractBalance, 1000 * 10**18);
    }

    function test_createVestingSchedule_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 0;
        uint256 amount = 1000 * 10**18;

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_wrongToken() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 0;
        uint256 amount = 10000 * 10**18;

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        tokenDistribution.createVestingSchedule(address(0), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_wrongBeneficiary() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 0;
        uint256 amount = 10000 * 10**18;

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        tokenDistribution.createVestingSchedule(address(token), address(0), start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_notEnoughTokens() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 0;
        uint256 amount = 10000 * 10**18;

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS"));
        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_wrongDuration() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 0;
        uint256 amount = 1000 * 10**18;

        vm.expectRevert(bytes("WRONG_DURATION"));
        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_wrongAmount() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 3600;
        uint256 amount = 3599;

        vm.expectRevert(bytes("WRONG_AMOUNT"));
        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_wrongTime() public {
        vm.startPrank(MANAGER);
        vm.warp(2000);

        uint256 start = block.timestamp - 1000;
        uint256 cliff = 3000;
        uint256 duration = 3600;
        uint256 amount = 1000 * 10**18;

        vm.expectRevert(bytes("WRONG_TIME"));
        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule_wrongDurationCliff() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 1000;
        uint256 duration = 1;
        uint256 amount = 1000 * 10**18;

        vm.expectRevert(bytes("WRONG_DURATION_CLIFF"));
        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function test_createVestingSchedule() public {
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), 0);
        assertEq(tokenDistribution.holdersVestingCount(TESTER), 0);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 0);

        // Create vesting schedule
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 60; // Unlock after 1 minute, you get at cliff 60/600 = 10% of the tokens
        uint256 duration = 600; // Linear vests over 10 minutes
        uint256 amount = 1000 * 10**18;

        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), amount);
        assertEq(tokenDistribution.vestingSchedulesIds(0), tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0));
        assertEq(tokenDistribution.holdersVestingCount(TESTER), 1);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 1);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), 0);

        vm.stopPrank();

        // Before Cliff
        vm.warp(start + 59);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), 0);

        // Cliff
        vm.warp(start + 60);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount * 10 / 100);

        // Fully unvested
        vm.warp(start + 600);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount);
    }

    function test_createVestingSchedule_event() public {
        // Create vesting schedule
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 60; // Unlock after 1 minute, you get at cliff 60/600 = 10% of the tokens
        uint256 duration = 600; // Linear vests over 10 minutes
        uint256 amount = 1000 * 10**18;

        bytes32 vestingScheduleId = tokenDistribution.computeNextVestingScheduleIdForHolder(address(TESTER));

        vm.expectEmit();
        emit VestingScheduleCreated(vestingScheduleId, address(token), address(TESTER), start, cliff, duration, amount);

        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);
    }

    function test_createVestingSchedule_token2() public {
        // Deal some tokens
        deal(address(token2), address(tokenDistribution), 500 * 10**18);

        // Create another token vesting schedule
        createVestingSchedule(token);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token2)), 0);
        assertEq(tokenDistribution.holdersVestingCount(TESTER), 1);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 1);

        // Create vesting schedule
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 900; // Unlock after 15 minutes, you get at cliff 900/6000 = 15% of the tokens
        uint256 duration = 6000; // Linear vests over 100 minutes
        uint256 amount = 500 * 10**18;

        tokenDistribution.createVestingSchedule(address(token2), TESTER, start, cliff, duration, amount);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token2)), amount);
        assertEq(tokenDistribution.vestingSchedulesIds(1), tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 1));
        assertEq(tokenDistribution.holdersVestingCount(TESTER), 2);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 2);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), 0);

        vm.stopPrank();

        // Before Cliff
        vm.warp(start + 899);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), 0);

        // Cliff
        vm.warp(start + 900);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), amount * 15 / 100);

        // Fully unvested
        vm.warp(start + 6000);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), amount);
    }

    function test_createVestingScheduleWithImmediateRelease() public {
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), 0);
        assertEq(tokenDistribution.holdersVestingCount(TESTER), 0);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 0);

        // Create vesting schedule
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0; // Unlock after immediately
        uint256 duration = 600; // Linear vests over 10 minutes
        uint256 amount = 1000 * 10**18;

        tokenDistribution.createVestingSchedule(address(token), TESTER, start, cliff, duration, amount);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), amount);
        assertEq(tokenDistribution.vestingSchedulesIds(0), tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, 0));
        assertEq(tokenDistribution.holdersVestingCount(TESTER), 1);
        assertEq(tokenDistribution.getVestingSchedulesCount(), 1);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), 0);

        vm.stopPrank();

        // Before Cliff
        vm.warp(start);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), 0);

        // Cliff
        vm.warp(start + 1);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount * 1 / 600);

        // 50%
        vm.warp(start + 300);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount * 50 / 100);

        // Fully unvested
        vm.warp(start + 600);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount);
    }

    function test_createMultipleVestingSchedules_wrongParams() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 600;
        uint256 amount = 1000 * 10**18;

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = TESTER;
        beneficiaries[1] = TESTER;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.expectRevert(bytes("WRONG_PARAMS"));
        tokenDistribution.createMultipleVestingSchedules(address(token), beneficiaries, start, cliff, duration, amounts);

        vm.stopPrank();
    }

    function test_createMultipleVestingSchedules() public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 0;
        uint256 duration = 600;
        uint256 amount = 500 * 10**18;
        uint256 amount2 = 249 * 10**18;

        address[] memory beneficiaries = new address[](2);
        beneficiaries[0] = TESTER;
        beneficiaries[1] = TESTER;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount2;

        tokenDistribution.createMultipleVestingSchedules(address(token), beneficiaries, start, cliff, duration, amounts);

        vm.stopPrank();

        // Before Cliff
        vm.warp(start);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), 0);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), 0);

        // Cliff
        vm.warp(start + 1);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount * 1 / 600);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), amount2 * 1 / 600);

        // 50%
        vm.warp(start + 300);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount * 50 / 100);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), amount2 * 50 / 100);

        // Fully unvested
        vm.warp(start + 600);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(0)), amount);
        assertEq(tokenDistribution.computeReleasableAmount(tokenDistribution.vestingSchedulesIds(1)), amount2);
    }

    function test_computeNextVestingScheduleIdForHolder() public {
        uint256 index = 0;
        bytes32 expectedResult = keccak256(abi.encodePacked(TESTER, index));
        assertEq(tokenDistribution.computeNextVestingScheduleIdForHolder(TESTER), expectedResult);

        createVestingSchedule(token);
        index = 1;
        expectedResult = keccak256(abi.encodePacked(TESTER, index));
        assertEq(tokenDistribution.computeNextVestingScheduleIdForHolder(TESTER), expectedResult);
    }

    function test_computeVestingScheduleIdForAddressAndIndex() public {
        uint256 index = 0;
        bytes32 expectedResult = keccak256(abi.encodePacked(TESTER, index));
        assertEq(tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, index), expectedResult);

        createVestingSchedule(token);
        index = 1;
        expectedResult = keccak256(abi.encodePacked(TESTER, index));
        assertEq(tokenDistribution.computeVestingScheduleIdForAddressAndIndex(TESTER, index), expectedResult);
    }
}
