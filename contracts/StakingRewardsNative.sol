// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol';

import './interfaces/IStakingRewards.sol';

/// @title Native token staking rewards contract
/// @notice Manages staking and reward distribution with native blockchain currency
/// @dev Implements the IStakingRewards interface with native token rewards
contract StakingRewardsNative is IStakingRewards, ERC20, Ownable, ReentrancyGuard, Pausable {
	using SafeERC20 for IERC20;

	/* ========== ERRORS ========== */
	
	error ZeroAmount();
	error RewardTooHigh();
	error NativeTransferFailed();
	error ZeroAddress();
	error InvalidRewardAmount();

	/* ========== STATE VARIABLES ========== */

	IERC20 public immutable stakingToken;

	uint256 public periodFinish;
	uint256 public rewardRate;

	uint256 public rewardsDuration = 60 days;
	uint256 public lastUpdateTime;
	uint256 public rewardPerTokenStored;

	mapping(address => uint256) public userRewardPerTokenPaid;
	mapping(address => uint256) public rewards;

	/* ========== CONSTRUCTOR ========== */

	/// @notice Initializes the staking contract
	/// @param _name Name for the staking receipt token
	/// @param _symbol Symbol for the staking receipt token
	/// @param _stakingToken Address of the token that can be staked
	constructor(string memory _name, string memory _symbol, address _stakingToken) ERC20(_name, _symbol) {
		if (_stakingToken == address(0)) revert ZeroAddress();
		stakingToken = IERC20(_stakingToken);
	}

	/* ========== VIEWS ========== */

	/// @notice Returns the last timestamp at which rewards are applicable
	/// @return The latest timestamp that rewards apply to
	function lastTimeRewardApplicable() public view returns (uint256) {
		return Math.min(block.timestamp, periodFinish);
	}

	/// @notice Calculates the reward per token stored
	/// @return The current reward per token rate
	function rewardPerToken() public view returns (uint256) {
		if (totalSupply() == 0) {
			return rewardPerTokenStored;
		}
		return
			rewardPerTokenStored + 
				((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalSupply();
	}

	/// @notice Calculates the rewards earned by an account
	/// @param account Address to calculate rewards for
	/// @return Amount of rewards earned
	function earned(address account) public view returns (uint256) {
		return
			(balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + 
				rewards[account];
	}

	/// @notice Returns the reward amount for the full duration
	/// @return Total reward for the duration
	function getRewardForDuration() external view returns (uint256) {
		return rewardRate * rewardsDuration;
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	/// @notice Stakes tokens in the contract
	/// @param amount Amount of tokens to stake
	function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
		if (amount == 0) revert ZeroAmount();

		stakingToken.safeTransferFrom(msg.sender, address(this), amount);
		_mint(msg.sender, amount);

		emit Staked(msg.sender, amount);
	}

	/// @notice Withdraws staked tokens
	/// @param amount Amount of tokens to withdraw
	function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
		if (amount == 0) revert ZeroAmount();

		_burn(msg.sender, amount);
		stakingToken.safeTransfer(msg.sender, amount);

		emit Withdrawn(msg.sender, amount);
	}

	/// @notice Claims available rewards
	function getReward() public nonReentrant updateReward(msg.sender) {
		uint256 reward = rewards[msg.sender];
		if (reward > 0) {
			rewards[msg.sender] = 0;
			
			(bool success, ) = payable(msg.sender).call{value: reward}("");
			if (!success) revert NativeTransferFailed();

			emit RewardPaid(msg.sender, reward);
		}
	}

	/// @notice Withdraws tokens and claims rewards in a single transaction
	function exit() external {
		withdraw(balanceOf(msg.sender));
		getReward();
	}

	/// @notice Emergency withdrawal function that bypasses reward updates
	/// @dev Can be called even when contract is paused, allows users to withdraw without getting rewards
	function emergencyWithdraw() external nonReentrant {
		uint256 amount = balanceOf(msg.sender);
		if (amount > 0) {
			_burn(msg.sender, amount);
			stakingToken.safeTransfer(msg.sender, amount);
			emit EmergencyWithdrawn(msg.sender, amount);
		}
	}

	/// @notice Allows the contract to receive native tokens
	receive() external payable {}

	/* ========== RESTRICTED FUNCTIONS ========== */

	/// @notice Initiates a new period of rewards distribution
	/// @param reward Amount of reward tokens to distribute
	/// @dev Reward value must exactly match msg.value sent to contract
	function notifyRewardAmount(uint256 reward) external payable onlyOwner updateReward(address(0)) {
		if (msg.value != reward) revert InvalidRewardAmount();

		if (block.timestamp >= periodFinish) {
			rewardRate = reward / rewardsDuration;
		} else {
			uint256 remaining = periodFinish - block.timestamp;
			uint256 leftover = remaining * rewardRate;
			rewardRate = (reward + leftover) / rewardsDuration;
		}

		uint balance = address(this).balance;
		if (rewardRate > balance / rewardsDuration) revert RewardTooHigh();

		lastUpdateTime = block.timestamp;
		periodFinish = block.timestamp + rewardsDuration;
		emit RewardAdded(reward);
	}

	/// @notice Updates the rewards duration for future reward periods
	/// @param _rewardsDuration New duration in seconds
	function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
		require(block.timestamp > periodFinish, "Previous rewards period must be complete");
		rewardsDuration = _rewardsDuration;
		emit RewardsDurationUpdated(_rewardsDuration);
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

	/// @notice Updates rewards before executing a function
	/// @param account Address to update rewards for
	modifier updateReward(address account) {
		rewardPerTokenStored = rewardPerToken();
		lastUpdateTime = lastTimeRewardApplicable();

		if (account != address(0)) {
			rewards[account] = earned(account);
			userRewardPerTokenPaid[account] = rewardPerTokenStored;
		}
		_;
	}

	/* ========== EVENTS ========== */

	event RewardAdded(uint256 reward);
	event Staked(address indexed user, uint256 amount);
	event Withdrawn(address indexed user, uint256 amount);
	event RewardPaid(address indexed user, uint256 reward);
	event EmergencyWithdrawn(address indexed user, uint256 amount);
	event RewardsDurationUpdated(uint256 newDuration);
}