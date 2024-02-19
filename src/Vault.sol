// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "./interfaces/ITierManager.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

/// @title Vault
/// @notice Implements a vault where fundraises can be created.
/// @author XBorg
contract Vault is AccessControlUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    struct Fundraise {
        // Token to raise
        address token;
        // Beneficiary
        address beneficiary;
        // Minimum amount to be raised
        uint256 softCap;
        // Maximum amount to be raised
        uint256 hardCap;
        // Start time
        uint256 startTime;
        // End time
        uint256 endTime;
        // Whitelist enabled
        bool whitelistEnabled;
        // Public
        PublicFundraise publicFundraise;
        // Current amount raised
        uint256 currentAmountRaised;
        // Contributions
        mapping(address => uint256) contributions;
        // Completed (Hard cap withdrawn)
        bool completed;
    }

    struct PublicFundraise {
        // Is open to public
        bool enabled;
        // Public min allocation
        uint256 minAllocation;
        // Public max allocation
        uint256 maxAllocation;
    }

    /// @notice Manager role
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Maps a fundraising id to the related struct.
    mapping(uint256 => Fundraise) public fundraises;

    /// @notice The total count of created fundraises.
    uint256 public totalFundraises;

    /// @notice The address of the contract managing the tier system.
    address public tierManager;

    /// @notice The address of the signer that crafts the whitelist signature.
    address public whitelistSigner;

    /// @notice Event emitted when a contribution to a fundraise is made.
    /// @param index The index of the fundraise
    /// @param sender The address that made the deposit
    /// @param amount The amount deposited
    event Deposit(uint256 indexed index, address indexed sender, uint256 indexed amount);

    /// @notice Event emitted when a fundraise is created.
    /// @param token The token raised
    /// @param beneficiary The address that will received the raised funds
    /// @param softCap The minimum amount to raise to consider the fundraise successful
    /// @param hardCap The maximum amount that can be raised
    /// @param startTime The time when the fundraise begins
    /// @param endTime The time when the fundraise ends
    event FundraiseCreated(address indexed token, address indexed beneficiary, uint256 softCap, uint256 hardCap, uint256 startTime, uint256 endTime);

    /// @notice Event emitted when a fundraise is completed and beneficiary claims the raised funds.
    /// @param index The index of the fundraise
    /// @param beneficiary The address that will received the raised funds
    /// @param amount The amount raised
    event FundraiseCompleted(uint256 indexed index, address indexed beneficiary, uint256 amount);

    /// @notice Event emitted when a refund is completed.
    /// @param index The index of the fundraise
    /// @param sender The address that will received the refunded funds
    /// @param amount The amount refunded
    event Refund(uint256 indexed index, address indexed sender, uint256 indexed amount);

    /// @notice Event emitted when a new tier manager is set.
    /// @param tierManager The new address of the tier manager
    event SetTierManager(address indexed tierManager);

    /// @notice Event emitted when a new whitelist signer is set.
    /// @param whitelistSigner The new address of the whitelist signer
    event SetWhitelistSigner(address indexed whitelistSigner);

    /// @notice Event emitted when a withdrawal is completed.
    /// @param index The index of the fundraise
    /// @param sender The address that made the withdrawal
    /// @param amount The amount withdrawn
    event Withdrawal(uint256 indexed index, address indexed sender, uint256 indexed amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Creates a Vault contract.
    /// @param _manager The address of the manager of the contract.
    /// @param _owner The address of the owner of the contract.
    /// @param _tierManager The address of the tier manager of the contract.
    /// @param _whitelistSigner The address of the whitelist signer of the contract.
    function initialize(address _manager, address _owner, address _tierManager, address _whitelistSigner) external initializer {
        require(_manager != address(0), "ADDRESS_ZERO");
        require(_owner != address(0), "ADDRESS_ZERO");
        require(_tierManager != address(0), "ADDRESS_ZERO");
        require(_whitelistSigner != address(0), "ADDRESS_ZERO");

        tierManager = _tierManager;
        whitelistSigner = _whitelistSigner;

        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        _grantRole(MANAGER_ROLE, _manager);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /// @notice Creates a new fundraise.
    /// @param _token The address of the token raised.
    /// @param _beneficiary The address that will receive the raised funds.
    /// @param _softCap The minimum amount to raise to consider the fundraise successful.
    /// @param _hardCap The maximum amount that can be raised.
    /// @param _startTime The start time when deposits open.
    /// @param _endTime The end time when deposits close.
    /// @param _whitelistEnabled If the whitelist is enabled or not.
    function createFundraise(
        address _token,
        address _beneficiary,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _startTime,
        uint256 _endTime,
        bool _whitelistEnabled
    ) external onlyRole(MANAGER_ROLE) {
        require(_token != address(0), "ADDRESS_ZERO");
        require(_beneficiary != address(0), "ADDRESS_ZERO");
        require(_softCap < _hardCap, "WRONG_CAPS");
        require(_startTime >= block.timestamp, "WRONG_TIME");
        require(_endTime >= block.timestamp, "WRONG_TIME");
        require(_startTime < _endTime, "WRONG_TIME");

        fundraises[totalFundraises].token = _token;
        fundraises[totalFundraises].beneficiary = _beneficiary;
        fundraises[totalFundraises].softCap = _softCap;
        fundraises[totalFundraises].hardCap = _hardCap;
        fundraises[totalFundraises].startTime = _startTime;
        fundraises[totalFundraises].endTime = _endTime;
        fundraises[totalFundraises].whitelistEnabled = _whitelistEnabled;
        fundraises[totalFundraises].publicFundraise.enabled = false;
        fundraises[totalFundraises].publicFundraise.minAllocation = 0;
        fundraises[totalFundraises].publicFundraise.maxAllocation = 0;
        fundraises[totalFundraises].currentAmountRaised = 0;
        fundraises[totalFundraises].completed = false;

        totalFundraises = totalFundraises + 1;

        emit FundraiseCreated(_token, _beneficiary, _softCap, _hardCap, _startTime, _endTime);
    }

    /// @notice Deposit an amount with a whitelist signature.
    /// @param _index The index of the fundraise.
    /// @param _amount The amount to deposit.
    /// @param _signature The whitelist signature generated offchain.
    function whitelistDeposit(uint256 _index, uint256 _amount, bytes calldata _signature) external nonReentrant {
        bytes32 data = keccak256(abi.encodePacked(_index, msg.sender));
        require(data.toEthSignedMessageHash().recover(_signature) == whitelistSigner, "WRONG_SIGNATURE");
        _deposit(_index, _amount);
    }

    /// @notice Deposit an amount.
    /// @param _index The index of the fundraise.
    /// @param _amount The amount to deposit.
    function deposit(uint256 _index, uint256 _amount) external nonReentrant {
        require(!fundraises[_index].whitelistEnabled, "ONLY_WHITELIST");
        _deposit(_index, _amount);
    }

    /// @notice Refund a deposit.
    /// @param _index The index of the fundraise.
    /// @param _depositAddress The address that deposited.
    function refundDeposit(uint256 _index, address _depositAddress) external nonReentrant onlyRole(MANAGER_ROLE) {
        require(!getFundraiseRunning(_index), "NOT_ENDED");
        require(!getFundraiseCompleted(_index), "FUNDS_ALREADY_WITHDRAWN");

        Fundraise storage fundraise = fundraises[_index];
        uint256 contribution = fundraise.contributions[_depositAddress];
        require(contribution > 0, "ZERO_AMOUNT");

        fundraise.contributions[_depositAddress] = 0;
        fundraise.currentAmountRaised = fundraise.currentAmountRaised - contribution;

        IERC20(fundraises[_index].token).safeTransfer(_depositAddress, contribution);

        emit Refund(_index, _depositAddress, contribution);
    }

    /// @notice Set a fundraise as completed and transfer the funds to the beneficiary.
    /// @param _index The index of the fundraise.
    function completeFundraise(uint256 _index) external nonReentrant {
        require(msg.sender == fundraises[_index].beneficiary || hasRole(MANAGER_ROLE, msg.sender), "NOT_ALLOWED");
        require(getFundraiseSuccessful(_index), "SOFT_CAP_NOT_MET");
        require(!getFundraiseRunning(_index), "NOT_ENDED");
        require(!getFundraiseCompleted(_index), "FUNDS_ALREADY_WITHDRAWN");

        IERC20(fundraises[_index].token).safeTransfer(fundraises[_index].beneficiary, fundraises[_index].currentAmountRaised);
        fundraises[_index].completed = true;

        emit FundraiseCompleted(_index, fundraises[_index].beneficiary, fundraises[_index].currentAmountRaised);
    }

    /// @notice Withdraw deposited funds from a fundraise in case the soft cap is not met.
    /// @param _index The index of the fundraise.
    function withdraw(uint256 _index) external nonReentrant {
        require(!getFundraiseSuccessful(_index), "ABOVE_SOFT_CAP");
        require(!getFundraiseRunning(_index), "NOT_ENDED");

        Fundraise storage fundraise = fundraises[_index];
        uint256 contribution = fundraise.contributions[msg.sender];
        require(contribution > 0, "ZERO_AMOUNT");

        fundraise.contributions[msg.sender] = 0;
        fundraise.currentAmountRaised = fundraise.currentAmountRaised - contribution;

        IERC20(fundraises[_index].token).safeTransfer(msg.sender, contribution);

        emit Withdrawal(_index, msg.sender, contribution);
    }

    /// @notice Set the address of the beneficiary of a fundraise.
    /// @param _index The index of the fundraise.
    /// @param _beneficiary The address of the beneficiary.
    function setBeneficiary(uint256 _index, address _beneficiary) external onlyRole(MANAGER_ROLE) {
        require(_beneficiary != address(0), "ADDRESS_ZERO");
        require(!getFundraiseCompleted(_index), "FUNDS_ALREADY_WITHDRAWN");
        fundraises[_index].beneficiary = _beneficiary;
    }

    /// @notice Set the soft and hard cap of a fundraise.
    /// @param _index The index of the fundraise.
    /// @param _softCap The minimum amount to raise to consider the fundraise successful.
    /// @param _hardCap The maximum amount that can be raised.
    function setCap(uint256 _index, uint256 _softCap, uint256 _hardCap) external onlyRole(MANAGER_ROLE) {
        require(_softCap < _hardCap, "WRONG_CAPS");
        require(_hardCap >= fundraises[_index].currentAmountRaised, "CAP_TOO_SMALL");
        fundraises[_index].softCap = _softCap;
        fundraises[_index].hardCap = _hardCap;
    }

    /// @notice Sets the parameters to open the fundraise to the public.
    /// @param _index The index of the fundraise.
    /// @param _enabled True if open to the public, false otherwise.
    /// @param _minAllocation The minimum allocation for the public.
    /// @param _maxAllocation The maximum allocation for the public.
    function setPublicFundraise(uint256 _index, bool _enabled, uint256 _minAllocation, uint256 _maxAllocation) external onlyRole(MANAGER_ROLE) {
        require(_maxAllocation >= _minAllocation, "WRONG_ALLOCATION");
        fundraises[_index].publicFundraise.enabled = _enabled;
        fundraises[_index].publicFundraise.minAllocation = _minAllocation;
        fundraises[_index].publicFundraise.maxAllocation = _maxAllocation;
    }

    /// @notice Set the start and end time of a fundraise.
    /// @param _index The index of the fundraise.
    /// @param _startTime The time when the deposits open.
    /// @param _endTime The time when the deposits end.
    function setTime(uint256 _index, uint256 _startTime, uint256 _endTime) external onlyRole(MANAGER_ROLE) {
        require(_endTime >= block.timestamp, "WRONG_TIME");
        require(_startTime < _endTime, "WRONG_TIME");
        fundraises[_index].startTime = _startTime;
        fundraises[_index].endTime = _endTime;
    }

    /// @notice Set if a fundraise should be whitelisted.
    /// @param _index The index of the fundraise.
    /// @param _whitelistEnabled True if enabled, false if disabled.
    function setWhitelist(uint256 _index, bool _whitelistEnabled) external onlyRole(MANAGER_ROLE) {
        fundraises[_index].whitelistEnabled = _whitelistEnabled;
    }

    /// @notice Set the address of the offchain whitelist signer.
    /// @param _whitelistSigner The new address of the whitelist signer.
    function setWhitelistSigner(address _whitelistSigner) external onlyRole(MANAGER_ROLE) {
        require(_whitelistSigner != address(0), "ADDRESS_ZERO");
        whitelistSigner = _whitelistSigner;
        emit SetWhitelistSigner(whitelistSigner);
    }

    /// @notice Set the address of the TierManager contract.
    /// @param _tierManager The new address of the TierManager contract.
    function setTierManager(address _tierManager) external onlyRole(MANAGER_ROLE) {
        require(_tierManager != address(0), "ADDRESS_ZERO");
        tierManager = _tierManager;
        emit SetTierManager(tierManager);
    }

    /// @notice Get the deposit of an address.
    /// @param _index The index of the fundraise.
    /// @param _contributor The address that deposited.
    /// @return The amount deposited.
    function getFundraiseContribution(uint256 _index, address _contributor) public view returns (uint256) {
        Fundraise storage fundraise = fundraises[_index];
        return fundraise.contributions[_contributor];
    }

    /// @notice Get if a fundraise is open.
    /// @param _index The index of the fundraise.
    /// @return True if deposits are open, otherwise false.
    function getFundraiseRunning(uint256 _index) public view returns (bool) {
        return fundraises[_index].startTime <= block.timestamp && fundraises[_index].endTime >= block.timestamp;
    }

    /// @notice Get if a fundraise raised more than the soft cap.
    /// @param _index The index of the fundraise.
    /// @return True if the amount is bigger than the soft cap, otherwise false.
    function getFundraiseSuccessful(uint256 _index) public view returns (bool) {
        return fundraises[_index].currentAmountRaised >= fundraises[_index].softCap;
    }

    /// @notice Get if a hard cap is met.
    /// @param _index The index of the fundraise.
    /// @return True if the hard cap is met, otherwise false.
    function getFundraiseFull(uint256 _index) public view returns (bool) {
        return fundraises[_index].currentAmountRaised == fundraises[_index].hardCap;
    }

    /// @notice Get if a fundraise is completed and if the funds were transferred out.
    /// @param _index The index of the fundraise.
    /// @return True if completed, otherwise false.
    function getFundraiseCompleted(uint256 _index) public view returns (bool) {
        return fundraises[_index].completed;
    }

    /// @notice Get if a fundraise requires a whitelist.
    /// @param _index The index of the fundraise.
    /// @return True if a whitelist is required, false otherwise.
    function getFundraiseWhitelisted(uint256 _index) public view returns (bool) {
        return fundraises[_index].whitelistEnabled;
    }

    /// @notice The logic for depositting an amount.
    /// @param _index The index of the fundraise.
    /// @param _amount The amount to deposit.
    function _deposit(uint256 _index, uint256 _amount) internal {
        require(getFundraiseRunning(_index), "NOT_OPEN");
        require(fundraises[_index].currentAmountRaised + _amount <= fundraises[_index].hardCap, "HARD_CAP");
        require(_amount > 0, "ZERO_AMOUNT");

        (uint256 minAllocation, uint256 maxAllocation) = ITierManager(tierManager).getAllocation(_index, msg.sender);
        if (fundraises[_index].publicFundraise.enabled && maxAllocation == 0) {
            // Eligible to public
            require(_amount >= fundraises[_index].publicFundraise.minAllocation, "AMOUNT_TOO_SMALL_PUBLIC");
            require(_amount <= fundraises[_index].publicFundraise.maxAllocation, "AMOUNT_TOO_BIG_PUBLIC");
        } else {
            // Tiers allocation
            require(_amount >= minAllocation, "AMOUNT_TOO_SMALL");
            require(_amount <= maxAllocation, "AMOUNT_TOO_BIG");
        }

        fundraises[_index].currentAmountRaised += _amount;
        fundraises[_index].contributions[msg.sender] += _amount;

        IERC20(fundraises[_index].token).safeTransferFrom(msg.sender, address(this), _amount);

        emit Deposit(_index, msg.sender, _amount);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}