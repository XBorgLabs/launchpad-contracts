// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract VaultWhitelistDeposit is Base {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    event Deposit(uint256 indexed index, address indexed sender, uint256 indexed amount);

    function createSignature(uint256 _index, address _sender) internal returns (bytes memory) {
        vm.startPrank(SIGNER);

        bytes32 data = keccak256(abi.encodePacked(_index, _sender)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, data);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        return signature;
    }

    function createFakeSignature(uint256 _index, address _sender) internal returns (bytes memory) {
        vm.startPrank(FAKE_SIGNER);

        bytes32 data = keccak256(abi.encodePacked(_index, _sender)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(FAKE_SIGNER_PK, data);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        return signature;
    }

    function test_whitelistDeposit_wrongSignature() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createFakeSignature(0, TESTER);

        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);
        vm.expectRevert(bytes("WRONG_SIGNATURE"));
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }

    function test_whitelistDeposit_notOpenEarly() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createSignature(0, TESTER);

        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("NOT_OPEN"));
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }

    function test_whitelistDeposit_notOpenLate() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        // Move forward in time
        (,,,,,, uint256 endTime,,,,) = vault.fundraises(0);
        vm.warp(endTime + 1);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createSignature(0, TESTER);

        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("NOT_OPEN"));
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }

    function test_whitelistDeposit_hardCap() public {
        createFundraise(token);
        deal(address(token), TESTER, 1001 * 10**18);

        uint256 depositAmount = 1001 * 10**18; // Hard cap is 1000
        bytes memory signature = createSignature(0, TESTER);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Deposit
        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("HARD_CAP"));
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }

    function test_whitelistDeposit_amountTooSmall() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        uint256 depositAmount = 10 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createSignature(0, TESTER);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("AMOUNT_TOO_SMALL"));
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }

    function test_whitelistDeposit_amountTooBig() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        uint256 depositAmount = 70 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createSignature(0, TESTER);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Remove whitelist
        vm.startPrank(MANAGER);
        vault.setWhitelist(0, false);
        vm.stopPrank();

        // Deposit
        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);

        vm.expectRevert(bytes("AMOUNT_TOO_BIG"));
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }

    function test_whitelistDeposit() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createSignature(0, TESTER);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Deposit
        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);
        vault.whitelistDeposit(0, depositAmount, signature);

        (,,,,,,, bool fundraiseWhitelistEnabled,, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);

        assertTrue(fundraiseWhitelistEnabled);
        assertEq(currentAmountRaised, depositAmount);
        assertFalse(completed);
        assertEq(token.balanceOf(TESTER), (1000 * 10**18) - depositAmount);
        assertEq(vault.getFundraiseContribution(0, TESTER), depositAmount);

        vm.stopPrank();
    }

    function test_whitelistDeposit_event() public {
        createFundraise(token);
        deal(address(token), TESTER, 1000 * 10**18);

        uint256 depositAmount = 50 * 10**18; // Tier is >= 42 && <= 69
        bytes memory signature = createSignature(0, TESTER);

        // Move forward in time
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(0);
        vm.warp(startTime);

        // Deposit
        vm.startPrank(TESTER);

        token.approve(address(vault), depositAmount);

        vm.expectEmit();
        emit Deposit(0, TESTER, depositAmount);
        vault.whitelistDeposit(0, depositAmount, signature);

        vm.stopPrank();
    }
}
