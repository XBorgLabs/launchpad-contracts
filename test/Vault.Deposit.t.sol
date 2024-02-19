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
        (,,,,, uint256 endTime,,,,) = vault.fundraises(0);
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
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
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
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
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
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 10 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("AMOUNT_TOO_SMALL"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooBig() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 70 * 10**18; // Tier is >= 42 && <= 69
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("AMOUNT_TOO_BIG"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooSmallPublic() public {
        createFundraise(token);
        enablePublic();
        deal(address(token), TESTER, 7 * 10**18);

        // Move forward in time
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 1 * 10**17; // Tier is >= 1 && <= 10, depositing 0.1
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("AMOUNT_TOO_SMALL_PUBLIC"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit_amountTooBigPublic() public {
        createFundraise(token);
        enablePublic();
        deal(address(token), TESTER, 7 * 10**18);

        // Move forward in time
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        uint256 depositAmount = 11 * 10**18; // Tier is >= 1 && <= 10
        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("AMOUNT_TOO_BIG_PUBLIC"));
        vault.deposit(0, depositAmount);

        vm.stopPrank();
    }

    function test_deposit() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
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

        (,,,,,, bool fundraiseWhitelistEnabled,, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);

        assertFalse(fundraiseWhitelistEnabled);
        assertEq(currentAmountRaised, depositAmount);
        assertFalse(completed);
        assertEq(token.balanceOf(TESTER), (1000 * 10**18) - depositAmount);
        assertEq(vault.getFundraiseContribution(0, TESTER), depositAmount);

        vm.stopPrank();
    }

    function test_deposit_publicAllocation() public {
        createFundraise(token);

        // Enable public
        enablePublic();

        deal(address(token), TESTER, 7 * 10**18);

        // Move forward in time
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
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

        (,,,,,, bool fundraiseWhitelistEnabled,, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);

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
        (,,,, uint256 startTime,,,,,) = vault.fundraises(0);
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
