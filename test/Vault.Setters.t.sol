// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VaultUpgraded} from "./mock/VaultUpgraded.sol";

contract VaultSetters is Base {

    event SetTierManager(address indexed tierManager);
    event SetWhitelistSigner(address indexed whitelistSigner);

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

    function test_setBeneficiary_onlyOwner() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setBeneficiary(0, DEPLOYER);

        vm.stopPrank();
    }

    function test_setBeneficiary_addressZero() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.setBeneficiary(0, address(0));

        vm.stopPrank();
    }

    function test_setBeneficiary_fundsAlreadyWithdrawn() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        // End and complete
        (,,,,,, uint256 endTime,,,,) = vault.fundraises(0);
        vm.warp(endTime + 1);
        vault.completeFundraise(0);

        vm.expectRevert(bytes("FUNDS_ALREADY_WITHDRAWN"));
        vault.setBeneficiary(0, DEPLOYER);

        vm.stopPrank();
    }

    function test_setBeneficiary() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        (,, address startBeneficiary,,,,,,,,) = vault.fundraises(0);
        assertEq(startBeneficiary, BENEFICIARY);

        vault.setBeneficiary(0, DEPLOYER);

        (,, address endBeneficiary,,,,,,,,) = vault.fundraises(0);
        assertEq(endBeneficiary, DEPLOYER);

        vm.stopPrank();
    }

    function test_setCap_onlyOwner() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setCap(0, 10 * 10**18, 20 * 10**18);

        vm.stopPrank();
    }

    function test_setCap_wrongCaps() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("WRONG_CAPS"));
        vault.setCap(0, 50 * 10**18, 20 * 10**18);

        vm.stopPrank();
    }

    function test_setCap_capTooSmall() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("CAP_TOO_SMALL"));
        vault.setCap(0, 10 * 10**18, 20 * 10**18);

        vm.stopPrank();
    }

    function test_setCap() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        (,,, uint256 startSoftCap, uint256 startHardCap,,,,,,) = vault.fundraises(0);
        assertEq(startSoftCap, 100 * 10**18);
        assertEq(startHardCap, 1000 * 10**18);

        vault.setCap(0, 1 * 10**18, 20000 * 10**18);

        (,,, uint256 endSoftCap, uint256 endHardCap,,,,,,) = vault.fundraises(0);
        assertEq(endSoftCap, 1 * 10**18);
        assertEq(endHardCap, 20000 * 10**18);

        vm.stopPrank();
    }

    function test_setName_onlyOwner() public {
        createAndDepositFundraise(100 * 10**18, false);

        string memory finalName = "XBorg";

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setName(0, finalName);

        vm.stopPrank();
    }

    function test_setName() public {
        createAndDepositFundraise(100 * 10**18, false);

        string memory originalName = "Fundraise";
        string memory updatedName = "XBorg";

        vm.startPrank(MANAGER);

        (string memory initialName,,,,,,,,,,) = vault.fundraises(0);
        assertEq(initialName, originalName);

        vault.setName(0, updatedName);

        (string memory finalName,,,,,,,,,,) = vault.fundraises(0);
        assertEq(finalName, updatedName);

        vm.stopPrank();
    }

    function test_setPublicFundraise_onlyOwner() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setPublicFundraise(0, true, 10 * 10**18, 20 * 10**18);

        vm.stopPrank();
    }

    function test_setPublicFundraise_wrongCaps() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("WRONG_ALLOCATION"));
        vault.setPublicFundraise(0, true, 50 * 10**18, 20 * 10**18);

        vm.stopPrank();
    }

    function test_setPublicFundraise() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        (,,,,,,,, Vault.PublicFundraise memory startPublicFundraise,,) = vault.fundraises(0);
        assertFalse(startPublicFundraise.enabled);
        assertEq(startPublicFundraise.minAllocation, 0);
        assertEq(startPublicFundraise.maxAllocation, 0);

        vault.setPublicFundraise(0, true, 10 * 10**18, 20 * 10**18);

        (,,,,,,,, Vault.PublicFundraise memory endPublicFundraise,,) = vault.fundraises(0);
        assertTrue(endPublicFundraise.enabled);
        assertEq(endPublicFundraise.minAllocation, 10 * 10**18);
        assertEq(endPublicFundraise.maxAllocation, 20 * 10**18);

        vm.stopPrank();
    }

    function test_setTime_onlyOwner() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setTime(0, 10, 200);

        vm.stopPrank();
    }

    function test_setTime_wrongEndTime() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);
        vm.warp(500);

        vm.expectRevert(bytes("WRONG_TIME"));
        vault.setTime(0, 10, 200);

        vm.stopPrank();
    }

    function test_setTime_wrongStartEndTime() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("WRONG_TIME"));
        vault.setTime(0, 500, 200);

        vm.stopPrank();
    }

    function test_setTime() public {
        createAndDepositFundraise(100 * 10**18, false);

        vm.startPrank(MANAGER);

        (,,,,, uint256 startStartTime, uint256 startEndTime,,,,) = vault.fundraises(0);
        assertEq(startStartTime, 61);
        assertEq(startEndTime, 661);

        vault.setTime(0, 10, 200);

        (,,,,, uint256 endStartTime, uint256 endEndTime,,,,) = vault.fundraises(0);
        assertEq(endStartTime, 10);
        assertEq(endEndTime, 200);

        vm.stopPrank();
    }

    function test_setWhitelist_onlyOwner() public {
        createFundraise(token);

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setWhitelist(0, false);

        vm.stopPrank();
    }

    function test_setWhitelist_addressZero() public {
        createFundraise(token);

        vm.startPrank(MANAGER);

        assertTrue(vault.getFundraiseWhitelisted(0));

        vault.setWhitelist(0, false);

        assertFalse(vault.getFundraiseWhitelisted(0));

        vm.stopPrank();
    }

    function test_setWhitelistSigner_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setWhitelistSigner(DEPLOYER);

        vm.stopPrank();
    }

    function test_setWhitelistSigner_addressZero() public {
        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.setWhitelistSigner(address(0));

        vm.stopPrank();
    }

    function test_setWhitelistSigner() public {
        vm.startPrank(MANAGER);

        assertEq(vault.whitelistSigner(), SIGNER);

        vault.setWhitelistSigner(FAKE_SIGNER);

        assertEq(vault.whitelistSigner(), FAKE_SIGNER);

        vm.stopPrank();
    }

    function test_setTierManager_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.setTierManager(DEPLOYER);

        vm.stopPrank();
    }

    function test_setTierManager_addressZero() public {
        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.setTierManager(address(0));

        vm.stopPrank();
    }

    function test_setTierManager() public {
        vm.startPrank(MANAGER);

        assertEq(vault.tierManager(), address(tierManager));

        vault.setTierManager(FAKE_SIGNER);

        assertEq(vault.tierManager(), FAKE_SIGNER);

        vm.stopPrank();
    }
}
