// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./Base.t.sol";
import {XBorg} from "../src/XBorgToken.sol";

contract XBorgConstructor is Base {
    function test_constructor() public {
        vm.startPrank(DEPLOYER);

        XBorg xborg = new XBorg();
        uint256 deployerBalance = xborg.balanceOf(DEPLOYER);
        assertEq(deployerBalance, 10 ** (9 + 18)); // 1B tokens + 18 decimals

        vm.stopPrank();
    }
}
