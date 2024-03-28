// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";
import "forge-std/Script.sol";

contract VaultDeployer is Script {
    Vault public vault;
    Vault public vaultImplementation;

    address public manager;
    address public owner;
    address public tierManager;
    address public whitelistSigner;

    constructor() {
        // Constructor args
        manager = address(0);
        owner = address(0);
        tierManager = address(0);
        whitelistSigner = address(0);
    }

    function run() external {
        vm.startBroadcast();
        vaultImplementation = new Vault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(address(vaultProxy));
        vault.initialize(manager, owner, tierManager, whitelistSigner);

        console.log("Vault Deployment:");
        console.log("Proxy:", address(vault));
        console.log("Implementation:", address(vaultImplementation));
        console.log("Signer:", vault.whitelistSigner());
        console.log("TierManager:", vault.tierManager());
        vm.stopBroadcast();
    }
}