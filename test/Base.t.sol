// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {TierManager} from "../src/TierManager.sol";
import {TokenDistribution} from "../src/TokenDistribution.sol";
import {Vault} from "../src/Vault.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Token} from "./mock/Token.sol";
import {ERC721Token} from "./mock/ERC721Token.sol";
import {ERC1155Token} from "./mock/ERC1155Token.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

abstract contract Base is Test {
    // Token Distribution
    TokenDistribution public tokenDistribution;
    TokenDistribution public tokenDistributionImplementation;

    // ERC20 Token
    Token public token;
    Token public token2;

    // ERC721 Token
    ERC721Token public erc721Token;

    // ERC1155 Token
    ERC1155Token public erc1155Token;

    // Tier Manager
    TierManager public tierManager;
    TierManager public tierManagerImplementation;

    // Vault
    Vault public vault;
    Vault public vaultImplementation;

    // Addresses
    address public DEPLOYER;
    address public MANAGER;
    address public OWNER;
    address public TESTER;
    address public SIGNER;
    uint256 public SIGNER_PK;
    address public FAKE_SIGNER;
    uint256 public FAKE_SIGNER_PK;
    address public BENEFICIARY;

    constructor() {
        DEPLOYER = makeAddr("DEPLOYER");
        MANAGER = makeAddr("MANAGER");
        OWNER = makeAddr("OWNER");
        TESTER = makeAddr("TESTER");
        (SIGNER, SIGNER_PK) = makeAddrAndKey("SIGNER");
        (FAKE_SIGNER, FAKE_SIGNER_PK) = makeAddrAndKey("FAKE_SIGNER");
        BENEFICIARY = makeAddr("BENEFICIARY");

        // Deploy contracts
        vm.startPrank(DEPLOYER);

        // ERC20 Token
        token = new Token(DEPLOYER);
        token2 = new Token(DEPLOYER);

        // ERC721 Token
        erc721Token = new ERC721Token(DEPLOYER);

        // ERC1155 Token
        erc1155Token = new ERC1155Token(DEPLOYER);

        // TokenDistribution
        tokenDistributionImplementation = new TokenDistribution();
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenDistributionImplementation), "");
        tokenDistribution = TokenDistribution(address(proxy));
        tokenDistribution.initialize(MANAGER, OWNER);

        // TierManager
        tierManagerImplementation = new TierManager();
        ERC1967Proxy tierManagerProxy = new ERC1967Proxy(address(tierManagerImplementation), "");
        tierManager = TierManager(address(tierManagerProxy));
        tierManager.initialize(MANAGER, OWNER);

        // Vault
        vaultImplementation = new Vault();
        ERC1967Proxy vaultProxy = new ERC1967Proxy(address(vaultImplementation), "");
        vault = Vault(address(vaultProxy));
        vault.initialize(MANAGER, OWNER, address(tierManager), SIGNER);

        // Fund tokens to TokenDistribution
        deal(address(token), address(tokenDistribution), 1000 * 10**18);

        vm.stopPrank();
    }

    function createVestingSchedule(Token _token) public {
        vm.startPrank(MANAGER);

        uint256 start = block.timestamp;
        uint256 cliff = 60; // Unlock after 1 minute, you get at cliff 60/600 = 10% of the tokens
        uint256 duration = 600; // Linear vests over 10 minutes
        uint256 amount = 1000 * 10**18;

        tokenDistribution.createVestingSchedule(address(_token), TESTER, start, cliff, duration, amount);

        vm.stopPrank();
    }

    function createDefaultTier() public {
        vm.startPrank(MANAGER);

        string memory name = "Tier 0";
        uint256 balance = 100 * 10**18;
        uint256 minAllocation = 42 * 10**18;
        uint256 maxAllocation = 69 * 10**18;

        tierManager.setTier(name, address(token), balance, 0, address(token), minAllocation, maxAllocation);

        vm.stopPrank();
    }

    function createLargerTier() public {
        vm.startPrank(MANAGER);

        string memory name = "Tier 0";
        uint256 balance = 10000 * 10**18;
        uint256 minAllocation = 50 * 10**18;
        uint256 maxAllocation = 250 * 10**18;

        tierManager.setTier(name, address(token), balance, 0, address(token), minAllocation, maxAllocation);

        vm.stopPrank();
    }

    function createFundraise(Token _token) public {
        vm.startPrank(MANAGER);

        string memory name = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp + 60;
        uint256 endTime = block.timestamp + 660;
        bool whitelistEnabled = true;

        // Create fundraise
        vault.createFundraise(name, address(_token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        // Add a tier
        createDefaultTier();
        createLargerTier();

        // Create tier stops prank
        vm.startPrank(MANAGER);

        uint256[] memory tiers = new uint256[](2);
        tiers[0] = 0;
        tiers[1] = 1;
        tierManager.setFundraiseTiers(0, tiers);

        vm.stopPrank();
    }
}