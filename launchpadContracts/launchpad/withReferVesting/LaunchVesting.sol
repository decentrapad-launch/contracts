// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

contract LaunchVesting {
    struct VestingSchedule {
        uint256 startTime;
        uint256 cycleLength;
        uint256 initialUnlockPercentage;
        uint256 periodUnlockPercentage;
    }
    VestingSchedule public schedule;

    struct UserVestingData {
        uint256 totalTokens;
        uint256 claimedTokens;
    }

    mapping(address => UserVestingData) public userVesting;

    constructor() {}

    function setVestingSchedule(
        uint256 _startTime,
        uint256 _cycleLength,
        uint256 _initialUnlockPercentage,
        uint256 _periodUnlockPercentage
    ) internal {
        schedule.startTime = _startTime;
        schedule.cycleLength = _cycleLength;
        schedule.initialUnlockPercentage = _initialUnlockPercentage;
        schedule.periodUnlockPercentage = _periodUnlockPercentage;
    }

    function setUserData(address _user, uint256 _totalTokens) internal {
        userVesting[_user].totalTokens += _totalTokens;
        userVesting[_user].claimedTokens = 0;
    }

    function unlockTokens(address _user) internal returns (uint256) {
        UserVestingData storage userData = userVesting[_user];
        uint256 withdrawable = getUserClaimable(_user);

        uint256 newClaimedAmount = userData.claimedTokens + withdrawable;
        require(
            withdrawable > 0 && newClaimedAmount <= userData.totalTokens,
            "nothing to claim"
        );

        userData.claimedTokens = newClaimedAmount;
        return withdrawable;
    }

    function getUserClaimable(address _user) public view returns (uint256) {
        UserVestingData storage userData = userVesting[_user];

        uint256 tgeReleaseAmount = (userData.totalTokens *
            schedule.initialUnlockPercentage) / 1000;
        uint256 cycleReleaseAmount = (userData.totalTokens *
            schedule.periodUnlockPercentage) / 1000;

        uint256 currentTotal = 0;
        if (block.timestamp >= schedule.startTime) {
            currentTotal =
                (((block.timestamp - schedule.startTime) /
                    schedule.cycleLength) * cycleReleaseAmount) +
                tgeReleaseAmount;
        }

        uint256 withdrawable = 0;
        if (currentTotal > userData.totalTokens) {
            withdrawable = userData.totalTokens - userData.claimedTokens;
        } else {
            withdrawable = currentTotal - userData.claimedTokens;
        }
        return withdrawable;
    }

    function getUserclaimedTokens(
        address user
    ) external view returns (uint256) {
        return userVesting[user].claimedTokens;
    }

    function getUserLockedTokens(address user) external view returns (uint256) {
        return userVesting[user].totalTokens - userVesting[user].claimedTokens;
    }
}
