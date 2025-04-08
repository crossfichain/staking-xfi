// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IStaking {
    /* ======== ERRORS ======== */
    error ZeroAmount();
    error InsufficientBalance();
    error NativeTransferFailed();
    error RewardTooHigh();
    error InsufficientLP();
    error ZeroAddress();
    error IncompletePrevRewardsPeriod();
    error InvalidRewardAmount();

    /* ======== EVENTS ======== */
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
