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

    function test_setWhitelist_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tierManager.setWhitelist(TESTER, TEST_WHITELIST_TIER);

        vm.stopPrank();
    }

    function test_setWhitelist() public {
        assertFalse(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));

        vm.startPrank(MANAGER);
        tierManager.setWhitelist(TESTER, TEST_WHITELIST_TIER);
        vm.stopPrank();

        assertTrue(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
    }

    function test_removeWhitelist_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tierManager.removeWhitelist(TESTER, TEST_WHITELIST_TIER);

        vm.stopPrank();
    }

    function test_removeWhitelist() public {
        // Pre-conditions
        vm.startPrank(MANAGER);
        tierManager.setWhitelist(TESTER, TEST_WHITELIST_TIER);
        vm.stopPrank();

        assertTrue(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));

        vm.startPrank(MANAGER);
        tierManager.removeWhitelist(TESTER, TEST_WHITELIST_TIER);
        vm.stopPrank();

        assertFalse(tierManager.whitelist(TESTER, TEST_WHITELIST_TIER));
    }
}
