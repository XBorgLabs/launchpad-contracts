// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "../../src/TokenDistribution.sol";

/// @dev Mock for testing.
/// @custom:oz-upgrades-from src/TokenDistribution.sol:TokenDistribution
contract TokenDistributionUpgraded is TokenDistribution {
    uint256 public version;

    function initializeV2(uint256 _version) external reinitializer(2) {
        version = _version;
    }

    function getVersion() public view returns (uint256) {
        return version;
    }
}