// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract ERC721Token is ERC721 {
    constructor(address _beneficiary) ERC721("Test Token", "TEST") {}

    function mint(address _to, uint256 _amount) external {
        for (uint i = 0; i < _amount; i++) {
            _mint(_to, i); // Quick fix, we start from 0 in each test
        }
    }
}