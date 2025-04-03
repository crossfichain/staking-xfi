// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/security/Pausable.sol'; // Added for emergency controls

// Inheritance
import './interfaces/IStakingRewards.sol';

contract StakingRewardsNative is IStakingRewards, ERC20, Ownable, ReentrancyGuard, Pausable {
	using SafeERC20 for IERC20;

	/* ========== ERRORS ========== */
	
	error ZeroAmount();
	error RewardTooHigh();
	error NativeTransferFailed();
	error ZeroAddress();
	error InvalidRewardAmount(); // Added for input validation

	/* ========== STATE VARIABLES ========== */

	IERC20 public immutable stakingToken; // Made immutable for gas optimization

	uint256 public periodFinish;
	uint256 public rewardRate;

	uint256 public rewardsDuration = 60 days;
	uint256 public lastUpdateTime;
	uint256 public rewardPerTokenStored;

	mapping(address => uint256) public userRewardPerTokenPaid;
	mapping(address => uint256) public rewards;

	// uint256 private _totalSupply;

	/* ========== CONSTRUCTOR ========== */

	constructor(string memory _name, string memory _symbol, address _stakingToken) ERC20(_name, _symbol) {
		if (_stakingToken == address(0)) revert ZeroAddress();
		stakingToken = IERC20(_stakingToken);
	}

	/* ========== VIEWS ========== */

	function lastTimeRewardApplicable() public view returns (uint256) {
		return Math.min(block.timestamp, periodFinish);
	}

	function rewardPerToken() public view returns (uint256) {
		if (totalSupply() == 0) {
			return rewardPerTokenStored;
		}
		return
			rewardPerTokenStored + 
				((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * 1e18) / totalSupply();
	}

	function earned(address account) public view returns (uint256) {
		return
			(balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + 
				rewards[account];
	}

	function getRewardForDuration() external view returns (uint256) {
		return rewardRate * rewardsDuration;
	}

	/* ========== MUTATIVE FUNCTIONS ========== */

	function stake(uint256 amount) external nonReentrant whenNotPaused updateReward(msg.sender) {
		/* --- INPUT VALIDATION --- */
		if (amount == 0) revert ZeroAmount();

		/* --- LOGIC --- */
		stakingToken.safeTransferFrom(msg.sender, address(this), amount);
		_mint(msg.sender, amount);

		/* --- EVENT --- */
		emit Staked(msg.sender, amount);
	}

	function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
		/* --- INPUT VALIDATION --- */
		if (amount == 0) revert ZeroAmount();

		/* --- LOGIC --- */
		_burn(msg.sender, amount);
		stakingToken.safeTransfer(msg.sender, amount);

		/* --- EVENT --- */
		emit Withdrawn(msg.sender, amount);
	}

	function getReward() public nonReentrant updateReward(msg.sender) {
		/* --- LOGIC --- */
		uint256 reward = rewards[msg.sender];
		if (reward > 0) {
			rewards[msg.sender] = 0;
			
			// Use a more secure way to transfer native tokens
			(bool success, ) = payable(msg.sender).call{value: reward}("");
			if (!success) revert NativeTransferFailed();

			/* --- EVENT --- */
			emit RewardPaid(msg.sender, reward);
		}
	}

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

	receive() external payable {}

	/* ========== RESTRICTED FUNCTIONS ========== */

	/// @notice Initiates a new period of rewards distribution
	/// @param reward amount of reward tokens to add to distribution
	/// @dev Reward value must exactly match msg.value sent to contract
	function notifyRewardAmount(uint256 reward) external payable onlyOwner updateReward(address(0)) {
		// Verify reward amount matches sent ETH
		if (msg.value != reward) revert InvalidRewardAmount();

		if (block.timestamp >= periodFinish) {
			rewardRate = reward / rewardsDuration;
		} else {
			uint256 remaining = periodFinish - block.timestamp;
			uint256 leftover = remaining * rewardRate;
			rewardRate = (reward + leftover) / rewardsDuration;
		}

		// Ensure the provided reward amount is not more than the balance in the contract.
		// This keeps the reward rate in the right range, preventing overflows due to
		// very high values of rewardRate in the earned and rewardsPerToken functions;
		// Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
		uint balance = address(this).balance;
		if (rewardRate > balance / rewardsDuration) revert RewardTooHigh();

		lastUpdateTime = block.timestamp;
		periodFinish = block.timestamp + rewardsDuration;
		emit RewardAdded(reward);
	}

	/// @notice Allows owner to update rewards duration for future reward periods
	/// @param _rewardsDuration New duration in seconds
	function setRewardsDuration(uint256 _rewardsDuration) external onlyOwner {
		// Can only be updated if current period has finished
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