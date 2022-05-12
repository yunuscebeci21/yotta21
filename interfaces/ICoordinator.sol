// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoordinator{
    function setEpochForCoordinatorDividend(bool _epoch) external returns (bool, uint256);
    function getDividend(address _account) external;
    function setLockDividend(bool _status) external;
}