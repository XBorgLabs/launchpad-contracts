// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {TokenDistribution} from "../src/TokenDistribution.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

contract TokenDistributionDeployer is Script {
    TokenDistribution public tokenDistribution;
    TokenDistribution public tokenDistributionImplementation;

    address public manager;
    address public owner;

    constructor() {
        // Constructor args
        manager = address(0);
        owner = address(0);
    }

    function run() external {
        vm.startBroadcast();

        tokenDistributionImplementation = new TokenDistribution();
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenDistributionImplementation), "");
        tokenDistribution = TokenDistribution(address(proxy));
        tokenDistribution.initialize(manager, owner);

        console.log("TokenDistribution Deployment:");
        console.log("Proxy:", address(tokenDistribution));
        console.log("Implementation:", address(tokenDistributionImplementation));
        vm.stopBroadcast();
    }
}