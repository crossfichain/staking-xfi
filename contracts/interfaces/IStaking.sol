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

    /* ======== FUNCTIONS ======== */
    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function getNativeReward() external;
    function vest(uint256 amount) external;
    function compoundBP() external;
    function getUserData() external returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function exit() external;
    function emergencyWithdraw() external;
    function notifyTokenRewardAmount(uint256 reward) external;
    function notifyNativeRewardAmount(uint256 amount) external payable;
    function setTokenRewardsDuration(uint256 _duration) external;
    function setNativeRewardsDuration(uint256 _duration) external;
    function pause() external;
    function unpause() external;
    
    function balanceBPOf(address account) external view returns (uint256);
    function getScaledBalanceBPOf(address account) external view returns (uint256);
    function balanceLPOf(address account) external view returns (uint256);
    function getScaledBalanceLPOf(address account) external view returns (uint256);
    function balanceSTOf(address account) external view returns (uint256);
    function getScaledBalanceSTOf(address account) external view returns (uint256);
    function getTotalSupplyLP() external view returns (uint256);
    function getScaledTotalSupplyLP() external view returns (uint256);
    function getTotalSupplyBP() external view returns (uint256);
    function getScaledTotalSupplyBP() external view returns (uint256);
    function getTotalSupplyST() external view returns (uint256);
    function getScaledTotalSupplyST() external view returns (uint256);
    function balanceVST(address account) external view returns (uint256);
    function getScaledBalanceVST(address account) external view returns (uint256);
    function balanceVSTStored(address account) external view returns (uint256);
    function getScaledBalanceVSTStored(address account) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function lastTimeTokenRewardApplicable() external view returns (uint256);
    function lastTimeNativeRewardApplicable() external view returns (uint256);
    function getNativeMultiplier() external view returns (uint256);
    function getTokenMultiplier() external view returns (uint256);
}