// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IDecentrapadLaunch.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DecentrapadLaunch is Ownable, IDecentrapadLaunch, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    struct launchSaleInfo {
        address tokenAddress;
        address paymentToken;
        uint256 tokensForSale;
        uint256 softCap;
        uint256 hardCap;
        uint256 presaleRate;
        uint256 startTime;
        uint256 endTime;
        uint256 minBuyLimit;
        uint256 maxBuyLimit;
        uint256 referRatio;
        bool burnRemainingTokens;
    }

    struct launchPoolData {
        uint256 totalRaised;
        uint256 totalTokensClaimed;
        PoolStatus status;
    }

    struct poolFee {
        uint256 nativeFee;
        uint256 tokenFee;
    }

    launchPoolData public poolData;
    launchSaleInfo public launchInfo;
    poolFee public poolFees;

    mapping(address => uint256) public UserInvestments;
    mapping(address => uint256) referComission;
    mapping(address => bool) public whitelistUsers;

    address public platformAddress;
    address deadAddress = 0x000000000000000000000000000000000000dEaD;
    uint256 public platformFee;
    uint256 claimTime;
    uint256 PublicStartTime;
    uint256 constant base = 1000;
    uint256 constant earlyClaimFee = 100;
    uint256 totalRefferal;
    uint256 referReward;

    bool whitelistEnabled;
    bool referRewardStatus;
    bool delayClaim;

    constructor(
        launchSaleInfo memory _launchInfo,
        poolFee memory _poolFees,
        address owner,
        address _platform,
        bool _whitelistEnabled,
        bool _referRewardStatus
    ) {
        transferOwnership(owner);
        launchInfo = _launchInfo;
        poolFees = _poolFees;
        poolData.status = PoolStatus.ACTIVE;
        platformAddress = _platform;
        whitelistEnabled = _whitelistEnabled;
        referRewardStatus = _referRewardStatus;
    }

    function updateWhitelistData(
        address[] memory _users,
        bool status
    ) external onlyOwner {
        require(_users.length > 0, "no addresses");

        for (uint256 indx = 0; indx < _users.length; indx++) {
            whitelistUsers[_users[indx]] = status;
        }
    }

    function updateEndTime(uint64 newendTime) public onlyOwner {
        require(
            newendTime > launchInfo.startTime && newendTime > block.timestamp,
            "Sale end can't be less than sale start"
        );
        launchInfo.endTime = newendTime;
    }

    function disableWhitelist(uint256 _time) external onlyOwner {
        require(whitelistEnabled, "wl not enabled");
        require(poolData.status == PoolStatus.ACTIVE, "not active");
        require(block.timestamp < launchInfo.endTime, "Sale ended");
        require(_time < launchInfo.endTime, "invalid time");
        whitelistEnabled = false;
        PublicStartTime = _time;
        emit whitelistStatus(false, _time);
    }

    function enableWhitelist() external onlyOwner {
        require(!whitelistEnabled, "wl not enabled");
        require(poolData.status == PoolStatus.ACTIVE, "not active");
        require(block.timestamp < launchInfo.endTime, "Sale ended");
        whitelistEnabled = true;
        emit whitelistStatus(true, 0);
    }

    function buyTokens(
        address referAddress,
        uint256 paymentAmount
    ) external payable nonReentrant {
        require(poolData.status == PoolStatus.ACTIVE, "not active");
        if (whitelistEnabled) {
            require(whitelistUsers[msg.sender], "not wl");
        } else if (!whitelistEnabled) {
            if (PublicStartTime > block.timestamp) {
                require(whitelistUsers[msg.sender], "not wl");
            }
        }
        require(
            block.timestamp >= launchInfo.startTime &&
                block.timestamp < launchInfo.endTime,
            "Cannot buy atm"
        );
        require(
            paymentAmount >= launchInfo.minBuyLimit &&
                (UserInvestments[msg.sender].add(paymentAmount)) <=
                launchInfo.maxBuyLimit,
            "Invalid Amount sent"
        );
        require(
            poolData.totalRaised.add(paymentAmount) <= launchInfo.hardCap,
            "Exceeds max cap"
        );

        transferFromHelper(
            launchInfo.paymentToken,
            msg.sender,
            address(this),
            paymentAmount
        );
        UserInvestments[msg.sender] += paymentAmount;

        poolData.totalRaised = poolData.totalRaised.add(paymentAmount);

        if (referRewardStatus) {
            require(msg.sender != referAddress, "Cannot refer itself");
            if (referAddress != address(0)) {
                referComission[referAddress] += paymentAmount;
                totalRefferal += paymentAmount;
            }
        }
        emit TokensBought(msg.sender, referAddress, paymentAmount);
    }

    function userClaim() external nonReentrant {
        uint256 userContribution = UserInvestments[msg.sender];
        require(userContribution > 0, "zero contribution");
        uint256 claimedAmount;

        if (poolData.status == PoolStatus.ACTIVE) {
            require(
                !referRewardStatus,
                "Cannot claim early due to refer rewards"
            );
            if (poolData.totalRaised < launchInfo.softCap) {
                uint256 earlyClaimPenalty = userContribution
                    .mul(earlyClaimFee)
                    .div(base);
                uint256 remainingContribution = userContribution.sub(
                    earlyClaimPenalty
                );

                UserInvestments[msg.sender] = 0;
                poolData.totalRaised -= userContribution;

                transferHelper(
                    launchInfo.paymentToken,
                    platformAddress,
                    earlyClaimPenalty
                );
                transferHelper(
                    launchInfo.paymentToken,
                    msg.sender,
                    remainingContribution
                );
                claimedAmount = remainingContribution;
            } else {
                revert("Cannot claim");
            }
        } else if (poolData.status == PoolStatus.CANCELED) {
            UserInvestments[msg.sender] = 0;
            poolData.totalRaised -= userContribution;

            transferHelper(
                launchInfo.paymentToken,
                msg.sender,
                userContribution
            );
            claimedAmount = userContribution;
        } else if (poolData.status == PoolStatus.COMPLETED) {
            if (delayClaim) {
                require(
                    claimTime < block.timestamp,
                    "cannot claim before time"
                );
            }
            uint256 minAmountReceives = calculateAmount(
                launchInfo.paymentToken,
                userContribution,
                launchInfo.presaleRate
            );
            UserInvestments[msg.sender] = 0;

            transferHelper(
                launchInfo.tokenAddress,
                msg.sender,
                minAmountReceives
            );
            poolData.totalTokensClaimed += minAmountReceives;
            claimedAmount = minAmountReceives;
        }
        emit tokensClaimed(msg.sender, claimedAmount, poolData.status);
    }

    function finalizePlatformFees(
        uint256 _amountRaised
    ) public returns (uint256, uint256) {
        uint256 paymentShareFee;
        uint256 tokenShareFee;
        paymentShareFee = calculatePlatformShare(
            _amountRaised,
            poolFees.nativeFee
        );
        transferHelper(
            launchInfo.paymentToken,
            platformAddress,
            paymentShareFee
        );

        if (poolFees.tokenFee > 0) {
            uint256 tokenSold = calculateAmount(
                launchInfo.paymentToken,
                _amountRaised,
                launchInfo.presaleRate
            );
            tokenShareFee = calculatePlatformShare(
                tokenSold,
                poolFees.tokenFee
            );
            transferHelper(
                launchInfo.tokenAddress,
                platformAddress,
                tokenShareFee
            );
        }
        return (paymentShareFee, tokenShareFee);
    }

    function calculatePlatformShare(
        uint256 _amountRaised,
        uint256 _platformFee
    ) public pure returns (uint256) {
        uint256 platformFeeAmount = _amountRaised.mul(_platformFee).div(base);
        return platformFeeAmount;
    }

    function finalizeLaunch() external onlyOwner {
        require(
            block.timestamp >= launchInfo.endTime ||
                poolData.totalRaised == launchInfo.hardCap,
            "Sale nt ended nor HC reached"
        );
        require(poolData.status == PoolStatus.ACTIVE, "Already finalized");
        require(
            poolData.totalRaised >= launchInfo.softCap,
            "not exceed softcap"
        );

        poolData.status = PoolStatus.COMPLETED;
        uint256 totalAmountRaised = poolData.totalRaised;
        uint256 nativePlatformShare;
        uint256 tokenPlatformShare;

        (nativePlatformShare, tokenPlatformShare) = finalizePlatformFees(
            totalAmountRaised
        );

        uint256 raisedAfterPlatformFee = totalAmountRaised.sub(
            nativePlatformShare
        );

        if (referRewardStatus && totalRefferal > 0) {
            referReward = raisedAfterPlatformFee.mul(launchInfo.referRatio).div(
                    base
                );
        }

        uint256 raisedAfterReferRewards = raisedAfterPlatformFee.sub(
            referReward
        );

        transferHelper(
            launchInfo.paymentToken,
            msg.sender,
            raisedAfterReferRewards
        );

        uint256 remainingTokens = leftoverSaleTokens(
            totalAmountRaised,
            tokenPlatformShare
        );
        if (remainingTokens > 0) {
            if (launchInfo.burnRemainingTokens) {
                transferHelper(
                    launchInfo.tokenAddress,
                    deadAddress,
                    remainingTokens
                );
            } else {
                transferHelper(
                    launchInfo.tokenAddress,
                    owner(),
                    remainingTokens
                );
            }
        }
        emit poolFinalized(totalAmountRaised);
    }

    function leftoverSaleTokens(
        uint256 _amountRaised,
        uint256 _tokenPlatformShare
    ) public view returns (uint256) {
        uint256 scale;
        if (launchInfo.paymentToken != address(0)) {
            uint256 decimals = ERC20(launchInfo.paymentToken).decimals();
            scale = 10 ** decimals;
        } else {
            scale = 10 ** 18;
        }
        uint256 saleTokensSold = (_amountRaised.mul(launchInfo.presaleRate))
            .div(scale);
        uint256 totalTokens = saleTokensSold.add(_tokenPlatformShare);

        uint256 saleTokenBalance = launchInfo.tokensForSale;
        return saleTokenBalance.sub(totalTokens);
    }

    function claimReferReward() external nonReentrant {
        require(referRewardStatus, "Refer reward not exists");
        require(
            poolData.status == PoolStatus.COMPLETED,
            "pool didn't completed yet"
        );

        uint256 userReward = referComissionAmount(msg.sender);
        require(userReward > 0, "zero reward");
        referComission[msg.sender] = 0;

        transferHelper(launchInfo.paymentToken, msg.sender, userReward);

        emit ReferRewardsClaimed(msg.sender, userReward);
    }

    function enableAffilateReward(uint256 _ratio) external onlyOwner {
        require(poolData.status == PoolStatus.ACTIVE, "not active");
        require(_ratio > launchInfo.referRatio && _ratio <= 100, "ratio error");
        require(launchInfo.endTime > block.timestamp, "ended");
        referRewardStatus = true;
        launchInfo.referRatio = _ratio;
        emit affiliateEnabled(_ratio);
    }

    function enableClaimDelay(uint256 _time) external onlyOwner {
        require(launchInfo.endTime > block.timestamp, "sale ended");
        require(launchInfo.endTime < _time, "cant be less than end time");
        require(poolData.status == PoolStatus.ACTIVE, "not active");
        delayClaim = true;
        claimTime = _time;
        emit claimTimeAdded(_time);
    }

    function transferFromHelper(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (token != address(0)) {
            ERC20(token).safeTransferFrom(from, to, amount);
        } else {
            require(msg.value == amount, "Insufficient ETH sent");
        }
    }

    function transferHelper(
        address token,
        address to,
        uint256 amount
    ) internal {
        if (token != address(0)) {
            ERC20(token).safeTransfer(to, amount);
        } else {
            payable(to).transfer(amount);
        }
    }

    function calculateAmount(
        address _paymentToken,
        uint256 _amount,
        uint256 _rate
    ) public view returns (uint256) {
        uint256 scale;
        if (_paymentToken == address(0)) {
            scale = 10 ** 18;
        } else {
            uint256 decimals = ERC20(_paymentToken).decimals();
            scale = 10 ** decimals;
        }
        return (_amount.mul(_rate)).div(scale);
    }

    function cancelPool() external onlyOwner {
        require(
            poolData.status == PoolStatus.ACTIVE,
            "Already finalized or cancelled"
        );

        poolData.status = PoolStatus.CANCELED;
        uint256 tokensForSale = IERC20(launchInfo.tokenAddress).balanceOf(
            address(this)
        );
        IERC20(launchInfo.tokenAddress).transfer(msg.sender, tokensForSale);
        emit poolCanceled(poolData.status);
        renounceOwnership();
    }

    function referComissionAmount(address user) public view returns (uint256) {
        uint256 _paymentDecimals;
        if (launchInfo.paymentToken != address(0)) {
            _paymentDecimals =
                10 ** (ERC20(launchInfo.paymentToken).decimals());
        } else {
            _paymentDecimals = 10 ** 18;
        }
        uint256 _share = ((referReward).mul(_paymentDecimals)).div(
            totalRefferal
        );

        uint256 totalContribution = referComission[user];
        uint256 usersShare = ((totalContribution).mul(_share)).div(
            _paymentDecimals
        );

        return usersShare;
    }
}
