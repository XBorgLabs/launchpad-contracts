// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TokenDistributionDeployment is Base {
    function test_initialize_wrongManagerAddress() public {
        tokenDistributionImplementation = new TokenDistribution();
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenDistributionImplementation), "");
        tokenDistribution = TokenDistribution(payable(proxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        tokenDistribution.initialize(address(0), OWNER);
    }

    function test_initialize_wrongOwnerAddress() public {
        tokenDistributionImplementation = new TokenDistribution();
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenDistributionImplementation), "");
        tokenDistribution = TokenDistribution(payable(proxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        tokenDistribution.initialize(MANAGER, address(0));
    }

    function test_initialize() public {
        tokenDistributionImplementation = new TokenDistribution();
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenDistributionImplementation), "");
        tokenDistribution = TokenDistribution(payable(proxy));
        tokenDistribution.initialize(TESTER, DEPLOYER);
        assertTrue(tokenDistribution.hasRole(keccak256("MANAGER_ROLE"), TESTER));
        assertTrue(tokenDistribution.hasRole(0x00, DEPLOYER)); // DEFAULT_ADMIN_ROLE
    }
}
