// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol'; // Added for emergency controls

/// @title Complicated staking contract
/// @author Monty C. Python
contract Staking is Ownable, ReentrancyGuard, ERC20, Pausable {
	using SafeERC20 for IERC20;

	/* ========== ERRORS ========== */
	
	error ZeroAmount();
	error InsufficientBalance();
	error NativeTransferFailed();
	error RewardTooHigh();
	error InsufficientLP();
	error ZeroAddress();

	/* ========== CONSTANTS ========== */

	uint256 public constant AMOUNT_MULTIPLIER = 1e4;
	uint256 public constant INIT_MULTIPLIER_VALUE = 1e30;
	uint8 public constant VESTING_CONST = 1e1;
	uint256 public constant ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;

	/* ========== STATE VARIABLES ========== */

	IERC20 public immutable stakingToken;
	IERC20 public immutable rewardsToken;

	uint256 public tokenPeriodFinish; // finish of tokens earning
	uint256 public tokenRewardRate; // how many tokens are given to pool every second
	uint256 public tokenRewardsDuration = 60 days;

	uint256 public nativePeriodFinish;
	uint256 public nativeRewardRate;
	uint256 public nativeRewardsDuration = 60 days;

	uint256 public lastNativeUpdateTime;
	uint256 public lastTokenUpdateTime;

	struct UserVariables {
		uint256 userTokenMultiplierPaid;
		uint256 userNativeMultiplierPaid;
		uint256 userLastUpdateTime;
		uint256 balanceLP;
		uint256 balanceST;
		uint256 balanceBP;
		uint256 balanceNC;
		uint256 balanceVST;
		uint256 balanceVSTStored;
		uint256 rewards;
		uint256 vestingFinishTime;
	}

	mapping(address => UserVariables) public userVariables;

	uint256 public _totalSupplyLP;
	uint256 public _totalSupplyBP;
	uint256 public _totalSupplyST;

	uint256 public nativeMultiplierStored = INIT_MULTIPLIER_VALUE;
	uint256 public tokenMultiplierStored = INIT_MULTIPLIER_VALUE; // Fixed: Initialize to same value as nativeMultiplierStored

	/* ========== CONSTRUCTOR ========== */

	constructor(
		address _rewardsDistribution,
		address _rewardsToken,
		address _stakingToken,
		string memory _name,
		string memory _symbol
	) ERC20(_name, _symbol) {
		if (_rewardsToken == address(0) || _stakingToken == address(0) || _rewardsDistribution == address(0)) 
			revert ZeroAddress();
			
		rewardsToken = IERC20(_rewardsToken);
		stakingToken = IERC20(_stakingToken);
		transferOwnership(_rewardsDistribution);
	}

	/* ========== VIEWS FOR EXTERNAL USE ========== */

	function balanceBPOf(address account) external view returns (uint256) {
		return userVariables[account].balanceBP / AMOUNT_MULTIPLIER;
	}

	function balanceLPOf(address account) external view returns (uint256) {
		return userVariables[account].balanceLP / AMOUNT_MULTIPLIER;
	}

	function balanceSTOf(address account) external view returns (uint256) {
		return userVariables[account].balanceST / AMOUNT_MULTIPLIER;
	}

	function totalSupplyLP() external view returns (uint256) {
		return _totalSupplyLP / AMOUNT_MULTIPLIER;
	}

	function totalSupplyBP() external view returns (uint256) {
		return _totalSupplyBP / AMOUNT_MULTIPLIER;
	}

	function totalSupplyST() external view returns (uint256) {
		return _totalSupplyST / AMOUNT_MULTIPLIER;
	}

	/* ========== VIEWS FOR CONTRACT ========== */

	/// @notice Returns the latest time at which token rewards are still applicable
	/// @return Latest applicable timestamp for token rewards
	function lastTimeTokenRewardApplicable() public view returns (uint256) {
		return Math.min(block.timestamp, tokenPeriodFinish);
	}

	/// @notice Returns the latest time at which native rewards are still applicable
	/// @return Latest applicable timestamp for native rewards
	function lastTimeNativeRewardApplicable() public view returns (uint256) {
		return Math.min(block.timestamp, nativePeriodFinish);
	}

	/// @notice Calculates the current native multiplier value
	/// @return Current native multiplier value
	function getNativeMultiplier() public view returns (uint256) {
		if (_totalSupplyLP + _totalSupplyST + _totalSupplyBP == 0) {
			return nativeMultiplierStored;
		}

		uint256 timeDiff = lastTimeNativeRewardApplicable() - lastNativeUpdateTime;
		uint256 totalShares = _totalSupplyLP + _totalSupplyBP + _totalSupplyST;

		return nativeMultiplierStored + (nativeMultiplierStored * timeDiff * nativeRewardRate) / totalShares;
	}

	function getTokenMultiplier() public view returns (uint256) {
		if (_totalSupplyLP + _totalSupplyST + _totalSupplyBP == 0) {
			return tokenMultiplierStored;
		}

		uint256 timeDiff = lastTimeTokenRewardApplicable() - lastTokenUpdateTime;
		uint256 totalShares = _totalSupplyLP + _totalSupplyBP + _totalSupplyST;

		// Fixed: Using tokenMultiplierStored instead of nativeMultiplierStored
		return tokenMultiplierStored + (tokenMultiplierStored * timeDiff * tokenRewardRate) / totalShares;
	}

	function tokenEarned(address account) internal view returns (uint256) {
		UserVariables storage variables = userVariables[account];

		uint256 userShares = variables.balanceLP + variables.balanceBP + variables.balanceST;
		uint256 multiplierDiff = getTokenMultiplier() - variables.userTokenMultiplierPaid;
		uint256 divider = Math.max(variables.userNativeMultiplierPaid, INIT_MULTIPLIER_VALUE);

		return (userShares * multiplierDiff) / divider;
	}

	function nativeEarned(address account) internal view returns (uint256) {
		UserVariables storage variables = userVariables[account];

		uint256 userShares = variables.balanceLP + variables.balanceBP + variables.balanceST;

		uint256 multiplierDiff = getNativeMultiplier();

		uint256 divider = Math.max(variables.userNativeMultiplierPaid, INIT_MULTIPLIER_VALUE);

		return (userShares * multiplierDiff) / divider;
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	/// @notice Stakes tokens into the contract
	/// @param amount Amount of tokens to stake
	/// @dev Tokens are transferred from the user to the contract
	function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
		if (amount == 0) revert ZeroAmount();

		stakingToken.safeTransferFrom(msg.sender, address(this), amount);
		_mint(msg.sender, amount);

		amount *= AMOUNT_MULTIPLIER;
		userVariables[msg.sender].balanceLP += amount;
		_totalSupplyLP += amount;

		emit Staked(msg.sender, amount / AMOUNT_MULTIPLIER);
	}

	/// @notice Claims native rewards accumulated by the user
	/// @dev Native tokens are sent directly to the user's address
	function getNativeReward() public nonReentrant updateReward(msg.sender) {
		UserVariables storage variables = userVariables[msg.sender];

		uint256 reward = variables.balanceNC;

		if (reward > 0) {
			variables.balanceNC = 0;

			(bool sent, ) = msg.sender.call{value: reward / AMOUNT_MULTIPLIER}('');

			if (!sent) revert NativeTransferFailed();

			emit NativeRewardPaid(msg.sender, reward / AMOUNT_MULTIPLIER);
		}
	}

	/// @notice Withdraws staked tokens from the contract
	/// @param amount Amount of tokens to withdraw
	/// @dev Burns user's staking tokens and returns the original tokens
	function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
		if (amount == 0) revert ZeroAmount();
		if (balanceOf(msg.sender) < amount) revert InsufficientBalance();
		
		_burn(msg.sender, amount);

		UserVariables storage variables = userVariables[msg.sender];

		variables.balanceLP -= amount * AMOUNT_MULTIPLIER;
		_totalSupplyLP -= amount * AMOUNT_MULTIPLIER;

		_totalSupplyBP -= variables.balanceBP;
		variables.balanceBP = 0;

		stakingToken.safeTransfer(msg.sender, amount);

		emit Withdrawn(msg.sender, amount);
	}

	/// @notice Claims token rewards accumulated by the user
	/// @dev Token rewards are transferred to the user's address
	function getReward() public nonReentrant updateReward(msg.sender) {
		uint256 reward = userVariables[msg.sender].rewards;

		if (reward > 0) {
			userVariables[msg.sender].rewards = 0;

			rewardsToken.safeTransfer(msg.sender, reward / AMOUNT_MULTIPLIER);
			emit TokenRewardPaid(msg.sender, reward / AMOUNT_MULTIPLIER);
		}
	}

	/// @notice Converts staking tokens to vesting tokens
	/// @param amount Amount of tokens to vest
	/// @dev User's vesting period is reset when this function is called
	function vest(uint amount) public nonReentrant updateReward(msg.sender) {
		amount *= AMOUNT_MULTIPLIER;

		if (amount == 0) revert ZeroAmount();

		UserVariables storage variables = userVariables[msg.sender];
		uint256 balance = variables.balanceST;

		if (amount > balance) revert InsufficientBalance();
		if (amount * VESTING_CONST > variables.balanceLP) revert InsufficientLP();

		variables.balanceST -= amount;
		_totalSupplyST -= amount;

		variables.balanceVST -= variables.balanceVSTStored;
		variables.balanceVST += amount;

		variables.vestingFinishTime = block.timestamp + ONE_YEAR_IN_SECS;

		emit Vesting(msg.sender, amount / AMOUNT_MULTIPLIER);
	}

	/// @notice Compounds bonus points into LP tokens
	/// @dev Converts user's accumulated bonus points into additional LP tokens
	function compoundBP() external updateReward(msg.sender) {
		UserVariables storage variables = userVariables[msg.sender];
		
		// Reinvest bonus points back into LP balance
		uint256 bonusPoints = variables.balanceBP;
		if (bonusPoints > 0) {
			// Convert bonus points to LP tokens
			variables.balanceLP += bonusPoints;
			_totalSupplyLP += bonusPoints;
			
			// Reset bonus points
			variables.balanceBP = 0;
			_totalSupplyBP -= bonusPoints;
			
			emit BonusPointsCompounded(msg.sender, bonusPoints / AMOUNT_MULTIPLIER);
		}
	}

	/// @notice returns data about user rewards for front-end, supposed to be called via staticCall
	function getUserData()
		external
		updateReward(msg.sender)
		returns (uint256, uint256, uint256, uint256, uint256, uint256)
	{
		UserVariables storage userCurrentVariables = userVariables[msg.sender];

		return (
			userCurrentVariables.balanceLP / AMOUNT_MULTIPLIER,
			userCurrentVariables.balanceBP / AMOUNT_MULTIPLIER,
			userCurrentVariables.balanceNC / AMOUNT_MULTIPLIER,
			userCurrentVariables.balanceST / AMOUNT_MULTIPLIER,
			userCurrentVariables.balanceVST / AMOUNT_MULTIPLIER,
			userVariables[msg.sender].rewards / AMOUNT_MULTIPLIER
		);
	}

	function exit() external {
		withdraw(userVariables[msg.sender].balanceLP / AMOUNT_MULTIPLIER);
		getReward();
	}

	/// @notice Emergency withdrawal function that bypasses reward updates
	/// @dev Can be called even when contract is paused
	function emergencyWithdraw() external nonReentrant {
		UserVariables storage variables = userVariables[msg.sender];
		uint256 amount = variables.balanceLP / AMOUNT_MULTIPLIER;
		
		if (amount > 0) {
			_burn(msg.sender, amount);
			
			variables.balanceLP = 0;
			_totalSupplyLP -= amount * AMOUNT_MULTIPLIER;
			
			_totalSupplyBP -= variables.balanceBP;
			variables.balanceBP = 0;
			
			stakingToken.safeTransfer(msg.sender, amount);
			emit EmergencyWithdrawn(msg.sender, amount);
		}
	}

	/* ========== RESTRICTED FUNCTIONS ========== */

	function notifyTokenRewardAmount(uint256 reward) external onlyOwner updateReward(address(0)) {
		if (block.timestamp >= tokenPeriodFinish) {
			tokenRewardRate = (reward * AMOUNT_MULTIPLIER) / tokenRewardsDuration;
		} else {
			uint256 remaining = tokenPeriodFinish - block.timestamp;
			uint256 leftover = remaining * tokenRewardRate;
			tokenRewardRate = (reward * AMOUNT_MULTIPLIER + leftover) / tokenRewardsDuration;
		}

		uint balance = rewardsToken.balanceOf(address(this));
		if (tokenRewardRate > (balance * AMOUNT_MULTIPLIER) / tokenRewardsDuration) revert RewardTooHigh();

		lastTokenUpdateTime = block.timestamp;

		tokenPeriodFinish = block.timestamp + tokenRewardsDuration;
		emit TokenRewardAdded(reward);
	}

	function notifyNativeRewardAmount(uint256 amount) external payable onlyOwner updateReward(address(0)) {
		// Verify reward amount matches sent ETH
		require(msg.value == amount, "Reward amount must match sent value");
		
		if (block.timestamp >= nativePeriodFinish) {
			nativeRewardRate = (amount * AMOUNT_MULTIPLIER) / nativeRewardsDuration;
		} else {
			uint256 remaining = nativePeriodFinish - block.timestamp;
			uint256 leftover = remaining * nativeRewardRate;
			nativeRewardRate = (amount * AMOUNT_MULTIPLIER + leftover) / nativeRewardsDuration;
		}

		uint balance = address(this).balance;
		if (nativeRewardRate > (balance * AMOUNT_MULTIPLIER) / nativeRewardsDuration) revert RewardTooHigh();

		lastNativeUpdateTime = block.timestamp;
		nativePeriodFinish = block.timestamp + nativeRewardsDuration;
		emit NativeRewardAdded(amount);
	}

	/// @notice Sets the duration for token rewards
	/// @param _duration New duration in seconds
	function setTokenRewardsDuration(uint256 _duration) external onlyOwner {
		require(block.timestamp > tokenPeriodFinish, "Previous rewards period must be complete");
		tokenRewardsDuration = _duration;
		emit TokenRewardsDurationUpdated(_duration);
	}

	/// @notice Sets the duration for native rewards
	/// @param _duration New duration in seconds
	function setNativeRewardsDuration(uint256 _duration) external onlyOwner {
		require(block.timestamp > nativePeriodFinish, "Previous rewards period must be complete");
		nativeRewardsDuration = _duration;
		emit NativeRewardsDurationUpdated(_duration);
	}

	/// @notice Pauses the contract, preventing staking but allowing withdrawals
	function pause() external onlyOwner {
		_pause();
	}

	/// @notice Unpauses the contract, allowing staking again
	function unpause() external onlyOwner {
		_unpause();
	}

	/* ========== MODIFIERS ========== */

	modifier updateReward(address account) {
		UserVariables storage variables = userVariables[account];

		updateStoredVariables();

		uint256 _lastTimeNativeRewardApplicable = lastTimeNativeRewardApplicable();

		if (_totalSupplyLP != 0) {
			_totalSupplyST +=
				(_lastTimeNativeRewardApplicable - Math.min(_lastTimeNativeRewardApplicable, lastNativeUpdateTime)) *
				nativeRewardRate;
		}

		lastNativeUpdateTime = _lastTimeNativeRewardApplicable;
		lastTokenUpdateTime = lastTimeTokenRewardApplicable();

		if (account != address(0)) {
			updateUserVariables(account);

			updateBonusPoints(account);
			updateVesting(account);

			variables.userLastUpdateTime = block.timestamp;
		}

		_;
	}

	function updateUserVariables(address account) internal {
		UserVariables storage variables = userVariables[account];

		variables.rewards += tokenEarned(account);
		variables.balanceST = nativeEarned(account) - variables.balanceLP - variables.balanceBP;

		variables.userTokenMultiplierPaid = tokenMultiplierStored;
		variables.userNativeMultiplierPaid = nativeMultiplierStored;
	}

	function updateStoredVariables() internal {
		tokenMultiplierStored = getTokenMultiplier();
		nativeMultiplierStored = getNativeMultiplier();
	}

	function updateBonusPoints(address account) internal {
		UserVariables storage variables = userVariables[account];

		if (variables.userLastUpdateTime == 0) return;

		uint256 increaseOfBP = ((block.timestamp - variables.userLastUpdateTime) * variables.balanceLP) /
			ONE_YEAR_IN_SECS;

		_totalSupplyBP += increaseOfBP;
		variables.balanceBP += increaseOfBP;
	}

	function updateVesting(address account) internal {
		UserVariables storage variables = userVariables[account];

		if (Math.min(block.timestamp, variables.vestingFinishTime) < variables.userLastUpdateTime) {
			return;
		}

		uint256 increaseOfNC = ((Math.min(block.timestamp, variables.vestingFinishTime) -
			variables.userLastUpdateTime) *
			Math.min(variables.balanceVST, variables.balanceLP / VESTING_CONST)) / ONE_YEAR_IN_SECS;

		variables.balanceNC += increaseOfNC;
		variables.balanceVSTStored += increaseOfNC;
	}

	/* ========== EVENTS ========== */

	event TokenRewardAdded(uint256 reward);
	event NativeRewardAdded(uint256 reward);
	event Staked(address indexed user, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event TokenRewardPaid(address indexed user, uint256 reward);
	event NativeRewardPaid(address indexed user, uint256 reward);
	event Vesting(address indexed user, uint256 reward);
	event BonusPointsCompounded(address indexed user, uint256 amount);
	event EmergencyWithdrawn(address indexed user, uint256 amount);
	event TokenRewardsDurationUpdated(uint256 newDuration);
	event NativeRewardsDurationUpdated(uint256 newDuration);
}