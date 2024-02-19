// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultWithdraw is Base {
    event Withdrawal(uint256 indexed index, address indexed sender, uint256 indexed amount);

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

    function test_withdraw_aboveSoftCap() public {
        uint256 depositAmount = 100 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(TESTER);

        vm.expectRevert(bytes("ABOVE_SOFT_CAP"));
        vault.withdraw(0);

        vm.stopPrank();
    }

    function test_withdraw_notEnded() public {
        uint256 depositAmount = 50 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(TESTER);

        vm.expectRevert(bytes("NOT_ENDED"));
        vault.withdraw(0);

        vm.stopPrank();
    }

    function test_withdraw_zeroAmount() public {
        uint256 depositAmount = 50 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        vm.startPrank(BENEFICIARY); // BENEFICIARY didn't deposit, TESTER did

        vm.expectRevert(bytes("ZERO_AMOUNT"));
        vault.withdraw(0);

        vm.stopPrank();
    }

    function test_withdraw() public {
        uint256 depositAmount = 50 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);
        uint256 initialBalance = token.balanceOf(TESTER);
        (,,,,,,,, uint256 amountRaisedStart,) = vault.fundraises(0);

        vm.startPrank(TESTER);

        vault.withdraw(0);

        (,,,,,,,, uint256 amountRaisedEnd,) = vault.fundraises(0);
        uint256 finalBalance = token.balanceOf(TESTER);
        assertEq(finalBalance - initialBalance, depositAmount);
        assertEq(amountRaisedStart - amountRaisedEnd, depositAmount);

        vm.stopPrank();
    }

    function test_withdraw_double() public {
        uint256 depositAmount = 50 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);
        uint256 initialBalance = token.balanceOf(TESTER);

        vm.startPrank(TESTER);

        vault.withdraw(0);

        uint256 finalBalance = token.balanceOf(TESTER);
        assertEq(finalBalance - initialBalance, depositAmount);

        vm.expectRevert(bytes("ZERO_AMOUNT"));
        vault.withdraw(0);

        vm.stopPrank();
    }

    function test_withdraw_event() public {
        uint256 depositAmount = 50 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        vm.startPrank(TESTER);

        vm.expectEmit();
        emit Withdrawal(0, TESTER, depositAmount);
        vault.withdraw(0);

        vm.stopPrank();
    }
}
