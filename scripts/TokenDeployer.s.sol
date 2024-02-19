// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Token} from "../test/mock/Token.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

contract TokenDeployer is Script {
    Token public token;

    address public beneficiary;

    constructor() {
        // Constructor args
        beneficiary = address(0);
    }

    function run() external {
        vm.startBroadcast();
        token = new Token(beneficiary);
        console.log("Token Deployment:");
        console.log("Address:", address(token));
        vm.stopBroadcast();
    }
}