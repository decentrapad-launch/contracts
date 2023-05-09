// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILock {
    function lock(
        address owner,
        address token,
        bool isLpToken,
        uint256 amount,
        uint256 unlockDate,
        string memory description
    ) external returns (uint256 lockId);
}
