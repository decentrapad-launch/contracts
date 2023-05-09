// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.10;
import "./DecentrapadFairLaunch.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DecentraFairLaunchFactory is AccessControl, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeMath for uint256;

    event poolDeployed(address _poolAddress, address _owner);

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    address platformAddress;
    address public lockAddress;
    uint256 platformOneTimeFee;
    uint256 base = 1000;
    uint8 nativeFee;
    uint8 dualFees;

    constructor(
        address _platformAddress,
        address _lockAddress,
        uint8 _nativeFee,
        uint8 _dualFees
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
        platformAddress = _platformAddress;
        nativeFee = _nativeFee;
        dualFees = _dualFees;
        lockAddress = _lockAddress;
    }

    function deployPool(
        DecentrapadFairLaunch.launchSaleInfo memory _launchInfo,
        DecentrapadFairLaunch.dexListingInfo memory _listingInfo,
        address owner,
        bool feesInNative,
        bool _maxContribution,
        bool _referRewardStatus
    ) external payable nonReentrant {
        checkLaunchInfo(_launchInfo);
        require(
            msg.value == platformOneTimeFee,
            "Invalid Pool Creation Fee sent"
        );

        require(_listingInfo.lpTokensRatio >= 500, "should be more than 50 %");

        require(
            _launchInfo.startTime > block.timestamp &&
                _launchInfo.endTime > _launchInfo.startTime,
            "time error"
        );

        uint256 totalTokensRequired;
        DecentrapadFairLaunch.poolFee memory _poolFee;

        if (feesInNative) {
            _poolFee = DecentrapadFairLaunch.poolFee(nativeFee, 0);
            totalTokensRequired = calculateTotalForNative(
                _launchInfo.tokensForSale,
                nativeFee,
                _listingInfo.lpTokensRatio
            );
        } else {
            _poolFee = DecentrapadFairLaunch.poolFee(dualFees, dualFees);
            totalTokensRequired = calculateTotalForDual(
                _launchInfo.tokensForSale,
                dualFees,
                _listingInfo.lpTokensRatio
            );
        }

        DecentrapadFairLaunch decentraPool = new DecentrapadFairLaunch(
            _launchInfo,
            _listingInfo,
            _poolFee,
            owner,
            platformAddress,
            lockAddress,
            _maxContribution,
            _referRewardStatus
        );

        ERC20(_launchInfo.tokenAddress).safeTransferFrom(
            msg.sender,
            address(decentraPool),
            totalTokensRequired
        );
        payable(platformAddress).transfer(msg.value);
        emit poolDeployed(address(decentraPool), owner);
    }

    function calculateTotalForNative(
        uint256 _tokensForSale,
        uint256 _fee,
        uint256 _lpTokenRatio
    ) public view returns (uint256) {
        uint256 tokensForLP = _tokensForSale.mul(_lpTokenRatio).div(base);
        uint256 calculate = tokensForLP.mul(_fee).div(base);
        uint256 tokensAfterFee = tokensForLP.sub(calculate);
        uint256 totalTokensRequired = _tokensForSale.add(tokensAfterFee);
        return totalTokensRequired;
    }

    function calculateTotalForDual(
        uint256 _tokensForSale,
        uint256 _dualFee,
        uint256 _lpTokenRatio
    ) public view returns (uint256) {
        uint256 tokensForLP = _tokensForSale.mul(_lpTokenRatio).div(base);
        uint256 feeTokensToAdd = _tokensForSale.mul(_dualFee).div(base);
        uint256 feeTokensToSub = tokensForLP.mul(_dualFee).div(base);
        uint256 totalTokensRequired = (
            (_tokensForSale.add(tokensForLP)).add(feeTokensToAdd)
        ).sub(feeTokensToSub);
        return totalTokensRequired;
    }

    function checkLaunchInfo(
        DecentrapadFairLaunch.launchSaleInfo memory _launchInfo
    ) private view {
        isNotZeroAddress(msg.sender);
        isNotZeroAddress(_launchInfo.tokenAddress);
        isNotZero(_launchInfo.tokensForSale);
        isNotZero(_launchInfo.softCap);
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

    function setLockAddress(
        address newAddress
    ) external onlyRole(EXECUTOR_ROLE) {
        lockAddress = newAddress;
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
