// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract AirDrop is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;

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

    address public tokenAddress;
    address public platformAddress;
    address[] allocated;
    uint256 public totalAmount;
    uint256 public platformFee;
    uint256 public claimed;
    bool public vestingEnabled;
    bool public airDropEnabled;

    mapping(address => UserVestingData) public userVesting;

    event totalAllocations(uint256 _length);
    event allocationsRemoved(bool _status);
    event dropEnabled(bool status, uint256 _startTime);
    event vestingSet(uint256 _tgeBps, uint256 _cycleBps, uint256 _cycleTime);
    event airdropCancelled(bool _status);
    event tokensClaimed(address _account, uint256 _amount);
    event distributedAll(bool _status);
    event distributedByRange(uint256 _startIndx, uint256 _endIndx);

    constructor(
        address _tokenAddress,
        address _platformAddress,
        address _owner,
        uint256 _platformFee
    ) {
        transferOwnership(_owner);
        tokenAddress = _tokenAddress;
        platformAddress = _platformAddress;
        platformFee = _platformFee;
    }

    function setAllocations(
        address[] memory _users,
        uint256[] memory _totalTokens
    ) public onlyOwner {
        require(!airDropEnabled, "air drop  started");
        require(_users.length == _totalTokens.length, "length misMatched");
        for (uint256 i = 0; i < _users.length; i++) {
            if (userVesting[_users[i]].totalTokens != 0) {
                totalAmount = totalAmount - userVesting[_users[i]].totalTokens;
            }
            totalAmount += _totalTokens[i];
            userVesting[_users[i]].totalTokens = _totalTokens[i];
            allocated.push(_users[i]);
        }
        emit totalAllocations(allocated.length);
    }

    //to auto remove all allocations
    function removeAllAllocations() public onlyOwner {
        require(!airDropEnabled, "airdrop started cannot delete now");
        require(allocated.length > 0, "0 allocations");
        for (uint256 i = 0; i < allocated.length; i++) {
            address user = allocated[i];
            userVesting[user].totalTokens = 0;
            userVesting[user].claimedTokens = 0;
        }
        delete allocated;
        totalAmount = 0;
        emit allocationsRemoved(true);
    }

    function distributeAll() public onlyOwner {
        require(airDropEnabled, "air drop not started");
        require(!vestingEnabled, "cannnot distribute in vesting");
        for (uint256 i = 0; i < allocated.length; i++) {
            UserVestingData storage userData = userVesting[allocated[i]];
            uint256 claimableAmount = getUserClaimable(allocated[i]);
            if (claimableAmount > 0) {
                userData.claimedTokens = claimableAmount;
                ERC20(tokenAddress).safeTransfer(allocated[i], claimableAmount);
                claimed += claimableAmount;
            }
        }
        emit distributedAll(true);
    }

    function distributeByRange(uint256 _start, uint256 _end) public onlyOwner {
        require(airDropEnabled, "air drop not started");
        require(!vestingEnabled, "cannnot distribute in vesting");
        require(_end < allocated.length && _start < _end, "not found");
        for (uint256 i = _start; i <= _end; i++) {
            UserVestingData storage userData = userVesting[allocated[i]];
            uint256 claimableAmount = getUserClaimable(allocated[i]);
            if (claimableAmount > 0) {
                userData.claimedTokens = claimableAmount;
                ERC20(tokenAddress).safeTransfer(allocated[i], claimableAmount);
                claimed += claimableAmount;
            }
        }
        emit distributedByRange(_start, _end);
    }

    function setVesting(
        uint256 tgeBps,
        uint256 cycleBps,
        uint256 cycleTime
    ) public onlyOwner {
        require(!airDropEnabled, "air drop  started");
        vestingEnabled = true;
        schedule = VestingSchedule(0, cycleTime, tgeBps, cycleBps);
        emit vestingSet(tgeBps, cycleBps, cycleTime);
    }

    function startAirdrop(uint256 _time) public onlyOwner {
        require(!airDropEnabled, "already started");
        require(totalAmount > 0, "allocate first");
        require(_time >= block.timestamp, "cannot start in past");
        if (vestingEnabled) {
            schedule.startTime = _time;
        } else {
            schedule = VestingSchedule(_time, 0, 1000, 0);
        }
        uint256 fee = (totalAmount * platformFee) / 1000;
        ERC20(tokenAddress).safeTransferFrom(msg.sender, platformAddress, fee);
        ERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            totalAmount
        );
        airDropEnabled = true;
        emit dropEnabled(true, _time);
    }

    function cancelAirdrop() public onlyOwner {
        require(!airDropEnabled, "air drop started");
        renounceOwnership();
        emit airdropCancelled(true);
    }

    function claimTokens() external nonReentrant {
        require(airDropEnabled, "air drop not started");
        UserVestingData storage userData = userVesting[msg.sender];
        uint256 withdrawable = getUserClaimable(msg.sender);

        uint256 newClaimedAmount = userData.claimedTokens + withdrawable;
        require(
            withdrawable > 0 && newClaimedAmount <= userData.totalTokens,
            "nothing to claim"
        );

        userData.claimedTokens = newClaimedAmount;
        ERC20(tokenAddress).safeTransfer(msg.sender, withdrawable);
        claimed += withdrawable;
        emit tokensClaimed(msg.sender, withdrawable);
    }

    function getUserClaimable(address _user) public view returns (uint256) {
        UserVestingData storage userData = userVesting[_user];

        uint256 tgeReleaseAmount = (userData.totalTokens *
            schedule.initialUnlockPercentage) / 1000;
        uint256 currentTotal = 0;
        if (vestingEnabled) {
            if (block.timestamp >= schedule.startTime) {
                uint256 cycleReleaseAmount = (userData.totalTokens *
                    schedule.periodUnlockPercentage) / 1000;
                currentTotal =
                    (((block.timestamp - schedule.startTime) /
                        schedule.cycleLength) * cycleReleaseAmount) +
                    tgeReleaseAmount;
            }
        } else {
            currentTotal = tgeReleaseAmount;
        }

        uint256 withdrawable = 0;
        if (currentTotal > userData.totalTokens) {
            withdrawable = userData.totalTokens - userData.claimedTokens;
        } else {
            withdrawable = currentTotal - userData.claimedTokens;
        }
        return withdrawable;
    }

    function getUserclaimedTokens(address user) public view returns (uint256) {
        return userVesting[user].claimedTokens;
    }

    function getUserLockedTokens(address user) public view returns (uint256) {
        return userVesting[user].totalTokens - userVesting[user].claimedTokens;
    }
}
