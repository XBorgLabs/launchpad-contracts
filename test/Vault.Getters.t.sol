// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Base} from "./Base.t.sol";
import {TierManager} from "../src/TierManager.sol";
import {Vault} from "../src/Vault.sol";
import {Token} from "./mock/Token.sol";
import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VaultGetters is Base {
    function createNewFundraise(Token _token) internal {
        vm.startPrank(MANAGER);

        string memory fundraiseName = "Fundraise";
        uint256 softCap = 100 * 10**18;
        uint256 hardCap = 1000 * 10**18;
        uint256 startTime = block.timestamp + 60;
        uint256 endTime = block.timestamp + 660;
        bool whitelistEnabled = true;

        // Create two fundraises
        vault.createFundraise(fundraiseName, address(_token), BENEFICIARY, softCap, hardCap, startTime, endTime, whitelistEnabled);

        // Remove whitelist
        vault.setWhitelist(0, false);
        vault.setWhitelist(1, false);

        // Add a tier
        string memory name = "Default Tier";

        // Set tier
        tierManager.setTier(name, address(_token), TierManager.TokenType.ERC20, 1 * 10**18, 0, address(_token), 1 * 10**18, 10000 * 10**18);

        uint256[] memory tiers = new uint256[](1);
        tiers[0] = tierManager.totalTiers() - 1;
        tierManager.setFundraiseTiers(address(vault), vault.totalFundraises() - 1, tiers);

        vm.stopPrank();
    }

    function startFundraise(uint256 _index) internal {
        (,,,,, uint256 startTime,,,,,) = vault.fundraises(_index);
        vm.warp(startTime);
    }

    function depositFundraise(uint256 _index, Token _token, address _sender, uint256 _depositAmount) internal {
        // Deposit
        vm.startPrank(_sender);

        _token.approve(address(vault), _depositAmount);
        vault.deposit(_index, _depositAmount);

        vm.stopPrank();
    }

    function endFundraise(uint256 _index) internal {
        (,,,,,,uint256 endTime,,,,) = vault.fundraises(_index);
        vm.warp(endTime + 1);
    }

    function setWhitelist(uint256 _index, bool _whitelistEnabled) internal {
        vm.startPrank(MANAGER);
        vault.setWhitelist(_index, _whitelistEnabled);
        vm.stopPrank();
    }

    function test_getFundraiseContribution() public {
        // Create 2 fundraises
        createNewFundraise(token);
        startFundraise(0);
        createNewFundraise(token2);
        startFundraise(1);

        // Tester deposits in both
        deal(address(token), TESTER, 100 * 10**18);
        deal(address(token2), TESTER, 100 * 10**18);
        uint256 depositAmountTesterToken = 100 * 10**18;
        uint256 depositAmountTesterToken2 = 65 * 10**18;
        depositFundraise(0, token, TESTER, depositAmountTesterToken);
        depositFundraise(1, token2, TESTER, depositAmountTesterToken2);

        // Deployer only deposits in the second one
        deal(address(token2), DEPLOYER, 50 * 10**18);
        uint256 depositAmountDeployerToken = 50 * 10**18;
        depositFundraise(1, token2, DEPLOYER, depositAmountDeployerToken);

        assertEq(vault.getFundraiseContribution(0, TESTER), 100 * 10**18);
        assertEq(vault.getFundraiseContribution(1, TESTER), 65 * 10**18);
        assertEq(vault.getFundraiseContribution(0, DEPLOYER), 0);
        assertEq(vault.getFundraiseContribution(1, DEPLOYER), 50 * 10**18);
    }

    function test_getFundraiseTokenRaised() public {
        createNewFundraise(token);
        createNewFundraise(token2);

        assertEq(address(token), vault.getFundraiseTokenRaised(0));
        assertEq(address(token2), vault.getFundraiseTokenRaised(1));
    }

    function test_getFundraiseRunning() public {
        createNewFundraise(token);

        // Not running at start
        assertFalse(vault.getFundraiseRunning(0));

        // Start
        startFundraise(0);
        assertTrue(vault.getFundraiseRunning(0));

        // End
        endFundraise(0);
        assertFalse(vault.getFundraiseRunning(0));
    }

    function test_getFundraiseStarted() public {
        createFundraise(token);

        // Not started
        assertFalse(vault.getFundraiseStarted(0));

        // Start
        startFundraise(0);
        assertTrue(vault.getFundraiseStarted(0));

        // End
        endFundraise(0);
        assertTrue(vault.getFundraiseStarted(0));
    }

    function test_getFundraiseSuccessful() public {
        createNewFundraise(token);

        // By default, not successful
        assertFalse(vault.getFundraiseSuccessful(0));

        // Start, same not successful
        startFundraise(0);
        assertFalse(vault.getFundraiseSuccessful(0));

        // Deposit a bit (less than soft cap which is 100)
        deal(address(token), TESTER, 100 * 10**18);
        deal(address(token), DEPLOYER, 100 * 10**18);
        uint256 depositAmount = 25 * 10**18;
        depositFundraise(0, token, TESTER, depositAmount);
        depositFundraise(0, token, DEPLOYER, depositAmount);

        assertFalse(vault.getFundraiseSuccessful(0)); // 50 < 100

        // Deposit more
        depositFundraise(0, token, TESTER, 49 * 10**18);
        assertFalse(vault.getFundraiseSuccessful(0)); // 99 < 100

        // Make it
        depositFundraise(0, token, TESTER, 1 * 10**18);
        assertTrue(vault.getFundraiseSuccessful(0)); // 100 >= 100

        // End it
        endFundraise(0);
        assertTrue(vault.getFundraiseSuccessful(0)); // 100 >= 100
    }

    function test_getFundraiseFull() public {
        createNewFundraise(token);

        // By default, not successful
        assertFalse(vault.getFundraiseFull(0));

        // Start, same not successful
        startFundraise(0);
        assertFalse(vault.getFundraiseFull(0));

        // Deposit a bit (less than hard cap which is 1000)
        deal(address(token), TESTER, 1000 * 10**18);
        deal(address(token), DEPLOYER, 1000 * 10**18);
        uint256 depositAmount = 250 * 10**18;
        depositFundraise(0, token, TESTER, depositAmount);
        depositFundraise(0, token, DEPLOYER, depositAmount);

        assertFalse(vault.getFundraiseFull(0)); // 500 < 1000

        // Deposit more
        depositFundraise(0, token, TESTER, 499 * 10**18);
        assertFalse(vault.getFundraiseFull(0)); // 999 < 1000

        // Make it
        depositFundraise(0, token, TESTER, 1 * 10**18);
        assertTrue(vault.getFundraiseFull(0)); // 1000 >= 1000

        // End it
        endFundraise(0);
        assertTrue(vault.getFundraiseFull(0)); // 1000 >= 1000
    }

    function test_getFundraiseCompleted() public {
        createNewFundraise(token);

        // By default, not successful
        assertFalse(vault.getFundraiseCompleted(0));

        // Start, same not successful
        startFundraise(0);
        assertFalse(vault.getFundraiseCompleted(0));

        // Deposit a bit
        deal(address(token), TESTER, 1000 * 10**18);
        deal(address(token), DEPLOYER, 1000 * 10**18);
        uint256 depositAmount = 250 * 10**18;
        depositFundraise(0, token, TESTER, depositAmount);
        depositFundraise(0, token, DEPLOYER, depositAmount);

        // End it
        endFundraise(0);
        assertFalse(vault.getFundraiseCompleted(0));

        // Withdraw
        vm.startPrank(BENEFICIARY);
        vault.completeFundraise(0);
        vm.stopPrank();
        assertTrue(vault.getFundraiseCompleted(0));
    }

    function test_getFundraiseWhitelisted() public {
        createNewFundraise(token);

        setWhitelist(0, true);
        assertTrue(vault.getFundraiseWhitelisted(0));

        setWhitelist(0, false);
        assertFalse(vault.getFundraiseWhitelisted(0));
    }
}
