// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";

contract ERC1155Token is ERC1155 {
    constructor(address _beneficiary) ERC1155("TEST") {}

    function mint(address _to, uint256 _id, uint256 _amount) external {
        _mint(_to, _id, _amount, "0x");
    }
}