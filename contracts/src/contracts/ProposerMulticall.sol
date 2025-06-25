// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {OwnableUpgradeable} from '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol';

import {IProposerMulticall} from 'interfaces/IProposerMulticall.sol';
import {IProposer} from 'interfaces/proposer/IProposer.sol';

/// @title ProposerMulticall
///
/// @notice Contract for us to multicall neccessary proposer functions
contract ProposerMulticall is IProposerMulticall, OwnableUpgradeable, UUPSUpgradeable {
  /// @notice The version of the contract
  string internal constant _VERSION = '1.0.0';

  /// @notice The builder address
  ///
  /// @dev This is made immutable to reduce overhead as this multicall is expected to be called very frequently
  address public immutable BUILDER;

  constructor(
    address _builder
  ) {
    BUILDER = _builder;
    _disableInitializers();
  }

  /// @notice Initializes the contract
  ///
  /// @param _owner The owner of the contract
  function initialize(
    address _owner
  ) external virtual initializer {
    __Ownable_init(_owner);
  }

  /// @notice Multicall to execute multiple proposer calls
  ///
  /// @param _calls The calls to execute
  function multicall(
    Call[] calldata _calls
  ) external {
    if (msg.sender != BUILDER) revert Unauthorized();
    uint256 _callsLength = _calls.length;
    uint256[] memory _internalCallsGasUsed = new uint256[](_callsLength);

    uint256 _msgValueSummation;
    uint256 _preCallGasLeft;
    uint256 _gasUsed;
    bytes memory _callData;

    for (uint256 i; i < _callsLength; ++i) {
      _msgValueSummation += _calls[i].value;
      _callData = abi.encodeCall(IProposer.call, (_calls[i].target, _calls[i].data, _calls[i].value));
      _preCallGasLeft = gasleft();
      (bool _success, bytes memory _retdata) = _calls[i].proposer.call(_callData);
      _gasUsed = _preCallGasLeft - gasleft();

      // NOTE: There is a weird edge case where because the `IProposer` implementation will have nested logic
      // Just a simple transfer will cost >21k gas, meaning if someone sends DA Builder a normal transfer and it has a 21k gas limit
      // It would revert here
      if (_gasUsed > _calls[i].gasLimit) revert OutOfGas();
      _internalCallsGasUsed[i] = _gasUsed;

      if (_retdata.length == 0) revert InvalidProposer();

      bool _result = abi.decode(_retdata, (bool));

      if (!_success || !_result) {
        revert LowLevelCallFailed();
      }
    }

    emit InternalGasUsed(_internalCallsGasUsed);
  }

  /// @notice Returns the version of the contract
  function version() external pure returns (string memory) {
    return _VERSION;
  }

  /// @notice Authorizes the upgrade
  ///
  /// @param _newImplementation The new implementation address
  function _authorizeUpgrade(
    address _newImplementation
  ) internal override onlyOwner {}
}
