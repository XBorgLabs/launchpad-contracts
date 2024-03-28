// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    constructor(address _beneficiary) ERC20("Test Token", "TEST") {
        _mint(_beneficiary, 100000 * 10**18);
    }
}