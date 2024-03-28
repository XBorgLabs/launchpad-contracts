// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../src/Vault.sol";

/// @dev Mock for testing.
/// @custom:oz-upgrades-from src/Vault.sol:Vault
contract VaultUpgraded is Vault {
    uint256 public version;

    function initializeV2(uint256 _version) external reinitializer(2) {
        version = _version;
    }

    function getVersion() public view returns (uint256) {
        return version;
    }
}