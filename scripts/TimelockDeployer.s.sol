// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {TimelockController} from "openzeppelin-contracts/contracts/governance/TimelockController.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

contract TimelockDeployer is Script {
    TimelockController timelock;

    uint256 public minDelay;
    address public proposer;
    address public executor;
    address public admin;

    constructor() public {
        // Constructor args
        minDelay = 60;
        proposer = address(0x4e12B392781bC17263A56447adC57d7f5357F565);
        executor = address(0x4e12B392781bC17263A56447adC57d7f5357F565);
        admin = address(0x4e12B392781bC17263A56447adC57d7f5357F565);
    }

    function run() external {
        vm.startBroadcast();

        address[] memory proposers = new address[](1);
        proposers[0] = proposer;

        address[] memory executors = new address[](1);
        executors[0] = executor;

        timelock = new TimelockController(minDelay, proposers, executors, admin);

        console.log("Timelock Deployment:");
        console.log("Address:", address(timelock));
        vm.stopBroadcast();
    }
}