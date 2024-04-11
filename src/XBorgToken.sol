// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title XBorg
/// @notice Implements the XBorg (XBG) token which has a fixed supply of 1 billion tokens.
/// @author XBorg
contract XBorg is ERC20, ERC20Burnable, ERC20Permit {
    constructor() ERC20("XBorg", "XBG") ERC20Permit("XBorg") {
        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }
}