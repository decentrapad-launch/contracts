// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "./DecentrapadLaunch.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DecentraLaunchFactory is AccessControl, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    event poolDeployed(address, address);

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address platformAddress;
    uint256 platformOneTimeFee;
    uint256 constant base = 1000;
    uint8 nativeFee;
    uint8 dualFees;
    bool feeSide;

    constructor(address _platformAddress, uint8 _nativeFee, uint8 _dualFees) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        platformAddress = _platformAddress;
        nativeFee = _nativeFee;
        dualFees = _dualFees;
    }

    function deployPool(
        DecentrapadLaunch.launchSaleInfo memory _launchInfo,
        DecentrapadLaunch.VestingSchedule memory _vestingSchedule,
        address owner,
        bool feesInNative,
        bool _whitelistStatus,
        bool _referRewardStatus
    ) external payable nonReentrant {
        require(
            msg.value == platformOneTimeFee,
            "Invalid Pool Creation Fee sent"
        );
        checkLaunchInfo(_launchInfo);
        checkVestingInfo(_vestingSchedule, _launchInfo.endTime);

        DecentrapadLaunch.poolFee memory _poolFee;
        if (feesInNative) {
            _poolFee = DecentrapadLaunch.poolFee(nativeFee, 0);
        } else {
            _poolFee = DecentrapadLaunch.poolFee(dualFees, dualFees);
        }
        DecentrapadLaunch decentraPool = new DecentrapadLaunch(
            _launchInfo,
            _poolFee,
            _vestingSchedule,
            owner,
            platformAddress,
            _whitelistStatus,
            _referRewardStatus
        );
        feeSide = feesInNative;
        uint256 total = calculateTokens(
            _launchInfo.presaleRate,
            _launchInfo.hardCap,
            _launchInfo.paymentToken
        );

        ERC20(_launchInfo.tokenAddress).safeTransferFrom(
            msg.sender,
            address(decentraPool),
            total
        );

        payable(platformAddress).transfer(msg.value);

        emit poolDeployed(address(decentraPool), owner);
    }

    function checkVestingInfo(
        DecentrapadLaunch.VestingSchedule memory _vestingSchedule,
        uint256 _endTime
    ) private pure {
        require(
            _vestingSchedule.startTime == _endTime,
            "Vesting unlock should start after launch ends"
        );
        isNotZero(_vestingSchedule.cycleLength);
        isNotZero(_vestingSchedule.initialUnlockPercentage);
        isNotZero(_vestingSchedule.periodUnlockPercentage);
    }

    function checkLaunchInfo(
        DecentrapadLaunch.launchSaleInfo memory _launchInfo
    ) private view {
        require(
            _launchInfo.startTime > block.timestamp &&
                _launchInfo.endTime > _launchInfo.startTime,
            "time error"
        );
        require(_launchInfo.softCap <= _launchInfo.hardCap, "sc > hc");
        require(
            _launchInfo.softCap >= _launchInfo.hardCap.div(4),
            "sc should be 25% of hc"
        );
        isNotZeroAddress(msg.sender);
        isNotZeroAddress(_launchInfo.tokenAddress);
        isNotZero(_launchInfo.tokensForSale);
        isNotZero(_launchInfo.softCap);
        isNotZero(_launchInfo.hardCap);
        isNotZero(_launchInfo.presaleRate);
        isNotZero(_launchInfo.minBuyLimit);
        isNotZero(_launchInfo.maxBuyLimit);
    }

    function setPoolFees(
        uint8 _native,
        uint8 _dualFees
    ) external onlyRole(EXECUTOR_ROLE) {
        nativeFee = _native;
        dualFees = _dualFees;
    }

    function setPlaformAddress(
        address newAddress
    ) external onlyRole(EXECUTOR_ROLE) {
        platformAddress = newAddress;
    }

    function calculateTokens(
        uint256 presaleRate,
        uint256 hardCap,
        address paymentToken
    ) public view returns (uint256) {
        uint256 scale;
        if (paymentToken != address(0)) {
            uint256 decimals = ERC20(paymentToken).decimals();
            scale = 10 ** decimals;
        } else {
            scale = 10 ** 18;
        }
        uint256 tokensForSale = (presaleRate.mul(hardCap)).div(scale);
        uint256 fee;
        if (!feeSide) {
            fee = tokensForSale.mul(dualFees).div(base);
        }
        return tokensForSale.add(fee);
    }

    function setPlaformFee(uint256 newFee) external onlyRole(EXECUTOR_ROLE) {
        platformOneTimeFee = newFee;
    }

    function getPlatformAddress() external view returns (address) {
        return platformAddress;
    }

    function getplatformOneTimeFee() external view returns (uint256) {
        return platformOneTimeFee;
    }

    function isNotZeroAddress(address _add) private pure {
        require(_add != address(0), "Decentralaunch Factory: zero address");
    }

    function isNotZero(uint256 _num) private pure {
        require(_num != 0, "Decentralaunch Factory: zero value");
    }
}
