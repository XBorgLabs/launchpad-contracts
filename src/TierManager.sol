// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/IVault.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/// @title TierManager
/// @notice Implements a tier system for minimum and maximum allocations.
/// @author XBorg
contract TierManager is AccessControlEnumerableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct Tier {
        // Name
        string name;
        // Token to hold
        address tierToken;
        // Balance to hold
        uint256 tierBalanceRequirement;
        // ERC1155 only, id to hold, default is zero
        uint256 tierIdRequirement;
        // Fundraise token (that can be deposited)
        address allocationToken;
        // Min allocation
        uint256 minAllocation;
        // Max allocation
        uint256 maxAllocation;
    }

    /// @notice Manager role
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice The mapping containing all tiers created.
    /// @dev The index comes from totalTiers.
    mapping(uint256 => Tier) public tiers;

    /// @notice The count of all tiers created.
    uint256 public totalTiers;

    /// @notice The tiers that are linked to a fundraise id.
    mapping(uint256 => uint256[]) public fundraiseTiers;

    /// @notice The whitelist mapping for addresses that have a tier by default.
    mapping(address => mapping(uint256 => bool)) public whitelist;

    /// @notice Event emitted when a tier is created.
    /// @param _index The index of the new tier
    event SetTier(uint256 indexed _index);

    /// @notice Event emitted when a tier is updated.
    /// @param _index The index of the updated tier
    event UpdatedTier(uint256 indexed _index);

    /// @notice Event emitted when tiers are linked to a fundraise.
    /// @param _fundraiseIndex The index of the fundraise
    /// @param _tierIds The tiers available for this fundraise
    event SetFundraiseTiers(uint256 indexed _fundraiseIndex, uint256[] _tierIds);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Creates a TierManager contract.
    /// @param _manager The address of the manager of the contract.
    /// @param _owner The address of the owner of the contract.
    function initialize(address _manager, address _owner) external initializer {
        require(_manager != address(0), "ADDRESS_ZERO");
        require(_owner != address(0), "ADDRESS_ZERO");

        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();
        _grantRole(MANAGER_ROLE, _manager);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /// @notice Gets an allocation for a user for a particular fundraise.
    /// @param _fundraiseIndex The index of the fundraise on the Vault contract
    /// @param _depositAddress The address of the depositer
    /// @return The tier index, minimum and the maximum allocation
    function getAllocation(uint256 _fundraiseIndex, address _depositAddress) external view returns (uint256, uint256, uint256) {
        uint256[] memory relevantTiers = fundraiseTiers[_fundraiseIndex];
        uint256 relevantTiersLength = relevantTiers.length;

        require(relevantTiersLength > 0, "NO_TIERS");

        uint256 finalTierIndex = 0;
        uint256 minAllocation = 0;
        uint256 maxAllocation = 0;

        for (uint256 i = 0; i < relevantTiersLength; i++) {
            uint256 tierIndex = relevantTiers[i];
            address tierToken = tiers[tierIndex].tierToken;
            uint256 tokenBalance = 0;

            if (_isERC20(tierToken)) {
                tokenBalance = IERC20(tierToken).balanceOf(_depositAddress);
            } else if (_isERC721(tierToken)) {
                tokenBalance = IERC721(tierToken).balanceOf(_depositAddress);
            } else if (_isERC1155(tierToken)) {
                tokenBalance = IERC1155(tierToken).balanceOf(_depositAddress, tiers[tierIndex].tierIdRequirement);
            }

            // User must have the balance requirement or be whitelisted for this tier
            if (tokenBalance >= tiers[tierIndex].tierBalanceRequirement || whitelist[_depositAddress][tierIndex]) {
                if (tiers[tierIndex].maxAllocation > maxAllocation) {
                    finalTierIndex = tierIndex;
                    minAllocation = tiers[tierIndex].minAllocation;
                    maxAllocation = tiers[tierIndex].maxAllocation;
                }
            }
        }

        return (finalTierIndex, minAllocation, maxAllocation);
    }

    /// @notice Creates a new tier.
    /// @param _name The name of the tier.
    /// @param _tierToken The token that the user must hold.
    /// @param _tierBalance The amount of {_tierToken} that the user must hold.
    /// @param _tierIdRequirement Only for ERC1155 {tierToken}, the id to own. Default should be 0.
    /// @param _allocationToken The token that is raised, representing the unit of min and max allocation.
    /// @param _minAllocation The minimum allocation in the fundraise token.
    /// @param _maxAllocation The maximum allocation in the fundraise token.
    function setTier(string calldata _name, address _tierToken, uint256 _tierBalance, uint256 _tierIdRequirement, address _allocationToken, uint256 _minAllocation, uint256 _maxAllocation) external onlyRole(MANAGER_ROLE) {
        _setTier(totalTiers, _name, _tierToken, _tierBalance, _tierIdRequirement, _allocationToken, _minAllocation, _maxAllocation);
        totalTiers = totalTiers + 1;
        emit SetTier(totalTiers - 1);
    }

    /// @notice Updates an existing tier.
    /// @param _index The index of the tier.
    /// @param _name The name of the tier.
    /// @param _tierToken The token that the user must hold.
    /// @param _tierBalance The amount of {_tierToken} that the user must hold.
    /// @param _tierIdRequirement Only for ERC1155 {tierToken}, the id to own. Default should be 0.
    /// @param _allocationToken The token that is raised, representing the unit of min and max allocation.
    /// @param _minAllocation The minimum allocation in the fundraise token.
    /// @param _maxAllocation The maximum allocation in the fundraise token.
    function updateTier(uint256 _index, string calldata _name, address _tierToken, uint256 _tierBalance, uint256 _tierIdRequirement, address _allocationToken, uint256 _minAllocation, uint256 _maxAllocation) external onlyRole(MANAGER_ROLE) {
        require(_index < totalTiers, "WRONG_INDEX");
        _setTier(_index, _name, _tierToken, _tierBalance, _tierIdRequirement, _allocationToken, _minAllocation, _maxAllocation);
        emit UpdatedTier(_index);
    }

    /// @notice Sets the tier relevant for a fundraise.
    /// @dev It is recommended to put lowest tiers first and higher tiers at the end.
    /// @param _vault The vault where the fundraise is happening.
    /// @param _fundraiseIndex The fundraise id in the Vault contract.
    /// @param _tierIds The ids of the tiers that should apply for this fundraise.
    function setFundraiseTiers(address _vault, uint256 _fundraiseIndex, uint256[] calldata _tierIds) external onlyRole(MANAGER_ROLE) {
        for (uint256 i = 0; i < _tierIds.length; ++i) {
            require(IVault(_vault).getFundraiseTokenRaised(_fundraiseIndex) == tiers[_tierIds[i]].allocationToken, "WRONG_TOKEN");
        }
        fundraiseTiers[_fundraiseIndex] = _tierIds;
        emit SetFundraiseTiers(_fundraiseIndex, _tierIds);
    }

    /// @notice Sets a new tier to a batch of addresses
    /// @param _whitelistAddresses The addresses to benefit from the gifted tier
    /// @param _tierIndexes The indexes of the tiers (related to {tiers}) to grant
    function setWhitelist(address[] calldata _whitelistAddresses, uint256[] calldata _tierIndexes) external onlyRole(MANAGER_ROLE) {
        require(_whitelistAddresses.length == _tierIndexes.length, "WRONG_PARAMS");
        for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
            whitelist[_whitelistAddresses[i]][_tierIndexes[i]] = true;
        }
    }

    /// @notice Removes a tier from a batch of addresses
    /// @param _whitelistAddresses The addresses to benefit from the gifted tier
    /// @param _tierIndexes The indexes of the tiers (related to {tiers}) to remove
    function removeWhitelist(address[] calldata _whitelistAddresses, uint256[] calldata _tierIndexes) external onlyRole(MANAGER_ROLE) {
        require(_whitelistAddresses.length == _tierIndexes.length, "WRONG_PARAMS");
        for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
            whitelist[_whitelistAddresses[i]][_tierIndexes[i]] = false;
        }
    }

    /// @notice Updates the tiers mapping with a new or an updated tier.
    /// @param _index The index to set
    /// @param _name The name of the tier.
    /// @param _tierToken The token that the user must hold.
    /// @param _tierBalance The amount of {_tierToken} that the user must hold.
    /// @param _tierIdRequirement Only for ERC1155 {tierToken}, the id to own. Default should be 0.
    /// @param _allocationToken The token that is raised, representing the unit of min and max allocation.
    /// @param _minAllocation The minimum allocation in the fundraise token.
    /// @param _maxAllocation The maximum allocation in the fundraise token.
    function _setTier(uint256 _index, string calldata _name, address _tierToken, uint256 _tierBalance, uint256 _tierIdRequirement, address _allocationToken, uint256 _minAllocation, uint256 _maxAllocation) internal {
        require(_tierToken != address(0), "ADDRESS_ZERO");
        require(_allocationToken != address(0), "ADDRESS_ZERO");
        require(_maxAllocation >= _minAllocation, "WRONG_PARAMS");
        tiers[_index] = Tier(_name, _tierToken, _tierBalance, _tierIdRequirement, _allocationToken, _minAllocation, _maxAllocation);
    }

    /// @notice Tries to check if a token is an ERC20.
    /// @dev We use totalSupply as it's not available on ERC721.
    /// @param _tokenAddress The address of the token.
    function _isERC20(address _tokenAddress) internal view returns (bool) {
        try IERC20(_tokenAddress).totalSupply() returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Tries to check if a token is an ERC721.
    /// @param _tokenAddress The address of the token.
    function _isERC721(address _tokenAddress) internal view returns (bool) {
        try IERC721(_tokenAddress).balanceOf(address(1)) returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Tries to check if a token is an ERC1155.
    /// @param _tokenAddress The address of the token.
    function _isERC1155(address _tokenAddress) internal view returns (bool) {
        try IERC1155(_tokenAddress).balanceOf(address(1), 0) returns (uint256) {
            return true;
        } catch {
            return false;
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}