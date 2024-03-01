// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultRefundDeposit is Base {
    event Refund(uint256 indexed index, address indexed sender, uint256 indexed amount);

    function createAndDepositFundraise(uint256 _depositAmount, bool _ended) internal {
        createFundraise(token);
        deal(address(token), TESTER, 10000 * 10**18);

        // Move forward in time
        (,,,,, uint256 startTime, uint256 endTime,,,,) = vault.fundraises(0);
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

    function test_refundDeposit_onlyOwner() public {
        uint256 depositAmount = 100 * 10**18;
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(TESTER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(TESTER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.refundDeposit(0, TESTER);

        vm.stopPrank();
    }

    function test_refundDeposit_notEnded() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, false);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("NOT_ENDED"));
        vault.refundDeposit(0, TESTER);

        vm.stopPrank();
    }

    function test_refundDeposit_fundsAlreadyWithdrawn() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        vm.startPrank(MANAGER);

        // Complete
        vault.completeFundraise(0);

        // Can't do it again
        vm.expectRevert(bytes("FUNDS_ALREADY_WITHDRAWN"));
        vault.refundDeposit(0, TESTER);

        vm.stopPrank();
    }

    function test_refundDeposit_zeroAmount() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("ZERO_AMOUNT"));
        vault.refundDeposit(0, DEPLOYER);

        vm.stopPrank();
    }

    function test_refundDeposit() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        (,,,,,,,,, uint256 amountRaisedStart,) = vault.fundraises(0);
        uint256 tokenBalanceStart = token.balanceOf(TESTER);

        vm.startPrank(MANAGER);

        // Refund
        vault.refundDeposit(0, TESTER);

        (,,,,,,,,, uint256 amountRaisedEnd,) = vault.fundraises(0);
        uint256 tokenBalanceEnd = token.balanceOf(TESTER);

        assertEq(tokenBalanceEnd - tokenBalanceStart, depositAmount);
        assertEq(token.balanceOf(OWNER), 0);
        assertEq(amountRaisedStart - amountRaisedEnd, depositAmount);

        vm.stopPrank();
    }

    function test_refundDeposit_softCapNotMet() public {
        uint256 depositAmount = 50 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true);

        (,,,,,, uint256 endTime,,, uint256 amountRaisedStart,) = vault.fundraises(0);
        uint256 tokenBalanceStart = token.balanceOf(TESTER);

        vm.startPrank(MANAGER);
        vm.warp(endTime + 1);

        // Refund
        vault.refundDeposit(0, TESTER);

        (,,,,,,,,, uint256 amountRaisedEnd,) = vault.fundraises(0);
        uint256 tokenBalanceEnd = token.balanceOf(TESTER);

        assertEq(tokenBalanceEnd - tokenBalanceStart, depositAmount);
        assertEq(token.balanceOf(OWNER), 0);
        assertEq(amountRaisedStart - amountRaisedEnd, depositAmount);

        vm.stopPrank();
    }

    function test_refundDeposit_event() public {
        uint256 depositAmount = 150 * 10**18; // Soft cap is at 100
        createAndDepositFundraise(depositAmount, true); // Ended

        vm.startPrank(MANAGER);

        // Refund
        vm.expectEmit();
        emit Refund(0, TESTER, depositAmount);

        vault.refundDeposit(0, TESTER);

        vm.stopPrank();
    }
}
