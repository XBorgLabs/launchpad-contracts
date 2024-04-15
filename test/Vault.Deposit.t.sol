// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultDeposit is Base {
    event Deposit(uint256 indexed index, address indexed sender, uint256 indexed amount);

    function enablePublic() internal {
        vm.startPrank(MANAGER);
        vault.setPublicFundraise(0, true, 1 * 10**18, 10 * 10**18);
        vm.stopPrank();
    }

    function test_deposit_onlyWhitelist() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        vm.startPrank(TESTER);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("ONLY_WHITELIST"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_notOpenEarly() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        vm.startPrank(TESTER);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("NOT_OPEN"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_notOpenLate() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,,, uint256 endTime,,,,) = vault.fundraises(0);
        vm.warp(endTime + 1);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        vm.startPrank(TESTER);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("NOT_OPEN"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_hardCap() public {
        createFundraise(token);
        deal(address(token), TESTER, 1001 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 1001 * 10**18; // Hard cap is 1000
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("HARD_CAP"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_zeroAmount() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 0 * 10**18;
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("ZERO_AMOUNT"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooSmall() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 10 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("UNDER_MIN_ALLOCATION"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooBig() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 70 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("OVER_MAX_ALLOCATION"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooSmallPublic() public {
        createFundraise(token);
        enablePublic();
        deal(address(token), TESTER, 7 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 1 * 10**17; // Tier is >= 1 && <= 10, depositing 0.1
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("UNDER_MIN_PUBLIC_ALLOCATION"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooBigPublic() public {
        createFundraise(token);
        enablePublic();
        deal(address(token), TESTER, 7 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 11 * 10**18; // Tier is >= 1 && <= 10
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("OVER_MAX_PUBLIC_ALLOCATION"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_overAllocation() public {
        createFundraise(token);
        enablePublic();
        deal(address(token), TESTER, 20 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 8 * 10**18; // Tier is >= 1 && <= 10
        token.approve(address(vault), depositAmount);
        vault.deposit(0, depositAmount);

        token.approve(address(vault), depositAmount);
        vm.expectRevert(bytes("OVER_MAX_PUBLIC_ALLOCATION"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);
        vault.deposit(0, depositAmount);

        (,,,,,,, bool fundraiseWhitelistEnabled,, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);
        address[] memory contributors = vault.getFundraiseContributors(0);

        assertFalse(fundraiseWhitelistEnabled);
        assertEq(currentAmountRaised, depositAmount);
        assertFalse(completed);
        assertEq(token.balanceOf(TESTER), (1000 * 10**18) - depositAmount);
        assertEq(vault.getFundraiseContribution(0, TESTER), depositAmount);
        assertEq(contributors.length, 1);
        assertEq(contributors[0], TESTER);

        vm.stopPrank();
    }

    function test_depositMultipleTxs() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        uint256 depositAmount2 = 5 * 10**18;
        uint256 depositAmount3 = 10 * 10**18;
        uint256 totalAmount = depositAmount + depositAmount2 + depositAmount3;

        // Deposit 1 => 50
        token.approve(address(vault), depositAmount);
        vault.deposit(0, depositAmount);

        // Deposit 2 = 5 => 55
        token.approve(address(vault), depositAmount2);
        vault.deposit(0, depositAmount2);

        // Deposit 3 = 10 => 65
        token.approve(address(vault), depositAmount3);
        vault.deposit(0, depositAmount3);

        // Deposit 4 = 10 => 75 > 69, Revert
        token.approve(address(vault), depositAmount3);
        vm.expectRevert(bytes("OVER_MAX_ALLOCATION"));
        vault.deposit(0, depositAmount3);

        (,,,,,,, bool fundraiseWhitelistEnabled,, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);

        assertFalse(fundraiseWhitelistEnabled);
        assertEq(currentAmountRaised, totalAmount);
        assertFalse(completed);
        assertEq(token.balanceOf(TESTER), (1000 * 10**18) - totalAmount);
        assertEq(vault.getFundraiseContribution(0, TESTER), totalAmount);

        vm.stopPrank();
    }

    function test_deposit_publicAllocation() public {
        createFundraise(token);

        // Enable public
        enablePublic();

        deal(address(token), TESTER, 7 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 5 * 10**18; // Public tier is >= 1 && <= 10
        token.approve(address(vault), depositAmount);
        vault.deposit(0, depositAmount);

        (,,,,,,, bool fundraiseWhitelistEnabled,, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);

        assertFalse(fundraiseWhitelistEnabled);
        assertEq(currentAmountRaised, depositAmount);
        assertFalse(completed);
        assertEq(token.balanceOf(TESTER), (7 * 10**18) - depositAmount);
        assertEq(vault.getFundraiseContribution(0, TESTER), depositAmount);

        vm.stopPrank();
    }

    function test_deposit_event() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectEmit();
        emit Deposit(0, TESTER, depositAmount);
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }
}
