// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Token} from "./mock/Token.sol";
import {TokenDistributionUpgraded} from "./mock/TokenDistributionUpgraded.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract TokenDistributionUpgrade is Base {
    function test_upgrade_onlyOwner() public {
        TokenDistributionUpgraded tokenDistributionUpgraded = new TokenDistributionUpgraded();

        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), 0x00);
        vm.expectRevert(error);
        tokenDistribution.upgradeToAndCall(address(tokenDistributionUpgraded), "0x");

        vm.stopPrank();
    }

    function test_upgrade() public {
        TokenDistributionUpgraded tokenDistributionUpgraded = new TokenDistributionUpgraded();

        vm.startPrank(OWNER);

        tokenDistribution.upgradeToAndCall(address(tokenDistributionUpgraded), abi.encodeWithSignature("initializeV2(uint256)", 2));
        assertEq(TokenDistributionUpgraded(address(tokenDistribution)).getVersion(), 2);

        vm.stopPrank();
    }
}
