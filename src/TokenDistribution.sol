// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

/// @title TokenDistribution
/// @notice Implements cliff and linear vesting for token distribution.
/// @dev Adapted from https://github.com/abdelhamidbakhta/token-vesting-contracts.
/// @author XBorg
contract TokenDistribution is AccessControlEnumerableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    struct VestingSchedule {
        // Token to be distributed
        address token;
        // Beneficiary of tokens after they are released
        address beneficiary;
        // Cliff time of the vesting start in seconds since the UNIX epoch
        uint256 cliff;
        // Start time of the vesting period in seconds since the UNIX epoch
        uint256 start;
        // Duration of the vesting period in seconds
        uint256 duration;
        // Total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // Amount of tokens released
        uint256 released;
        // If the schedule has been revoked
        bool revoked;
    }
    
    /// @notice Manager role
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Stores all the schedule ids.
    bytes32[] public vestingSchedulesIds;

    /// @notice Maps a schedule id to the related struct.
    mapping(bytes32 => VestingSchedule) public vestingSchedules;

    /// @notice Returns the total amount vested per token.
    mapping(address => uint256) public vestingSchedulesTotalAmount;

    /// @notice Returns the amount of schedules for an address.
    mapping(address => uint256) public holdersVestingCount;

    /// @notice Event emitted when a vesting schedule is created.
    /// @param vestingScheduleId The id of the vesting schedule
    /// @param token The address of the token vested
    /// @param beneficiary The address of the beneficiary to whom vested tokens are transferred
    /// @param start The start time of the vesting period
    /// @param cliff The duration in seconds of the cliff in which tokens will begin to vest
    /// @param duration The duration in seconds of the period in which the tokens will vest
    /// @param amount The total amount of tokens to be released at the end of the vesting
    event VestingScheduleCreated(bytes32 indexed vestingScheduleId, address token, address indexed beneficiary, uint256 start, uint256 cliff, uint256 duration, uint256 indexed amount);

    /// @notice Event emitted when a vesting schedule is revoked.
    /// @param vestingScheduleId The id of the vesting schedule
    event VestingScheduleRevoked(bytes32 indexed vestingScheduleId);

    /// @notice Event emitted when owner withdraws some unallocated funds.
    /// @param token The address of the token withdrawn
    /// @param amount The amount withdrawn
    event Withdraw(address indexed token, uint256 indexed amount);

    /// @notice Event emitted when some tokens were released.
    /// @param vestingScheduleId The id of the vesting schedule
    /// @param amount The amount released
    event Release(bytes32 indexed vestingScheduleId, uint256 indexed amount);

    /// @notice Reverts if the vesting schedule does not exist or has been revoked.
    /// @param _vestingScheduleId The id of the vesting schedule
    modifier onlyIfVestingScheduleNotRevoked(bytes32 _vestingScheduleId) {
        require(!vestingSchedules[_vestingScheduleId].revoked, "REVOKED");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Creates a TokenDistribution contract.
    /// @param _manager The address of the manager of the contract.
    /// @param _owner The address of the owner of the contract.
    function initialize(address _manager, address _owner) external initializer {
        require(_manager != address(0), "ADDRESS_ZERO");
        require(_owner != address(0), "ADDRESS_ZERO");

        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        _grantRole(MANAGER_ROLE, _manager);
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
    }

    /// @notice Creates a new vesting schedule for a beneficiary.
    /// @param _token The token to distribute.
    /// @param _beneficiary The address of the beneficiary to whom vested tokens are transferred
    /// @param _start The start time of the vesting period
    /// @param _cliff The time when the first tokens will be unlocked
    /// @param _duration The duration in seconds of the period in which the tokens will vest
    /// @param _amount The total amount of tokens to be released at the end of the vesting
    function createVestingSchedule(
        address _token,
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _amount
    ) external onlyRole(MANAGER_ROLE) {
        _createVestingSchedule(_token, _beneficiary, _start, _cliff, _duration, _amount);
    }

    /// @notice Batch create vesting schedules for many addresses.
    /// @param _token The token to distribute.
    /// @param _beneficiaries The array of addresses to whom vested tokens are transferred
    /// @param _start The start time of the vesting period
    /// @param _cliff The duration in seconds of the cliff in which tokens will begin to vest
    /// @param _duration The duration in seconds of the period in which the tokens will vest
    /// @param _amounts The array of amount of tokens to be released at the end of the vesting per schedule
    function createMultipleVestingSchedules(
        address _token,
        address[] calldata _beneficiaries,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256[] calldata _amounts
    ) external onlyRole(MANAGER_ROLE) {
        require(_beneficiaries.length == _amounts.length, "WRONG_PARAMS");
        for (uint256 i = 0; i < _beneficiaries.length; i++) {
            _createVestingSchedule(_token, _beneficiaries[i], _start, _cliff, _duration, _amounts[i]);
        }
    }

    /// @notice Revokes the vesting schedule for given identifier.
    /// @param _vestingScheduleId the vesting schedule identifier
    function revoke(bytes32 _vestingScheduleId) external onlyRole(MANAGER_ROLE) nonReentrant onlyIfVestingScheduleNotRevoked(_vestingScheduleId) {
        VestingSchedule storage vestingSchedule = vestingSchedules[_vestingScheduleId];
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount > 0) {
            _release(_vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal - vestingSchedule.released;
        vestingSchedulesTotalAmount[vestingSchedule.token] = vestingSchedulesTotalAmount[vestingSchedule.token] - unreleased;
        vestingSchedule.revoked = true;

        emit VestingScheduleRevoked(_vestingScheduleId);
    }

    /// @notice Withdraw some non-allocated tokens.
    /// @param _token The address of the token
    /// @param _amount The amount to withdraw
    function withdraw(address _token, uint256 _amount) external nonReentrant onlyRole(MANAGER_ROLE) {
        require(getWithdrawableAmount(_token) >= _amount, "NOT_ENOUGH_TOKENS");
        IERC20(_token).safeTransfer(msg.sender, _amount);

        emit Withdraw(_token, _amount);
    }

    /// @notice Release an amount of tokens with an expired vesting.
    /// @param _vestingScheduleId The vesting schedule identifier
    /// @param _amount The amount to release
    function release(bytes32 _vestingScheduleId, uint256 _amount) external nonReentrant onlyIfVestingScheduleNotRevoked(_vestingScheduleId) {
        _release(_vestingScheduleId, _amount);
    }

    /// @notice Returns the number of vesting schedules associated to a beneficiary.
    /// @param _beneficiary The address of the receiver
    /// @return The number of vesting schedules
    function getVestingSchedulesCountByBeneficiary(address _beneficiary) external view returns (uint256) {
        return holdersVestingCount[_beneficiary];
    }

    /// @notice Returns the vesting schedule id at the given index.
    /// @param _index The index of the schedule
    /// @return The vesting id
    function getVestingIdAtIndex(uint256 _index) external view returns (bytes32) {
        require(_index < getVestingSchedulesCount(), "WRONG_INDEX");
        return vestingSchedulesIds[_index];
    }

    /// @notice Returns the vesting schedule information for a given holder and index.
    /// @param _holder The address of the holder
    /// @param _index The index of the schedule
    /// @return The vesting schedule structure information
    function getVestingScheduleByAddressAndIndex(address _holder, uint256 _index) external view returns (VestingSchedule memory) {
        return getVestingSchedule(computeVestingScheduleIdForAddressAndIndex(_holder, _index));
    }

    /// @notice Returns the number of vesting schedules managed by this contract.
    /// @return The number of vesting schedules
    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /// @notice Computes the vested amount of tokens for the given vesting schedule identifier.
    /// @param _vestingScheduleId The schedule id
    /// @return The vested amount
    function computeReleasableAmount(bytes32 _vestingScheduleId) external view onlyIfVestingScheduleNotRevoked(_vestingScheduleId) returns (uint256) {
        VestingSchedule storage vestingSchedule = vestingSchedules[_vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    /// @notice Returns the last vesting schedule for a given holder address.
    /// @param _holder The address of the beneficiary of the tokens
    /// @return The last schedule object
    function getLastVestingScheduleForHolder(address _holder) external view returns (VestingSchedule memory) {
        return vestingSchedules[computeVestingScheduleIdForAddressAndIndex(_holder, holdersVestingCount[_holder] - 1)];
    }

    /// @notice Computes the vesting schedule identifier for an address and an index.
    /// @param _holder The beneficiary of the tokens
    /// @param _index The index of the schedule
    function computeVestingScheduleIdForAddressAndIndex(address _holder, uint256 _index) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_holder, _index));
    }

    /// @notice Returns the vesting schedule information for a given identifier.
    /// @param _vestingScheduleId The schedule id
    /// @return The vesting schedule structure information
    function getVestingSchedule(bytes32 _vestingScheduleId) public view returns (VestingSchedule memory) {
        return vestingSchedules[_vestingScheduleId];
    }

    /// @notice Returns the amount of tokens that can be withdrawn by the owner.
    /// @param _token The token address to be withdrawn
    /// @return The amount of tokens not allocated
    function getWithdrawableAmount(address _token) public view returns (uint256) {
        return IERC20(_token).balanceOf(address(this)) - vestingSchedulesTotalAmount[_token];
    }

    /// @notice Computes the next vesting schedule identifier for a given holder address.
    /// @param _holder The address of the beneficiary of tokens
    /// @return The id of the next vesting schedule
    function computeNextVestingScheduleIdForHolder(address _holder) public view returns (bytes32) {
        return computeVestingScheduleIdForAddressAndIndex(_holder, holdersVestingCount[_holder]);
    }

    /// @notice Logic to create a vesting schedule.
    /// @dev Amount needs to be bigger than duration otherwise, due to rounding, tokens will only be available
    /// after vesting ends.
    /// @param _token The token to distribute.
    /// @param _beneficiary The address of the beneficiary to whom vested tokens are transferred
    /// @param _start The start time of the vesting period
    /// @param _cliff The duration in seconds of the cliff in which tokens will begin to vest
    /// @param _duration The duration in seconds of the period in which the tokens will vest
    /// @param _amount The total amount of tokens to be released at the end of the vesting
    function _createVestingSchedule(
        address _token,
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _amount
    ) internal {
        require(_token != address(0), "ADDRESS_ZERO");
        require(_beneficiary != address(0), "ADDRESS_ZERO");
        require(getWithdrawableAmount(_token) >= _amount, "NOT_ENOUGH_TOKENS");
        require(_duration > 0, "WRONG_DURATION");
        require(_amount > _duration, "WRONG_AMOUNT");
        require(_start >= block.timestamp, "WRONG_TIME");
        require(_duration >= _cliff, "WRONG_DURATION_CLIFF");

        bytes32 vestingScheduleId = computeNextVestingScheduleIdForHolder(_beneficiary);
        uint256 cliff = _start + _cliff;

        vestingSchedules[vestingScheduleId] = VestingSchedule(
            _token,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _amount,
            0,
            false
        );

        vestingSchedulesTotalAmount[_token] = vestingSchedulesTotalAmount[_token] + _amount;
        vestingSchedulesIds.push(vestingScheduleId);

        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount + 1;

        emit VestingScheduleCreated(vestingScheduleId, _token, _beneficiary, _start, _cliff, _duration, _amount);
    }

    /// @notice Logic to release some tokens.
    /// @param _vestingScheduleId the vesting schedule identifier
    /// @param _amount the amount to release
    function _release(bytes32 _vestingScheduleId, uint256 _amount) internal {
        VestingSchedule storage vestingSchedule = vestingSchedules[_vestingScheduleId];

        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isReleasor = hasRole(MANAGER_ROLE, msg.sender);
        require(isBeneficiary || isReleasor, "NOT_ALLOWED");

        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount >= _amount, "NOT_ENOUGH_TOKENS_RELEASED");
        require(_amount <= IERC20(vestingSchedule.token).balanceOf(address(this)), "NOT_ENOUGH_TOKENS");

        vestingSchedule.released = vestingSchedule.released + _amount;
        vestingSchedulesTotalAmount[vestingSchedule.token] = vestingSchedulesTotalAmount[vestingSchedule.token] - _amount;
        IERC20(vestingSchedule.token).safeTransfer(vestingSchedule.beneficiary, _amount);

        emit Release(_vestingScheduleId, _amount);
    }

    /// @notice Computes the releasable amount of tokens for a vesting schedule.
    /// @param _vestingSchedule The schedule to query
    /// @return The amount of releasable tokens
    function _computeReleasableAmount(VestingSchedule memory _vestingSchedule) internal view returns (uint256) {
        // Retrieve the current time.
        uint256 currentTime = _getCurrentTime();
        // If the current time is before the cliff, no tokens are releasable.
        if (currentTime < _vestingSchedule.cliff) {
            return 0;
        }
            // If the current time is after the vesting period, all tokens are releasable,
            // minus the amount already released.
        else if (currentTime >= _vestingSchedule.start + _vestingSchedule.duration) {
            return _vestingSchedule.amountTotal - _vestingSchedule.released;
        }
            // Otherwise, some tokens are releasable.
        else {
            // Compute the number of full vesting periods that have elapsed.
            uint256 timeFromStart = currentTime - _vestingSchedule.start;
            // Compute the amount of tokens that are vested.
            uint256 vestedAmount = (_vestingSchedule.amountTotal * timeFromStart) / _vestingSchedule.duration;
            // Subtract the amount already released and return.
            return vestedAmount - _vestingSchedule.released;
        }
    }

    /// @notice Returns the current time.
    /// @return The current timestamp in seconds
    function _getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}
}