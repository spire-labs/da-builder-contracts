// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GasTank} from 'contracts/GasTank.sol';
import {Base} from 'test/integration/Base.t.sol';

contract Mock_GasTank is GasTank {
  uint256 public number;

  function initialize(
    uint256 _number
  ) external {
    number = _number;
  }
}

contract Integration_GasTank is Base {
  /// @dev Tests that the upgrade works and new parameters are set
  function test_upgrade_differentBuilder_succeeds() public {
    address newImpl = address(new Mock_GasTank());

    vm.prank(proxyAdmin);
    gasTank.upgradeToAndCall(newImpl, abi.encodeCall(Mock_GasTank.initialize, (100)));

    assertEq(gasTank.builder(), daBuilder);
    assertEq(gasTank.owner(), proxyAdmin);
    assertEq(Mock_GasTank(payable(address(gasTank))).number(), 100);
  }

  /// @dev Tests that the user can deposit for themselves
  function test_deposit_for_self_succeeds() public {
    address _user = makeAddr('user');
    vm.deal(_user, 100 ether);

    uint256 _balanceBefore = gasTank.balances(_user);
    uint256 _contractBalanceBefore = address(gasTank).balance;

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    assertEq(gasTank.balances(_user), _balanceBefore + 100 ether);
    assertEq(address(gasTank).balance, _contractBalanceBefore + 100 ether);
  }

  /// @dev Tests that the user can deposit by sending ether to the contract
  function test_deposit_by_sending_ether_succeeds() public {
    address _user = makeAddr('user');
    vm.deal(_user, 100 ether);

    uint256 _balanceBefore = gasTank.balances(_user);
    uint256 _contractBalanceBefore = address(gasTank).balance;
    vm.prank(_user);
    (bool _success,) = address(gasTank).call{value: 100 ether}('');
    assertTrue(_success);
    assertEq(gasTank.balances(_user), _balanceBefore + 100 ether);
    assertEq(address(gasTank).balance, _contractBalanceBefore + 100 ether);
  }

  /// @dev Tests that deposit for a beneficiary works
  function test_deposit_for_beneficiary_succeeds() public {
    address _user = makeAddr('user');
    address _beneficiary = makeAddr('beneficiary');

    vm.deal(_user, 100 ether);

    uint256 _balanceBefore = gasTank.balances(_beneficiary);
    uint256 _contractBalanceBefore = address(gasTank).balance;
    vm.prank(_user);
    gasTank.deposit{value: 100 ether}(_beneficiary);

    assertEq(gasTank.balances(_beneficiary), _balanceBefore + 100 ether);
    assertEq(address(gasTank).balance, _contractBalanceBefore + 100 ether);
  }

  /// @dev Tests that withdraw is unbounded and can withdraw all funds to the owner
  function test_withdraw_unbounded_succeeds() public {
    address _user = makeAddr('user');

    // User depositing 100 ether
    vm.deal(_user, 100 ether);
    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();
    uint256 _userBalanceBefore = gasTank.balances(_user);
    uint256 _contractBalanceBefore = address(gasTank).balance;
    uint256 _adminBalanceBefore = proxyAdmin.balance;

    // Owner withdrawing all funds
    vm.prank(daBuilder);
    gasTank.withdraw(address(gasTank).balance);

    assertEq(address(gasTank).balance, 0);
    assertEq(proxyAdmin.balance, _adminBalanceBefore + _contractBalanceBefore);

    // Users balance should be unchanged
    assertEq(gasTank.balances(_user), _userBalanceBefore);
  }
}
