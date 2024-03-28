// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../../src/TierManager.sol";

/// @dev Mock for testing.
/// @custom:oz-upgrades-from src/TierManager.sol:TierManager
contract TierManagerUpgraded is TierManager {
    uint256 public version;

    function initializeV2(uint256 _version) external reinitializer(2) {
        version = _version;
    }

    function getVersion() public view returns (uint256) {
        return version;
    }
}