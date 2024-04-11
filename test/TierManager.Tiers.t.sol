// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TierManager} from "../src/TierManager.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TierManagerTiers is Base {

    event SetTier(uint256 indexed _index);
    event UpdatedTier(uint256 indexed _index);
    event SetFundraiseTiers(uint256 indexed _fundraiseIndex, uint256[] _tierIds);

    function test_setTier_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tierManager.setTier("Tier 0", address(token), 0, 0, address(token), 0, 0);

        vm.stopPrank();
    }

    function test_setTier() public {
        assertEq(tierManager.totalTiers(), 0);

        vm.startPrank(MANAGER);

        string memory name = "Tier 0";
        uint256 balance = 100 * 10**18;
        uint256 minAllocation = 42 * 10**18;
        uint256 maxAllocation = 69 * 10**18;

        tierManager.setTier(name, address(token), balance, 0, address(token), minAllocation, maxAllocation);

        vm.stopPrank();

        (string memory tierName, address tierToken, uint256 tierBalance, uint256 tierIdRequirement, address allocationToken, uint256 tierMinAllocation, uint256 tierMaxAllocation) = tierManager.tiers(0);
        assertEq(tierName, name);
        assertEq(tierToken, address(token));
        assertEq(tierBalance, balance);
        assertEq(tierIdRequirement, 0);
        assertEq(allocationToken, address(token));
        assertEq(tierMinAllocation, minAllocation);
        assertEq(tierMaxAllocation, maxAllocation);

        assertEq(tierManager.totalTiers(), 1);
    }

    function test_setTier_event() public {
        vm.startPrank(MANAGER);

        string memory name = "Tier 0";
        uint256 balance = 100 * 10**18;
        uint256 minAllocation = 42 * 10**18;
        uint256 maxAllocation = 69 * 10**18;

        vm.expectEmit();
        emit SetTier(0);

        tierManager.setTier(name, address(token), balance, 0, address(token), minAllocation, maxAllocation);

        vm.stopPrank();
    }

    function test_updateTier_onlyOwner() public {
        vm.startPrank(address(DEPLOYER));

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        tierManager.updateTier(0, "Tier 0", address(token), 0, 0, address(token), 0, 0);

        vm.stopPrank();
    }

    function test_updateTier_wrongIndex() public {
        vm.startPrank(MANAGER);

        vm.expectRevert(bytes("WRONG_INDEX"));
        tierManager.updateTier(1, "Tier 0", address(token), 0, 0, address(token), 0, 0);

        vm.stopPrank();
    }

    function test_updateTier() public {
        // Create default tier
        createDefaultTier();

        // Pre-conditions
        assertEq(tierManager.totalTiers(), 1);

        // Update
        vm.startPrank(MANAGER);

        string memory name = "Tier 1";
        uint256 balance = 99 * 10**18;
        uint256 minAllocation = 41 * 10**18;
        uint256 maxAllocation = 68 * 10**18;

        tierManager.updateTier(0, name, address(token), balance, 1, address(token2), minAllocation, maxAllocation);

        vm.stopPrank();

        // Post-conditions
        assertEq(tierManager.totalTiers(), 1);

        (string memory updatedTierName, address updatedTierToken, uint256 updatedTierBalance, uint256 updatedTierIdRequirement, address updatedAllocationToken, uint256 updatedTierMinAllocation, uint256 updatedTierMaxAllocation) = tierManager.tiers(0);
        assertEq(updatedTierName, name);
        assertEq(updatedTierToken, address(token));
        assertEq(updatedTierBalance, balance);
        assertEq(updatedTierIdRequirement, 1);
        assertEq(updatedAllocationToken, address(token2));
        assertEq(updatedTierMinAllocation, minAllocation);
        assertEq(updatedTierMaxAllocation, maxAllocation);
    }

    function test_updateTier_event() public {
        // Create default tier
        createDefaultTier();

        vm.startPrank(MANAGER);

        string memory name = "Tier 1";
        uint256 balance = 99 * 10**18;
        uint256 minAllocation = 41 * 10**18;
        uint256 maxAllocation = 68 * 10**18;

        vm.expectEmit();
        emit UpdatedTier(0);

        tierManager.updateTier(0, name, address(token), balance, 0, address(token), minAllocation, maxAllocation);

        vm.stopPrank();
    }

    function test_setFundraiseTiers_onlyOwner() public {
        vm.startPrank(DEPLOYER);

        bytes memory error = abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", address(DEPLOYER), keccak256("MANAGER_ROLE"));
        vm.expectRevert(error);
        uint256[] memory tiers = new uint256[](1);
        tiers[0] = 0;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }

    function test_setFundraiseTiers_wrongToken() public {
        // Create fundraise
        createFundraise(token);

        vm.startPrank(MANAGER);

        // Create wrong tier
        string memory name = "Tier 1";
        uint256 balance = 100 * 10**18;
        uint256 minAllocation = 42 * 10**18;
        uint256 maxAllocation = 69 * 10**18;

        tierManager.setTier(name, address(token), balance, 0, address(token2), minAllocation, maxAllocation);

        assertEq(tierManager.totalTiers(), 3); // Two created by the fundraise and the one we created

        uint256[] memory tiers = new uint256[](1);
        tiers[0] = 2;

        vm.expectRevert(bytes("WRONG_TOKEN"));
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }

    function test_setFundraiseTiers() public {
        // No tiers for fundraise index = 0
        vm.expectRevert();
        tierManager.fundraiseTiers(0, 0);

        // Create two fundraises
        createFundraise(token);
        createFundraise(token);

        // Add tiers
        createDefaultTier();
        createDefaultTier();
        createDefaultTier();

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](2);
        tiers[0] = 0;
        tiers[1] = 2;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        // Fundraise #1
        uint256[] memory tiers1 = new uint256[](1);
        tiers1[0] = 1;
        tierManager.setFundraiseTiers(address(vault), 1, tiers1);

        vm.stopPrank();

        // Check tiers
        assertEq(tierManager.fundraiseTiers(0, 0), 0);
        assertEq(tierManager.fundraiseTiers(0, 1), 2);
        assertEq(tierManager.fundraiseTiers(1, 0), 1);

        vm.expectRevert();
        tierManager.fundraiseTiers(0, 2);
        vm.expectRevert();
        tierManager.fundraiseTiers(1, 1);
        vm.expectRevert();
        tierManager.fundraiseTiers(2, 0);
    }

    function test_setFundraiseTiers_event() public {
        // Create oen fundraise
        createFundraise(token);

        // Create two tiers
        createDefaultTier();
        createDefaultTier();

        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](1);
        tiers[0] = 1;

        vm.expectEmit();
        emit SetFundraiseTiers(0, tiers);

        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }
}
