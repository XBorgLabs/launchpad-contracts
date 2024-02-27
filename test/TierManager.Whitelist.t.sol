// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TierManager} from "../src/TierManager.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TierManagerWhitelist is Base {
    uint256 public constant TEST_WHITELIST_TIER = 42;

    address[] public whitelistAddresses;
    uint256[] public tierIndexes;

    address[] public batchWhitelistAddresses;
    uint256[] public batchTierIndexes;

    constructor() {
        whitelistAddresses = new address[](1);
        whitelistAddresses[0] = TESTER;

        tierIndexes = new uint256[](1);
        tierIndexes[0] = TEST_WHITELIST_TIER;

        batchWhitelistAddresses = new address[](3);
        batchWhitelistAddresses[0] = TESTER;
        batchWhitelistAddresses[1] = DEPLOYER;
        batchWhitelistAddresses[2] = SIGNER;

        batchTierIndexes = new uint256[](3);
        batchTierIndexes[0] = TEST_WHITELIST_TIER;
        batchTierIndexes[1] = 58;
        batchTierIndexes[2] = 1;
    }

    function test_setWhitelist_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tierManager.setWhitelist(whitelistAddresses, tierIndexes);

        vm.stopPrank();
    }

    function test_setWhitelist_wrongParams() public {
        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("WRONG_PARAMS"));
        tierManager.setWhitelist(whitelistAddresses, batchTierIndexes);

        vm.stopPrank();
    }

    function test_setWhitelist() public {
        assertFalse(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));

        vm.startPrank(MANAGER);
        tierManager.setWhitelist(whitelistAddresses, tierIndexes);
        vm.stopPrank();

        assertTrue(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
    }

    function test_setWhitelist_batch() public {
        assertFalse(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
        assertFalse(tierManager.whitelist(DEPLOYER, 58));
        assertFalse(tierManager.whitelist(SIGNER, 1));

        vm.startPrank(MANAGER);
        tierManager.setWhitelist(batchWhitelistAddresses, batchTierIndexes);
        vm.stopPrank();

        assertTrue(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
        assertTrue(tierManager.whitelist(DEPLOYER, 58));
        assertTrue(tierManager.whitelist(SIGNER, 1));
    }

    function test_removeWhitelist_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tierManager.removeWhitelist(whitelistAddresses, tierIndexes);

        vm.stopPrank();
    }

    function test_removeWhitelist_wrongParams() public {
        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("WRONG_PARAMS"));
        tierManager.removeWhitelist(batchWhitelistAddresses, tierIndexes);

        vm.stopPrank();
    }

    function test_removeWhitelist() public {
        // Pre-conditions
        vm.startPrank(MANAGER);
        tierManager.setWhitelist(whitelistAddresses, tierIndexes);
        vm.stopPrank();

        assertTrue(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));

        vm.startPrank(MANAGER);
        tierManager.removeWhitelist(whitelistAddresses, tierIndexes);
        vm.stopPrank();

        assertFalse(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
    }

    function test_removeWhitelist_batch() public {
        // Pre-conditions
        vm.startPrank(MANAGER);
        tierManager.setWhitelist(batchWhitelistAddresses, batchTierIndexes);
        vm.stopPrank();

        assertTrue(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
        assertTrue(tierManager.whitelist(DEPLOYER, 58));
        assertTrue(tierManager.whitelist(SIGNER, 1));

        vm.startPrank(MANAGER);
        tierManager.removeWhitelist(batchWhitelistAddresses, batchTierIndexes);
        vm.stopPrank();

        assertFalse(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
        assertFalse(tierManager.whitelist(DEPLOYER, 58));
        assertFalse(tierManager.whitelist(SIGNER, 1));
    }
}
