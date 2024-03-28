// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {VaultUpgraded} from "./mock/VaultUpgraded.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract VaultUpgrade is Base {
    function test_upgrade_onlyOwner() public {
        VaultUpgraded vaultUpgraded = new VaultUpgraded();

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), 0x00);
        vm.expectRevert(error);
        vault.upgradeToAndCall(address(vaultUpgraded), "0x");

        vm.stopPrank();
    }

    function test_upgrade() public {
        VaultUpgraded vaultUpgraded = new VaultUpgraded();
        vm.startPrank(OWNER);

        vault.upgradeToAndCall(address(vaultUpgraded), abi.encodeWithSignature("initializeV2(uint256)", 2));
        assertEq(VaultUpgraded(address(vault)).getVersion(), 2);

        vm.stopPrank();
    }
}
