// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IDecentrapadLaunchWOReferLpVesting {
    enum PoolStatus {
        ACTIVE,
        CANCELED,
        COMPLETED
    }

    event UserInvestment(address indexed user, uint256 amount);

    event TokensBought(address user, uint256 amount);
    event tokensClaimed(address user, uint256 amount, PoolStatus);
    event poolCancelled(address user);

    function buyTokens(uint256 paymentAmount) external payable;

    function userClaim() external;

    function finalizeLaunch() external;

    function cancelPool() external;
}
