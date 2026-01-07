// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IProposerMulticall {
  event InternalGasUsed(uint256[] _internalCallsGasUsed);

  error LowLevelCallFailed();
  error Unauthorized();
  error OutOfGas();

  struct Call {
    address proposer;
    address target;
    bytes data;
    uint256 value;
    uint256 gasLimit;
  }

  function multicall(
    Call[] calldata _calls
  ) external;
  function initialize(
    address _owner
  ) external;
  function BUILDER() external view returns (address);
}
