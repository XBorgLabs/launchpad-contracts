// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TierManager} from "../src/TierManager.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TierManagerDeployment is Base {
    function test_initialize_wrongManagerAddress() public {
        tierManagerImplementation = new TierManager();
        ERC1967Proxy tierManagerProxy = new ERC1967Proxy(address(tierManagerImplementation), "");
        tierManager = TierManager(address(tierManagerProxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        tierManager.initialize(address(0), OWNER);
    }

    function test_initialize_wrongOwnerAddress() public {
        tierManagerImplementation = new TierManager();
        ERC1967Proxy tierManagerProxy = new ERC1967Proxy(address(tierManagerImplementation), "");
        tierManager = TierManager(address(tierManagerProxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        tierManager.initialize(MANAGER, address(0));
    }

    function test_initialize() public {
        tierManagerImplementation = new TierManager();
        ERC1967Proxy tierManagerProxy = new ERC1967Proxy(address(tierManagerImplementation), "");
        tierManager = TierManager(address(tierManagerProxy));
        tierManager.initialize(TESTER, DEPLOYER);
        assertTrue(tierManager.hasRole(keccak256("MANAGER_ROLE"), TESTER));
        assertTrue(tierManager.hasRole(0x00, DEPLOYER)); // DEFAULT_ADMIN_ROLE
    }
}
