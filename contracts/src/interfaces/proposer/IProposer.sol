// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

interface IProposer {
  error LowLevelCallFailed();
  error Unauthorized();

  function call(address _target, bytes calldata _data) external payable returns (bool);
}
