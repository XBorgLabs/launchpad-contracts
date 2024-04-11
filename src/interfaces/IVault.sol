// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IVault {
    function getFundraiseTokenRaised(uint256 _index) external view returns (address);
}