// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IProposer} from 'interfaces/proposer/IProposer.sol';

/// @title Proposer
///
/// @dev An example implementation of a proposer contract that is compatible with the aggregation service
///      Intended to be set as an EOA account code (EIP-7702)
///      This contract is meant to be an example implementation, and is stateless for the sake of simple storage management
contract Proposer is IProposer {
  /// @notice The address of the proposer multicall contract
  address public immutable PROPOSER_MULTICALL;

  /// @notice Constructor
  ///
  /// @param _proposerMulticall The address of the proposer multicall contract
  constructor(
    address _proposerMulticall
  ) {
    PROPOSER_MULTICALL = _proposerMulticall;
  }

  /// @notice Fallback function to receive ether
  receive() external payable {}

  /// @notice Makes an arbitrary low level call
  ///
  /// @param _target The address to call
  /// @param _data The calldata to send
  ///
  /// @return True by default if the call succeeds
  ///
  /// @dev The interface expectation is the boolean return value matches the status of the call, if it returns false for any reason
  ///      the builder will ignore the transaction
  /// @dev Has a whitelist check to enforce an authorized caller
  /// @dev Used to allow for contracts to make arbitrary calls for an EOA
  function call(address _target, bytes calldata _data) external payable returns (bool) {
    if (msg.sender != PROPOSER_MULTICALL && address(this) != msg.sender) revert Unauthorized();

    (bool _success,) = _target.call{value: msg.value}(_data);
    if (!_success) {
      revert LowLevelCallFailed();
    }

    return true;
  }
}
