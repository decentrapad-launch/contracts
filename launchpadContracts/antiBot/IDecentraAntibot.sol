// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

interface IDecentraAntiBot {
    function setTokenOwner(address owner) external;

    function transferValidation(
        address from,
        address to,
        uint256 amount
    ) external;
}
