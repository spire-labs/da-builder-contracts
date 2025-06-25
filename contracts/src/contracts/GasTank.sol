// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol';
import {IGasTank} from 'interfaces/IGasTank.sol';
import {ISemver} from 'interfaces/utils/ISemver.sol';

/// @title GasTank
///
/// @notice Contract for rollups to deposit funds for the aggregator service to charge from
contract GasTank is IGasTank, ISemver, UUPSUpgradeable, OwnableUpgradeable {
  /// @notice The version of the contract
  string internal constant _VERSION = '1.0.0';

  /// @notice The delay before an account can be closed
  uint256 public constant WITHDRAWAL_DELAY = 7 days;

  /// @notice The address of the builder DA Builder is using
  address public builder;

  /// @notice Mapping of balances
  mapping(address _operator => uint256 _balance) public balances;

  /// @notice Mapping of withdrawal start times
  mapping(address _operator => uint256 _timestamp) public withdrawalStartedAt;

  /// @notice Storage gap for future upgrades
  uint256[50] private __gap;

  modifier onlyBuilder() {
    if (msg.sender != builder) revert NotBuilder();
    _;
  }

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract
  ///
  /// @param _owner The owner of the contract
  /// @param _builder The hot wallet the builder is using
  function initialize(address _owner, address _builder) external virtual override initializer {
    __Ownable_init(_owner);
    builder = _builder;
  }

  /// @notice Sets the builder
  ///
  /// @param _builder The hot wallet the builder is using
  function setBuilder(
    address _builder
  ) external onlyOwner {
    builder = _builder;
  }

  /// @notice Charge an account
  ///
  /// @param _account The account to charge
  ///
  /// @dev Can only be called by the contract owner
  function charge(
    Account calldata _account
  ) external onlyBuilder {
    address _proxyAdmin = owner();
    _charge(_account, _proxyAdmin);
  }

  /// @notice Charge an account
  ///
  /// @param _accounts The accounts to charge
  ///
  /// @dev Can only be called by the contract owner
  function batchCharge(
    Account[] calldata _accounts
  ) external onlyBuilder {
    address _proxyAdmin = owner();
    for (uint256 i; i < _accounts.length; i++) {
      _charge(_accounts[i], _proxyAdmin);
    }
  }

  /// @notice Deposit funds into the account manager for an account
  function deposit() external payable {
    _deposit();
  }

  /// @notice Initiate an account to be closed
  function initiateAccountClose() external {
    withdrawalStartedAt[msg.sender] = block.timestamp;

    emit AccountCloseInitiated(msg.sender);
  }

  /// @notice Close an account
  ///
  /// @param _operator The address of the account to close
  function closeAccount(
    address _operator
  ) external {
    uint256 _withdrawalStartedAt = withdrawalStartedAt[_operator];

    if (_withdrawalStartedAt + WITHDRAWAL_DELAY > block.timestamp || _withdrawalStartedAt == 0) {
      revert AccountCantBeClosed();
    }

    uint256 _balance = balances[_operator];
    balances[_operator] = 0;
    withdrawalStartedAt[_operator] = 0;

    (bool _success,) = _operator.call{value: _balance}('');
    if (!_success) {
      revert FailedLowLevelCall();
    }

    emit AccountClosed(_operator);
  }

  /// @notice Charge an account
  ///
  /// @param _account The account to charge
  /// @param _proxyAdmin The admin of the proxy, should receive the funds
  function _charge(Account calldata _account, address _proxyAdmin) internal {
    balances[_account.operator] -= _account.charge;
    (bool _success,) = _proxyAdmin.call{value: _account.charge}('');
    if (!_success) {
      revert FailedLowLevelCall();
    }
  }

  /// @notice Deposit funds into the account manager for an account
  function _deposit() internal {
    if (withdrawalStartedAt[msg.sender] != 0) revert AccountClosing();

    uint256 _balance = balances[msg.sender];
    uint256 _newBalance = _balance + msg.value;

    balances[msg.sender] = _newBalance;

    emit AccountDeposited(msg.sender, _newBalance);
  }

  /// @notice Authorizes the upgrade
  ///
  /// @param _newImplementation The new implementation address
  function _authorizeUpgrade(
    address _newImplementation
  ) internal override onlyOwner {}

  /// @notice Returns the version of the contract
  function version() external pure returns (string memory) {
    return _VERSION;
  }

  receive() external payable {
    _deposit();
  }
}
