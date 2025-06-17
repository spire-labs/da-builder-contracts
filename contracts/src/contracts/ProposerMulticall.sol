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
  ) external payable {
    if (msg.sender != BUILDER) revert Unauthorized();

    uint256 _msgValueSummation;

    for (uint256 i; i < _calls.length; ++i) {
      _msgValueSummation += _calls[i].value;
      (bool _success, bytes memory _retdata) = _calls[i].proposer.call{value: _calls[i].value}(
        abi.encodeCall(IProposer.call, (_calls[i].target, _calls[i].data))
      );

      if (_calls[i].enforceRevert) {
        if (_retdata.length == 0) revert InvalidProposer();

        bool _result = abi.decode(_retdata, (bool));

        if (!_success || !_result) {
          revert LowLevelCallFailed();
        }
      }
    }
  }

  /// @notice Authorizes the upgrade
  ///
  /// @param _newImplementation The new implementation address
  function _authorizeUpgrade(
    address _newImplementation
  ) internal override onlyOwner {}
}
