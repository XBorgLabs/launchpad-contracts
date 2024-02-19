// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {TierManager} from "../src/TierManager.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

contract TierManagerDeployer is Script {
    TierManager public tierManager;
    TierManager public tierManagerImplementation;

    address public manager;
    address public owner;

    constructor() public {
        // Constructor args
        manager = address(0);
        owner = address(0);
    }

    function run() external {
        vm.startBroadcast();
        tierManagerImplementation = new TierManager();
        ERC1967Proxy tierManagerProxy = new ERC1967Proxy(address(tierManagerImplementation), "");
        tierManager = TierManager(address(tierManagerProxy));
        tierManager.initialize(manager, owner);

        console.log("TierManager Deployment:");
        console.log("Proxy:", address(tierManager));
        console.log("Implementation:", address(tierManagerImplementation));
        vm.stopBroadcast();
    }
}