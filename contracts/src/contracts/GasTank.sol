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
  string internal constant _VERSION = '1.1.1';

  /// @notice The address of the builder DA Builder is using
  address public builder;

  /// @notice Mapping of balances
  mapping(address _operator => uint256 _balance) public balances;

  /// @notice Mapping of withdrawal start times
  ///
  /// @dev No longer used storage slot
  // forge-lint: disable-next-line(mixed-case-variable)
  mapping(address _operator => uint256 _timestamp) internal __unused_withdrawalStartedAt;

  /// @notice Storage gap for future upgrades
  uint256[50] private __gap;

  /// @notice Constructor
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializes the contract
  ///
  /// @param _owner The owner of the contract
  /// @param _builder The hot wallet the builder is using
  function initialize(
    address _owner,
    address _builder
  ) external virtual override initializer {
    __Ownable_init(_owner);
    builder = _builder;

    emit BuilderSet(_builder);
  }

  /// @notice Sets the builder
  ///
  /// @param _builder The hot wallet the builder is using
  function setBuilder(
    address _builder
  ) external onlyOwner {
    builder = _builder;

    emit BuilderSet(_builder);
  }

  /// @notice Deposit funds into the account manager for an account
  ///
  /// @param _operator The address of the account to deposit into
  function deposit(
    address _operator
  ) external payable {
    _deposit(_operator);
  }

  /// @notice Deposit funds into the account manager for an account
  function deposit() external payable {
    _deposit(msg.sender);
  }

  /// @notice Withdraw funds from the account manager to the owner
  function withdraw(
    uint256 _amount
  ) external {
    if (msg.sender != builder) revert NotBuilder();

    address payable _owner = payable(owner());
    (bool _success,) = _owner.call{value: _amount}('');

    if (!_success) revert FailedLowLevelCall();

    emit Withdrawn(_amount);
  }

  /// @notice Deposit funds into the account manager for an account
  ///
  /// @param _operator The address of the account to deposit into
  function _deposit(
    address _operator
  ) internal {
    uint256 _newBalance = balances[_operator] + msg.value;

    balances[_operator] = _newBalance;

    emit AccountDeposited(_operator, _newBalance);
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
    _deposit(msg.sender);
  }
}
