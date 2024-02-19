// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultDeployment is Base {
    function test_initialize_wrongManagerAddress() public {
        vaultImplementation = new Vault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(payable(proxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.initialize(address(0), OWNER, address(tierManager), SIGNER);
    }

    function test_initialize_wrongOwnerAddress() public {
        vaultImplementation = new Vault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(payable(proxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.initialize(MANAGER, address(0), address(tierManager), SIGNER);
    }

    function test_initialize_wrongTierManagerAddress() public {
        vaultImplementation = new Vault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(payable(proxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.initialize(MANAGER, OWNER, address(0), SIGNER);
    }

    function test_initialize_wrongWhitelistSignerAddress() public {
        vaultImplementation = new Vault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(payable(proxy));
        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.initialize(MANAGER, OWNER, address(tierManager), address(0));
    }

    function test_initialize() public {
        vaultImplementation = new Vault();
        ERC1967Proxy proxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(payable(proxy));
        vault.initialize(MANAGER, OWNER, address(tierManager), SIGNER);

        assertTrue(tierManager.hasRole(keccak256("MANAGER_ROLE"), MANAGER));
        assertTrue(tierManager.hasRole(0x00, OWNER)); // DEFAULT_ADMIN_ROLE
        assertEq(vault.tierManager(), address(tierManager));
        assertEq(vault.whitelistSigner(), SIGNER);
    }
}
