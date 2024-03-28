// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TierManager} from "../src/TierManager.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TierManagerUpgraded} from "./mock/TierManagerUpgraded.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract TierManagerUpgrade is Base {
    function test_upgrade_onlyOwner() public {
        TierManagerUpgraded tierManagerUpgraded = new TierManagerUpgraded();

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), 0x00);
        vm.expectRevert(error);
        tierManager.upgradeToAndCall(address(tierManagerUpgraded), "0x");

        vm.stopPrank();
    }

    function test_upgrade() public {
        TierManagerUpgraded tierManagerUpgraded = new TierManagerUpgraded();

        vm.startPrank(OWNER);

        tierManager.upgradeToAndCall(address(tierManagerUpgraded), abi.encodeWithSignature("initializeV2(uint256)", 2));
        assertEq(TierManagerUpgraded(address(tierManager)).getVersion(), 2);

        vm.stopPrank();
    }
}
