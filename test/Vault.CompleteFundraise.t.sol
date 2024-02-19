// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultCompleteFundraise is Base {
    event FundraiseCompleted(uint256 indexed index, address indexed beneficiary, uint256 amount);

    function createAndDepositFundraise(uint256 _depositAmount, bool _ended) internal {
        createFundraise(token);
        deal(address(token), TESTER, 10000 * 10**18);

        // Move forward in time
        (,,,, uint256 startTime, uint256 endTime,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        token.approve(address(vault), _depositAmount);
        vault.deposit(0, _depositAmount);

        // Move forward to the end
        if (_ended) {
            vm.warp(endTime + 1);
        }

        vm.stopPrank();
    }

    function test_completeFundraise_notAllowed() public {
        uint256 depositAmount = 100 * 10**18;
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(TESTER);

        vm.expectRevert(bytes("NOT_ALLOWED"));
        vault.completeFundraise(0);

        vm.stopPrank();
    }

    function test_completeFundraise_aboveSoftCap() public {
        uint256 depositAmount = 99 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(BENEFICIARY);

        vm.expectRevert(bytes("SOFT_CAP_NOT_MET"));
        vault.completeFundraise(0);

        vm.stopPrank();
    }

    function test_completeFundraise_notEnded() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(BENEFICIARY);

        vm.expectRevert(bytes("NOT_ENDED"));
        vault.completeFundraise(0);

        vm.stopPrank();
    }

    function test_completeFundraise_fundsAlreadyWithdrawn() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        vm.startPrank(BENEFICIARY);

        // Complete
        vault.completeFundraise(0);

        // Can't do it again
        vm.expectRevert(bytes("FUNDS_ALREADY_WITHDRAWN"));
        vault.completeFundraise(0);

        vm.stopPrank();
    }

    function test_completeFundraise() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        (,,,,,,,,, bool completedStart) = vault.fundraises(0);
        assertFalse(completedStart);

        vm.startPrank(BENEFICIARY);

        // Complete
        vault.completeFundraise(0);

        (,,,,,,,,, bool completedEnd) = vault.fundraises(0);
        assertTrue(completedEnd);
        assertEq(token.balanceOf(BENEFICIARY), depositAmount);
        assertEq(token.balanceOf(OWNER), 0);

        vm.stopPrank();
    }

    function test_completeFundraise_owner() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        (,,,,,,,,, bool completedStart) = vault.fundraises(0);
        assertFalse(completedStart);

        vm.startPrank(MANAGER);

        // Complete
        vault.completeFundraise(0);

        (,,,,,,,,, bool completedEnd) = vault.fundraises(0);
        assertTrue(completedEnd);
        assertEq(token.balanceOf(BENEFICIARY), depositAmount);
        assertEq(token.balanceOf(OWNER), 0);

        vm.stopPrank();
    }

    function test_completeFundraise_emptyRaise() public {
        vm.startPrank(MANAGER);

        uint256 softCap = 0;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp + 60;
        uint256 endTime = block.timestamp + 660;
        bool whitelistEnabled = true;

        // Create fundraise
        vault.createFundraise(address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        (,,,,,,,,, bool completedStart) = vault.fundraises(0);
        assertFalse(completedStart);

        vm.warp(endTime + 1);

        // Complete with no deposits
        vault.completeFundraise(0);

        (,,,,,,,,, bool completedEnd) = vault.fundraises(0);
        assertTrue(completedEnd);
        assertEq(token.balanceOf(BENEFICIARY), 0);
        assertEq(token.balanceOf(OWNER), 0);
    }

    function test_completeFundraise_event() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        (,,,,,,,,, bool completedStart) = vault.fundraises(0);
        assertFalse(completedStart);

        vm.startPrank(BENEFICIARY);

        // Complete
        vm.expectEmit();
        emit FundraiseCompleted(0, BENEFICIARY, depositAmount);

        vault.completeFundraise(0);

        vm.stopPrank();
    }
}
