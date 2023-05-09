// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "./airdrop.sol";

contract DecentraLaunchFactory is Ownable, ReentrancyGuard {
    event poolDeployed(address, address);

    address platformAddress;
    uint256 platformOneTimeFee;
    uint256 platformTokenFee;

    constructor(
        address _platformAddress,
        uint256 _platformOneTimeFee,
        uint8 _platformFee
    ) {
        platformAddress = _platformAddress;
        platformTokenFee = _platformFee;
        platformOneTimeFee = _platformOneTimeFee;
    }

    function deployPool(
        address _token,
        address _owner
    ) external payable nonReentrant {
        require(
            msg.value == platformOneTimeFee,
            "Invalid Pool Creation Fee sent"
        );

        require(_token != address(0), "Invalid token address");

        AirDrop newAirdrop = new AirDrop(
            _token,
            platformAddress,
            _owner,
            platformTokenFee
        );

        payable(platformAddress).transfer(msg.value);
        emit poolDeployed(address(newAirdrop), _owner);
    }

    function setPlaformAddress(address newAddress) external onlyOwner {
        platformAddress = newAddress;
    }

    function setPlaformOneTimeFee(uint256 newFee) external onlyOwner {
        platformOneTimeFee = newFee;
    }

    function setPlaformTokenFee(uint256 newFee) external onlyOwner {
        platformTokenFee = newFee;
    }

    function getPlatformAddress() external view returns (address) {
        return platformAddress;
    }

    function getplatformOneTimeFee() external view returns (uint256) {
        return platformOneTimeFee;
    }

    function getplatformTokenFee() external view returns (uint256) {
        return platformTokenFee;
    }
}
