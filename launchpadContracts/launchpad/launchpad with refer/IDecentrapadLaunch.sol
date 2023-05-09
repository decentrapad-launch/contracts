// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IDecentrapadLaunch {
    enum PoolStatus {
        ACTIVE,
        CANCELED,
        COMPLETED
    }

    event TokensBought(address user, address refferal, uint256 amount);
    event tokensClaimed(address user, uint256 amount, PoolStatus);
    event poolCanceled(PoolStatus status);
    event ReferRewardsClaimed(address user, uint256 amount);
    event affiliateEnabled(uint256 ratio);
    event claimTimeAdded(uint256 newClaimTime);
    event poolFinalized(uint256 totalRaised);
    event whitelistStatus(bool _status, uint256 _publicTime);

    function buyTokens(
        address referAddress,
        uint256 paymentAmount
    ) external payable;

    function userClaim() external;

    function finalizeLaunch() external;

    function claimReferReward() external;

    function cancelPool() external;
}
