// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TokenDistributionWithdraw is Base {
    event Withdraw(address indexed token, uint256 indexed amount);

    function test_withdraw_onlyOwner() public {
        // Pre-conditions
        uint256 initialAmount = 1000 * 10**18;
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        uint256 deployerInitialBalance = token.balanceOf(DEPLOYER);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), 0);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(DEPLOYER), deployerInitialBalance);

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tokenDistribution.withdraw(address(token), initialAmount);

        uint256 deployerFinalBalance = token.balanceOf(DEPLOYER);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        assertEq(deployerFinalBalance - deployerInitialBalance, 0);

        vm.stopPrank();
    }

    function test_withdraw_notEnoughTokens() public {
        // Pre-conditions
        uint256 initialAmount = 1000 * 10**18;
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        uint256 ownerInitialBalance = token.balanceOf(MANAGER);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), 0);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(MANAGER), ownerInitialBalance);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS"));
        tokenDistribution.withdraw(address(token), initialAmount + 1);

        vm.stopPrank();
    }

    function test_withdraw() public {
        // Pre-conditions
        uint256 initialAmount = 1000 * 10**18;
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        uint256 ownerInitialBalance = token.balanceOf(MANAGER);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), 0);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(MANAGER), ownerInitialBalance);

        vm.startPrank(MANAGER);

        tokenDistribution.withdraw(address(token), initialAmount);
        uint256 ownerFinalBalance = token.balanceOf(MANAGER);

        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        assertEq(ownerFinalBalance - ownerInitialBalance, initialAmount);

        vm.stopPrank();
    }

    function test_withdraw_notEnoughTokensWithVestingSchedules() public {
        // Create a dummy vesting schedule
        createVestingSchedule(token);

        // Pre-conditions
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        uint256 ownerInitialBalance = token.balanceOf(MANAGER);

        // Fund extra tokens to TokenDistribution
        uint256 initialAmount = 1000 * 10**18;
        uint256 extraAmount = 100 * 10**18;
        deal(address(token), address(tokenDistribution), initialAmount + extraAmount); // 1100 (1000 + 100) tokens in total

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount + extraAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), extraAmount);
        assertEq(token.balanceOf(MANAGER), ownerInitialBalance);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS"));
        tokenDistribution.withdraw(address(token), extraAmount + 1);

        vm.stopPrank();
    }

    function test_withdraw_notEnoughTokens2WithVestingSchedules() public {
        // Create a dummy vesting schedule
        createVestingSchedule(token);

        // Pre-conditions
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        uint256 ownerInitialBalance = token.balanceOf(MANAGER);

        // Fund extra tokens to TokenDistribution
        uint256 initialAmount = 1000 * 10**18;
        uint256 extraAmount = 100 * 10**18;
        deal(address(token), address(tokenDistribution), initialAmount + extraAmount); // 1100 (1000 + 100) tokens in total

        // Fund unused tokens to TokenDistribution
        uint256 token2Amount = 50 * 10**18;
        deal(address(token2), address(tokenDistribution), token2Amount);

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount + extraAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), extraAmount);
        assertEq(token.balanceOf(MANAGER), ownerInitialBalance);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS"));
        tokenDistribution.withdraw(address(token), extraAmount + 1); // Withdrawing 101 T1 when only 100 T1 is available

        vm.expectRevert(bytes("NOT_ENOUGH_TOKENS"));
        tokenDistribution.withdraw(address(token2), extraAmount); // Withdrawing 101 T2 when only 50 T2 is available

        vm.stopPrank();
    }

    function test_withdraw_withVestingSchedules() public {
        // Create a dummy vesting schedule
        createVestingSchedule(token);

        // Pre-conditions
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        uint256 ownerInitialBalance = token.balanceOf(MANAGER);

        // Fund extra tokens to TokenDistribution
        uint256 initialAmount = 1000 * 10**18;
        uint256 extraAmount = 100 * 10**18;
        deal(address(token), address(tokenDistribution), initialAmount + extraAmount); // 1100 (1000 + 100) tokens in total

        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount + extraAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), extraAmount);
        assertEq(token.balanceOf(MANAGER), ownerInitialBalance);

        vm.startPrank(MANAGER);

        tokenDistribution.withdraw(address(token), extraAmount);
        uint256 ownerFinalBalance = token.balanceOf(MANAGER);

        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        assertEq(ownerFinalBalance - ownerInitialBalance, extraAmount);

        vm.stopPrank();
    }

    function test_withdraw_withVestingSchedulesMultipleTokens() public {
        // Create a dummy vesting schedule
        createVestingSchedule(token);

        // Pre-conditions
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        uint256 ownerInitialBalanceToken1 = token.balanceOf(MANAGER);
        uint256 ownerInitialBalanceToken2 = token2.balanceOf(MANAGER);

        // Fund extra tokens to TokenDistribution
        uint256 initialAmount = 1000 * 10**18;
        uint256 extraAmount = 100 * 10**18;
        deal(address(token), address(tokenDistribution), initialAmount + extraAmount); // 1100 (1000 + 100) tokens in total

        // Fund unused tokens to TokenDistribution
        uint256 token2Amount = 500 * 10**18;
        deal(address(token2), address(tokenDistribution), token2Amount);

        // Token 1
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token)), initialAmount);
        assertEq(token.balanceOf(address(tokenDistribution)), initialAmount + extraAmount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), extraAmount);
        assertEq(token.balanceOf(MANAGER), ownerInitialBalanceToken1);

        // Token 2
        assertEq(tokenDistribution.vestingSchedulesTotalAmount(address(token2)), 0);
        assertEq(token2.balanceOf(address(tokenDistribution)), token2Amount);
        assertEq(tokenDistribution.getWithdrawableAmount(address(token2)), token2Amount);
        assertEq(token2.balanceOf(MANAGER), ownerInitialBalanceToken2);

        vm.startPrank(MANAGER);

        tokenDistribution.withdraw(address(token), extraAmount);
        tokenDistribution.withdraw(address(token2), token2Amount);
        uint256 ownerFinalBalanceToken1 = token.balanceOf(MANAGER);
        uint256 ownerFinalBalanceToken2 = token2.balanceOf(MANAGER);

        // Token 1
        assertEq(tokenDistribution.getWithdrawableAmount(address(token)), 0);
        assertEq(ownerFinalBalanceToken1 - ownerInitialBalanceToken1, extraAmount);

        // Token 2
        assertEq(tokenDistribution.getWithdrawableAmount(address(token2)), 0);
        assertEq(ownerFinalBalanceToken2 - ownerInitialBalanceToken2, token2Amount);

        vm.stopPrank();
    }

    function test_withdraw_event() public {
        // Create a dummy vesting schedule
        createVestingSchedule(token);

        // Fund extra tokens to TokenDistribution
        uint256 initialAmount = 1000 * 10**18;
        uint256 extraAmount = 100 * 10**18;
        deal(address(token), address(tokenDistribution), initialAmount + extraAmount); // 1100 (1000 + 100) tokens in total

        vm.startPrank(MANAGER);

        vm.expectEmit();
        emit Withdraw(address(token), extraAmount);

        tokenDistribution.withdraw(address(token), extraAmount);

        vm.stopPrank();
    }
}
