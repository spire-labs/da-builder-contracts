// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract SetNumber {
  uint256 public number;

  // Meant to be used for testing sequencer permutation revert scenarios
  // This is important because both individual transactions would succeed on their own
  // Example Batch: [tx1, tx2]
  // -- tx1: setToOne() -- succeeds
  // -- tx2: setToOne() -- reverts
  function setToOne() public {
    if (number == 1) revert();
    number = 1;
  }
}
