// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { SafeMath } from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { ISetToken } from "../external/ISetToken.sol";
import { ITradeModule } from "../external/ITradeModule.sol";
import { ITimelock } from "../interfaces/ITimelock.sol";


contract Timelock is ITimelock{
  using SafeMath for uint256;

  event NewAdmin(address indexed newAdmin);
  event NewPendingAdmin(address indexed newPendingAdmin);
  event NewDelay(uint256 indexed newDelay);
  event CancelTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  event ExecuteTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  event QueueTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );
  
  //oylamada kalma süresi 3 gün
  uint256 public constant GRACE_PERIOD = 7200;
  uint256 public constant MINIMUM_DELAY = 7000;
  uint256 public constant MAXIMUM_DELAY = 14400;

  address public admin;
  address public owner;
  address public guardianWalletAddress;
  address public ttffAddress;
  address public pendingAdmin;
  address public tokenAddress;
  uint256 public delay;

  bool public isFirstAdminSetted;

  mapping(bytes32 => bool) public queuedTransactions;

  ITradeModule public tradeModule;

  constructor(uint256 delay_, address _tradeModule, address _tokenAddress) {
    require(
      delay_ >= MINIMUM_DELAY,
      "Timelock::constructor: Delay must exceed minimum delay."
    );
    require(
      delay_ <= MAXIMUM_DELAY,
      "Timelock::setDelay: Delay must not exceed maximum delay."
    );

    owner = msg.sender;
    delay = delay_;
    tradeModule = ITradeModule(_tradeModule);
    tokenAddress = _tokenAddress;
  }

  receive() external payable {}

  function rebalancing(address _setToken,
        string calldata _exchangeName,
        address _sendToken,
        uint256 _sendQuantity,
        address _receiveToken,
        uint256 _minReceiveQuantity,
        bytes calldata _data) external {
    require(msg.sender == address(this) || msg.sender == guardianWalletAddress, "Only Timelock or Guardian Wallet");
    // multiwallet otta timelock tarafından set edilebilir olucak
    // timelock contract'ında ttff set fonksiyonu olmalı 
    ISetToken _ttff = ISetToken(_setToken);
    if(msg.sender==guardianWalletAddress){
      tradeModule.trade(_ttff,
                      _exchangeName,
                      _sendToken,
                      _sendQuantity,
                      tokenAddress,
                      _minReceiveQuantity,
                      _data);
    }else if(msg.sender == address(this)){
       tradeModule.trade(_ttff,
                      _exchangeName,
                      _sendToken,
                      _sendQuantity,
                      _receiveToken,
                      _minReceiveQuantity,
                      _data);
    }
  }

  function setFirstAdmin(address admin_) public {
    require(msg.sender==owner, "only owner");
    require(!isFirstAdminSetted, "Timelock::setFirstAdmin: Already setted.");
    isFirstAdminSetted = true;
    admin = admin_;
    emit NewAdmin(admin);
  }

  function setGuardianWallet(address _newGuardianWalletAddress) public {
    require(msg.sender==address(this),"only this address");
    guardianWalletAddress = _newGuardianWalletAddress;
  }

  function getGuardianWallet() external view override returns(address){
    return guardianWalletAddress;
  }

  function setTokenAddress(address _newTokenAddress) public {
    require(msg.sender==address(this),"only this address");
    tokenAddress = _newTokenAddress;
  }

  function getTokenAddress() external view override returns(address){
    return tokenAddress;
  }

  function setTTFF(address _ttffAddress) public {
    require(msg.sender==owner,"only owner");
    ttffAddress = _ttffAddress;
  }

  function setDelay(uint256 delay_) public {
    require(
      msg.sender == address(this),
      "Timelock::setDelay: Call must come from Timelock."
    );
    require(
      delay_ >= MINIMUM_DELAY,
      "Timelock::setDelay: Delay must exceed minimum delay."
    );
    require(
      delay_ <= MAXIMUM_DELAY,
      "Timelock::setDelay: Delay must not exceed maximum delay."
    );
    delay = delay_;

    emit NewDelay(delay);
  }

  function acceptAdmin() public {
    require(
      msg.sender == pendingAdmin,
      "Timelock::acceptAdmin: Call must come from pendingAdmin."
    );
    admin = msg.sender;
    pendingAdmin = address(0);

    emit NewAdmin(admin);
  }

  function setPendingAdmin(address pendingAdmin_) public {
    require(
      msg.sender == address(this),
      "Timelock::setPendingAdmin: Call must come from Timelock."
    );
    pendingAdmin = pendingAdmin_;

    emit NewPendingAdmin(pendingAdmin);
  }

  function queueTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public returns (bytes32) {
    require(
      msg.sender == admin,
      "Timelock::queueTransaction: Call must come from admin."
    );
    require(
      eta >= getBlockTimestamp().add(delay),
      "Timelock::queueTransaction: Estimated execution block must satisfy delay."
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = true;

    emit QueueTransaction(txHash, target, value, signature, data, eta);
    return txHash;
  }

  function cancelTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public {
    require(
      msg.sender == admin,
      "Timelock::cancelTransaction: Call must come from admin."
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    queuedTransactions[txHash] = false;

    emit CancelTransaction(txHash, target, value, signature, data, eta);
  }

  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    uint256 eta
  ) public payable returns (bytes memory) {
    require(
      msg.sender == admin,
      "Timelock::executeTransaction: Call must come from admin."
    );

    bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    require(
      queuedTransactions[txHash],
      "Timelock::executeTransaction: Transaction hasn't been queued."
    );
    require(
      getBlockTimestamp() >= eta,
      "Timelock::executeTransaction: Transaction hasn't surpassed time lock."
    );
    require(
      getBlockTimestamp() <= eta.add(GRACE_PERIOD),
      "Timelock::executeTransaction: Transaction is stale."
    );

    queuedTransactions[txHash] = false;

    bytes memory callData;

    if (bytes(signature).length == 0) {
      callData = data;
    } else {
      callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
    }

    // solium-disable-next-line security/no-call-value
    (bool success, bytes memory returnData) = target.call{value: value}(
      callData
    );
    require(
      success,
      "Timelock::executeTransaction: Transaction execution reverted."
    );

    emit ExecuteTransaction(txHash, target, value, signature, data, eta);

    return returnData;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    // solium-disable-next-line security/no-block-members
    return block.timestamp;
  }
}
