// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { IDividend } from "./interfaces/IDividend.sol";
import { IWeth } from "./interfaces/IWeth.sol";

/// @title Dividend
/// @author Yotta21
/// @notice The process of entering and exiting the dividend takes place.
contract Dividend is IDividend {
  using SafeMath for uint256;

  /* =================== State Variables ====================== */
  /// @notice Address of manager contract
  address public manager;
  /// @notice Address of Otta
  address public ottaTokenAddress;
  /// @notice Address of Locked Otta contract
  address public lockedOtta;
  /// @notice Total number of wallets locking Otta tokens
  uint256 public walletCounter;
  /// @notice Total locked Otta token amount
  uint256 public totalLockedOtta;
  /// @notice Total ethereum to dividend
  uint256 public totalEthDividend;
  /// @notice Max integer value
  uint256 public constant MAX_INT = 2**256 - 1;
  /// @notice State of sets in this contract
  bool public isLockingEpoch;
  /// @notice Holds relation of address and locked otta token amount
  mapping(address => uint256) private locked;
  /// @notice Importing Otta token methods
  ERC20 public ottaToken;

  /* =================== Constructor ====================== */
  constructor(
    address _manager,
    address _ottaTokenAddress,
    address _lockedOtta
  ) {
    require(_manager != address(0), "Zero address");
    manager = _manager;
    isLockingEpoch = false;
    require(_ottaTokenAddress != address(0), "Zero address");
    ottaTokenAddress = _ottaTokenAddress;
    ottaToken = ERC20(ottaTokenAddress);
    require(_lockedOtta != address(0), "Zero address");
    lockedOtta = _lockedOtta;
  }

  /* =================== Functions ====================== */
  receive() external payable {}

  /* =================== External Functions ====================== */
  /// @inheritdoc IDividend
  function setEpoch(bool epoch)
    external
    override
    returns (bool state, uint256 totalEth)
  {
    require(msg.sender == ottaTokenAddress, "Only Otta");
    isLockingEpoch = epoch;
    if (isLockingEpoch) {
      totalEthDividend = address(this).balance;
      uint256 _amount = ottaToken.balanceOf(lockedOtta);
      locked[manager] = _amount;
      uint256 _ottaAmount = ottaToken.balanceOf(address(this));
      totalLockedOtta = _ottaAmount.add(_amount);
      walletCounter += 1;
      emit OttaTokenLocked(manager, _amount);
    }
    return (isLockingEpoch, totalEthDividend);
  }

  /// @notice recives otta token to lock
  /// @param amount The otta token amount to lock
  function lockOtta(uint256 amount) external {
    require(isLockingEpoch, "Not epoch");
    locked[msg.sender] = locked[msg.sender].add(amount);
    totalLockedOtta = totalLockedOtta.add(amount);
    walletCounter += 1;
    bool success = ottaToken.transferFrom(msg.sender, address(this), amount);
    require(success, "Transfer failed");
    emit OttaTokenLocked(msg.sender, amount);
  }

  /// @notice calculates dividend amount of user
  /// @dev Transfers locked Otta token to user
  /// @dev Transfers dividends to the user 
  function getDividend() external {
    require(!isLockingEpoch, "Not dividend epoch");
    require(locked[msg.sender] != 0, "Locked Otta not found");
    address payable _userAddress = payable(msg.sender);
    require(_userAddress != address(0), "Zero address");
    uint256 _ottaQuantity = locked[msg.sender];
    locked[msg.sender] = 0;
    walletCounter -= 1;
    uint256 _percentage = (_ottaQuantity.mul(10**18)).div(totalLockedOtta);
    uint256 _dividendQuantity = (_percentage.mul(totalEthDividend)).div(10**18);
    _userAddress.transfer(_dividendQuantity);
    bool success = ottaToken.transfer(msg.sender, _ottaQuantity);
    require(success, "Transfer failed");
  }

  /// @inheritdoc IDividend
  function getDividendRequesting() external override {
    require(msg.sender == ottaTokenAddress, "Only Otta");
    address payable _userAddress = payable(manager);
    require(_userAddress != address(0), "Zero address");
    uint256 _ottaQuantity = locked[manager];
    locked[manager] = 0;
    walletCounter -= 1;
    uint256 _percentage = (_ottaQuantity.mul(10**18)).div(totalLockedOtta);
    uint256 _dividendQuantity = (_percentage.mul(totalEthDividend)).div(10**18);
    _userAddress.transfer(_dividendQuantity);
  }

  /* =================== Public Functions ====================== */
  /// @notice Returns locked otta amount of user
  /// @param _userAddress The address of user
  function getLockedAmount(address _userAddress)
    public
    view
    returns (uint256 lockedAmount)
  {
    return locked[_userAddress];
  }
}
