// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultCreateFundraise is Base {
    event FundraiseCreated(uint256 indexed index, string name, address indexed token, address indexed beneficiary, uint256 softCap, uint256 hardCap, uint256 startTime, uint256 endTime);

    function test_createFundraise_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 60;
        bool whitelistEnabled = true;

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        vault.createFundraise(name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise_wrongToken() public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 60;
        bool whitelistEnabled = true;

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.createFundraise(name, address(0), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise_wrongBeneficiary() public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 60;
        bool whitelistEnabled = true;

        vm.expectRevert(bytes("ADDRESS_ZERO"));
        vault.createFundraise(name, address(token), address(0), softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise_wrongCaps() public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 10000 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + 60;
        bool whitelistEnabled = true;

        vm.expectRevert(bytes("WRONG_CAPS"));
        vault.createFundraise(name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise_wrongStartTime() public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp - 1;
        uint256 endTime = startTime + 60;
        bool whitelistEnabled = true;

        vm.expectRevert(bytes("WRONG_TIME"));
        vault.createFundraise(name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise_wrongEndTime() public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp;
        uint256 endTime = startTime - 1;
        bool whitelistEnabled = true;

        vm.expectRevert(bytes("WRONG_TIME"));
        vault.createFundraise(name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise_wrongStartEndTime() public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp + 60;
        uint256 endTime = block.timestamp;
        bool whitelistEnabled = true;

        vm.expectRevert(bytes("WRONG_TIME"));
        vault.createFundraise(name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    function test_createFundraise() public {
        assertEq(vault.totalFundraises(), 0);

        vm.startPrank(MANAGER);

        string memory name = "Fundraise";

        vault.createFundraise(name, address(token), BENEFICIARY, 100 * 10**18, 1000 * 10**18, block.timestamp + 60, block.timestamp + 660, true);

        vm.stopPrank();

        (string memory fundraiseName, address fundraiseToken, address fundraiseBeneficiary, uint256 fundraiseSoftCap, uint256 fundraiseHardCap, uint256 fundraiseStartTime, uint256 fundraiseEndTime, bool fundraiseWhitelistEnabled, Vault.PublicFundraise memory publicFundraise, uint256 currentAmountRaised, bool completed) = vault.fundraises(0);

        assertEq(fundraiseName, name);
        assertEq(fundraiseToken, address(token));
        assertEq(fundraiseBeneficiary, BENEFICIARY);
        assertEq(fundraiseSoftCap, 100 * 10**18);
        assertEq(fundraiseHardCap, 1000 * 10**18);
        assertEq(fundraiseStartTime, block.timestamp + 60);
        assertEq(fundraiseEndTime, block.timestamp + 660);
        assertTrue(fundraiseWhitelistEnabled);
        assertFalse(publicFundraise.enabled);
        assertEq(publicFundraise.minAllocation, 0);
        assertEq(publicFundraise.maxAllocation, 0);
        assertEq(currentAmountRaised, 0);
        assertFalse(completed);
    }

    function test_createFundraise_event() public {
        vm.startPrank(MANAGER);

        uint256 index = 0;
        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp + 60;
        uint256 endTime = block.timestamp + 660;
        bool whitelistEnabled = true;

        vm.expectEmit();
        emit FundraiseCreated(index, name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime);

        vault.createFundraise(name, address(token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }
}
