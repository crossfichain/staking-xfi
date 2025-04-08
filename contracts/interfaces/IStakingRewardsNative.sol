// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IStakingRewardsNative {
    /* ======== ERRORS ======== */
    error ZeroAmount();
    error NativeTransferFailed();
    error RewardTooHigh();
    error ZeroAddress();
    error IncompletePrevRewardsPeriod();
    error InvalidRewardAmount();

    /* ======== EVENTS ======== */
    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event EmergencyWithdrawn(address indexed user, uint256 amount);
    event RewardsDurationUpdated(uint256 newDuration);

    /* ======== FUNCTIONS ======== */
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function exit() external;
    function emergencyWithdraw() external;
    function notifyRewardAmount(uint256 reward) external payable;
    function setRewardsDuration(uint256 _rewardsDuration) external;
    function pause() external;
    function unpause() external;
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function getRewardForDuration() external view returns (uint256);
}