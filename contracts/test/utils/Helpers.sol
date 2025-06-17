// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from 'forge-std/Test.sol';

/// @title Helpers
///
/// @notice Helper functions for testing, meant to be inherited on the `Base` contract
contract Helpers is Test {
  /// @notice Sets up an account with code
  ///
  /// @param implementation The address of the implementation
  /// @param privateKey The private key of the account
  function _setAccountCode(address implementation, uint256 privateKey) internal {
    vm.signAndAttachDelegation(implementation, privateKey);
    (bool _success,) = payable(vm.addr(privateKey)).call('');
    assertTrue(_success);
  }

  /// @notice Sets up a mock and expects a call to it
  ///
  /// @param _receiver The address to have a mock on
  /// @param _calldata The calldata to mock and expect
  /// @param _returned The data to return from the mocked call
  function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
    vm.mockCall(_receiver, _calldata, _returned);
    vm.expectCall(_receiver, _calldata);
  }

  /// @notice Sets up a mock and expects a call to it
  ///
  /// @param _receiver The address to have a mock on
  /// @param _value The value to mock and expect
  /// @param _calldata The calldata to mock and expect
  /// @param _returned The data to return from the mocked call
  function _mockAndExpect(address _receiver, uint256 _value, bytes memory _calldata, bytes memory _returned) internal {
    vm.mockCall(_receiver, _value, _calldata, _returned);
    vm.expectCall(_receiver, _value, _calldata);
  }
}
