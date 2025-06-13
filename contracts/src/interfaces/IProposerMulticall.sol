// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface IProposerMulticall {
  error LowLevelCallFailed();
  error Unauthorized();
  error InvalidProposer();

  struct Call {
    address proposer;
    address target;
    bytes data;
    uint256 value;
    bool enforceRevert;
  }

  function multicall(
    Call[] calldata _calls
  ) external payable;
  function initialize(
    address _owner
  ) external;
  function BUILDER() external view returns (address);
}
