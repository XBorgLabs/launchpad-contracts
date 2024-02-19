// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ITierManager {
    function getAllocation(uint256 _fundraiseIndex, address _depositAddress) external view returns (uint256, uint256);
}