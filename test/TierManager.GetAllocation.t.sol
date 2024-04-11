// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TierManager} from "../src/TierManager.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./mock/Token.sol";

contract TierManagerGetAllocation is Base {
    function fixture_createFundraise(Token _token) internal {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp + 60;
        uint256 endTime = block.timestamp + 660;
        bool whitelistEnabled = true;

        // Create fundraise
        vault.createFundraise(name, address(_token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        vm.stopPrank();
    }

    // @dev Adds three ERC20 tiers
    function fixture_getAllocation_addTiers() internal {
        // Create Fundraise
        fixture_createFundraise(token);

        // Add tiers
        vm.startPrank(MANAGER);
        string memory name = "Tier";
        tierManager.setTier(name, address(token), 10 * 10**18, 0, address(token), 1, 100);
        tierManager.setTier(name, address(token), 100 * 10**18, 0, address(token), 10, 1000);
        tierManager.setTier(name, address(token), 1000 * 10**18, 0, address(token), 100, 10000);
        vm.stopPrank();

        assertEq(tierManager.totalTiers(), 3);
    }

    // @dev Add tiers for ERC20, ERC721 and ERC1155
    function fixture_getAllocation_addAllErcTiers() internal {
        // Create Fundraise
        fixture_createFundraise(token);

        // Add tiers
        vm.startPrank(MANAGER);
        string memory name = "Tier";
        tierManager.setTier(name, address(token), 10 * 10**18, 0, address(token), 1, 100);
        tierManager.setTier(name, address(erc721Token), 100, 0, address(token), 10, 1000);
        tierManager.setTier(name, address(erc1155Token), 5, 0, address(token), 100, 10000);
        tierManager.setTier(name, address(erc1155Token), 2, 1, address(token), 1000, 100000);
        vm.stopPrank();

        assertEq(tierManager.totalTiers(), 4);
    }

    // @dev Add three tiers. Set in asc order (tier 0, 1, 2)
    function fixture_getAllocation_multipleTiers_ascOrder() internal {
        fixture_getAllocation_addTiers();

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](3);
        tiers[0] = 0;
        tiers[1] = 1;
        tiers[2] = 2;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }

    // @dev Add three tiers. Set in desc order (tier 2, 1, 0)
    function fixture_getAllocation_multipleTiers_descOrder() internal {
        fixture_getAllocation_addTiers();

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](3);
        tiers[0] = 2;
        tiers[1] = 1;
        tiers[2] = 0;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }

    // @dev Add three tiers. Set in random order (tier 2, 0, 1)
    function fixture_getAllocation_multipleTiers_randomOrder() internal {
        fixture_getAllocation_addTiers();

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](3);
        tiers[0] = 2;
        tiers[1] = 0;
        tiers[2] = 1;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }

    // @dev Add three tiers with different interfaces. Set in random order (tier 2, 0, 3, 1)
    function fixture_getAllocation_multipleErcTiers_randomOrder() internal {
        fixture_getAllocation_addAllErcTiers();

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](4);
        tiers[0] = 2;
        tiers[1] = 0;
        tiers[2] = 3;
        tiers[3] = 1;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        vm.stopPrank();
    }

    function test_getAllocation_noTiers() public {
        vm.expectRevert(bytes("NO_TIERS"));
        tierManager.getAllocation(0, TESTER);
    }

    // @dev Test with single tier. User shouldn't be eligible.
    function test_getAllocation_singleTier_noTier() public {
        // Create fundraise
        fixture_createFundraise(token);

        // Add tiers
        createDefaultTier();
        assertEq(tierManager.totalTiers(), 1);

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](1);
        tiers[0] = 0;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        // Deal 10 tokens (less than min. 100 for tier 0)
        deal(address(token), address(DEPLOYER), 10 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 0);
        assertEq(maxAllocation, 0);

        vm.stopPrank();
    }

    // @dev Test with single tier. User should be eligible to the only tier.
    function test_getAllocation_singleTier_tier0() public {
        // Create fundraise
        fixture_createFundraise(token);

        // Add tiers
        createDefaultTier();
        assertEq(tierManager.totalTiers(), 1);

        // Set Fundraise Tiers
        vm.startPrank(MANAGER);

        // Fundraise #0
        uint256[] memory tiers = new uint256[](1);
        tiers[0] = 0;
        tierManager.setFundraiseTiers(address(vault), 0, tiers);

        // Deal 100 tokens (== min. 100 for tier 0)
        deal(address(token), address(DEPLOYER), 100 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 42 * 10**18);
        assertEq(maxAllocation, 69 * 10**18);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in asc order (tier 0, 1, 2). User shouldn't be eligible.
    function test_getAllocation_multipleTiers_ascOrder_noTier() external {
        fixture_getAllocation_multipleTiers_ascOrder();

        // Deal 5 tokens (less than min. 10 for tier 0)
        deal(address(token), address(DEPLOYER), 5 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 0);
        assertEq(maxAllocation, 0);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in asc order (tier 0, 1, 2). User should be eligble to tier 0.
    function test_getAllocation_multipleTiers_ascOrder_tier0() external {
        fixture_getAllocation_multipleTiers_ascOrder();

        // Deal 99 tokens (> tier 0 && < tier 1)
        deal(address(token), address(DEPLOYER), 99 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 1);
        assertEq(maxAllocation, 100);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in asc order (tier 0, 1, 2). User should be eligble to tier 1.
    function test_getAllocation_multipleTiers_ascOrder_tier1() external {
        fixture_getAllocation_multipleTiers_ascOrder();

        // Deal 100 tokens (= tier 1 && < tier 2)
        deal(address(token), address(DEPLOYER), 100 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 1);
        assertEq(minAllocation, 10);
        assertEq(maxAllocation, 1000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in asc order (tier 0, 1, 2). User should be eligble to tier 2.
    function test_getAllocation_multipleTiers_ascOrder_tier2() external {
        fixture_getAllocation_multipleTiers_ascOrder();

        // Deal 42069 tokens (> tier 2)
        deal(address(token), address(DEPLOYER), 42069 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 2);
        assertEq(minAllocation, 100);
        assertEq(maxAllocation, 10000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in desc order (tier 2, 1, 0). User shouldn't be eligible.
    function test_getAllocation_multipleTiers_descOrder_noTier() external {
        fixture_getAllocation_multipleTiers_descOrder();

        // Deal 5 tokens (less than min. 10 for tier 0)
        deal(address(token), address(DEPLOYER), 5 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 0);
        assertEq(maxAllocation, 0);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in desc order (tier 2, 1, 0). User should be eligible to tier 0.
    function test_getAllocation_multipleTiers_descOrder_tier0() external {
        fixture_getAllocation_multipleTiers_descOrder();

        // Deal 99 tokens (> tier 0 && < tier 1)
        deal(address(token), address(DEPLOYER), 99 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 1);
        assertEq(maxAllocation, 100);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in desc order (tier 2, 1, 0). User should be eligible to tier 1.
    function test_getAllocation_multipleTiers_descOrder_tier1() external {
        fixture_getAllocation_multipleTiers_descOrder();

        // Deal 100 tokens (= tier 1 && < tier 2)
        deal(address(token), address(DEPLOYER), 100 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 1);
        assertEq(minAllocation, 10);
        assertEq(maxAllocation, 1000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in desc order (tier 2, 1, 0). User should be eligible to tier 2.
    function test_getAllocation_multipleTiers_descOrder_tier2() external {
        fixture_getAllocation_multipleTiers_descOrder();

        // Deal 42069 tokens (> tier 2)
        deal(address(token), address(DEPLOYER), 42069 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 2);
        assertEq(minAllocation, 100);
        assertEq(maxAllocation, 10000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in random order (tier 2, 0, 1). User shouldn't be eligible.
    function test_getAllocation_multipleTiers_randomOrder_noTier() external {
        fixture_getAllocation_multipleTiers_randomOrder();

        // Deal 5 tokens (less than min. 10 for tier 0)
        deal(address(token), address(DEPLOYER), 5 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 0);
        assertEq(maxAllocation, 0);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in random order (tier 2, 0, 1). User should be eligible to tier 0.
    function test_getAllocation_multipleTiers_randomOrder_tier0() external {
        fixture_getAllocation_multipleTiers_randomOrder();

        // Deal 99 tokens (> tier 0 && < tier 1)
        deal(address(token), address(DEPLOYER), 99 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 1);
        assertEq(maxAllocation, 100);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in random order (tier 2, 0, 1). User should be eligible to tier 1.
    function test_getAllocation_multipleTiers_randomOrder_tier1() external {
        fixture_getAllocation_multipleTiers_randomOrder();

        // Deal 100 tokens (= tier 1 && < tier 2)
        deal(address(token), address(DEPLOYER), 100 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 1);
        assertEq(minAllocation, 10);
        assertEq(maxAllocation, 1000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers. Set in random order (tier 2, 0, 1). User should be eligible to tier 2.
    function test_getAllocation_multipleTiers_randomOrder_tier2() external {
        fixture_getAllocation_multipleTiers_randomOrder();

        // Deal 42069 tokens (> tier 2)
        deal(address(token), address(DEPLOYER), 42069 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 2);
        assertEq(minAllocation, 100);
        assertEq(maxAllocation, 10000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers of multiple interfaces. Set in random order (tier 2, 0, 3, 1). User should be eligible to tier 0.
    function test_getAllocation_multipleErcTiers_randomOrder_tier0() external {
        fixture_getAllocation_multipleErcTiers_randomOrder();

        // Deal 10 ERC20 tokens (= tier 0)
        deal(address(token), address(DEPLOYER), 10 * 10**18);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 1);
        assertEq(maxAllocation, 100);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers of multiple interfaces. Set in random order (tier 2, 0, 3, 1). User should be eligible to tier 1.
    function test_getAllocation_multipleErcTiers_randomOrder_tier1() external {
        fixture_getAllocation_multipleErcTiers_randomOrder();

        // Deal 100 ERC721 tokens (= tier 1)
        erc721Token.mint(DEPLOYER, 100);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 1);
        assertEq(minAllocation, 10);
        assertEq(maxAllocation, 1000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers of multiple interfaces. Set in random order (tier 2, 0, 3, 1). User should be eligible to tier 2.
    function test_getAllocation_multipleErcTiers_randomOrder_tier2() external {
        fixture_getAllocation_multipleErcTiers_randomOrder();

        // Deal 5 ERC1155 tokens of id 0 (= tier 2)
        erc1155Token.mint(DEPLOYER, 0, 5);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 2);
        assertEq(minAllocation, 100);
        assertEq(maxAllocation, 10000);

        vm.stopPrank();
    }

    // @dev Test with multiple tiers of multiple interfaces. Set in random order (tier 2, 0, 3, 1). User should be eligible to tier 3.
    function test_getAllocation_multipleErcTiers_randomOrder_tier3() external {
        fixture_getAllocation_multipleErcTiers_randomOrder();

        // Deal 5 ERC1155 tokens of id 0 (= tier 2)
        erc1155Token.mint(DEPLOYER, 1, 2);

        vm.startPrank(address(DEPLOYER));

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, DEPLOYER);
        assertEq(tierIndex, 3);
        assertEq(minAllocation, 1000);
        assertEq(maxAllocation, 100000);

        vm.stopPrank();
    }

    function test_getAllocation_whitelist() external {
        fixture_getAllocation_multipleTiers_randomOrder();

        // Set whitelist
        vm.startPrank(MANAGER);

        address[] memory whitelistAddresses = new address[](1);
        whitelistAddresses[0] = TESTER;

        uint256[] memory tierIndexes = new uint256[](1);
        tierIndexes[0] = 2;

        tierManager.setWhitelist(whitelistAddresses, tierIndexes);
        vm.stopPrank();

        // Make sure TESTER has no tokens
        deal(address(token), address(DEPLOYER), 0);

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, TESTER);
        assertEq(tierIndex, 2);
        assertEq(minAllocation, 100);
        assertEq(maxAllocation, 10000);
    }

    function test_getAllocation_none() external {
        fixture_getAllocation_multipleTiers_randomOrder();

        // Make sure TESTER has no tokens
        deal(address(token), address(DEPLOYER), 0);

        (uint256 tierIndex, uint256 minAllocation, uint256 maxAllocation) = tierManager.getAllocation(0, TESTER);
        assertEq(tierIndex, 0);
        assertEq(minAllocation, 0);
        assertEq(maxAllocation, 0);
    }

}
