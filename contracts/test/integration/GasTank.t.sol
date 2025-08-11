// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GasTank, IGasTank} from 'contracts/GasTank.sol';
import {stdError} from 'forge-std/Test.sol';
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

  /// @dev Tests the deposit and single charge flow
  function test_deposit_and_charge_succeeds() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account memory account = IGasTank.Account({charge: 100 ether, operator: _user});

    vm.prank(daBuilder);
    gasTank.charge(account);

    assertEq(gasTank.balances(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Tests the deposit and charge flow by sending ether to the contract
  function test_direct_deposit_and_charge_succeeds() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    (bool _success,) = address(gasTank).call{value: 100 ether}('');
    assertTrue(_success);

    IGasTank.Account memory account = IGasTank.Account({charge: 100 ether, operator: _user});

    vm.prank(daBuilder);
    gasTank.charge(account);

    assertEq(gasTank.balances(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
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

  /// @dev Tests a partial charge on the account
  function test_partial_charge_succeeds() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account memory account = IGasTank.Account({charge: 50 ether, operator: _user});

    vm.prank(daBuilder);
    gasTank.charge(account);

    assertEq(gasTank.balances(_user), 50 ether);
    assertEq(address(proxyAdmin).balance, 50 ether);
  }

  /// @dev Tests a charge with a new builder
  function test_charge_with_newBuilder_succeeds() public {
    address _user = makeAddr('user');
    address newBuilder = makeAddr('newBuilder');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account memory account = IGasTank.Account({charge: 100 ether, operator: _user});

    vm.prank(proxyAdmin);
    gasTank.setBuilder(newBuilder);

    vm.prank(newBuilder);
    gasTank.charge(account);

    assertEq(gasTank.balances(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Test overcharge reverts with aritmetic overflow
  function test_charge_overcharge_reverts() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account memory account = IGasTank.Account({charge: type(uint256).max, operator: _user});

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(daBuilder);
    gasTank.charge(account);
  }

  /// @dev Tests a batch charge
  function test_batch_charge_succeeds() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user2);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account[] memory accounts = new IGasTank.Account[](2);
    accounts[0] = IGasTank.Account({charge: 100 ether, operator: _user});
    accounts[1] = IGasTank.Account({charge: 100 ether, operator: _user2});

    vm.prank(daBuilder);
    gasTank.batchCharge(accounts);

    assertEq(gasTank.balances(_user), 0);
    assertEq(gasTank.balances(_user2), 0);
    assertEq(address(proxyAdmin).balance, 200 ether);
  }

  /// @dev Tests a batch charge with partial charges
  function test_batch_charge_partial_succeeds() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user2);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account[] memory accounts = new IGasTank.Account[](2);
    accounts[0] = IGasTank.Account({charge: 25 ether, operator: _user});
    accounts[1] = IGasTank.Account({charge: 75 ether, operator: _user2});

    vm.prank(daBuilder);
    gasTank.batchCharge(accounts);

    assertEq(gasTank.balances(_user), 75 ether);
    assertEq(gasTank.balances(_user2), 25 ether);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Tests a batch charge with partial charges and a new builder
  function test_batch_charge_partial_with_newBuilder_succeeds() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');
    address newBuilder = makeAddr('newBuilder');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user2);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account[] memory accounts = new IGasTank.Account[](2);
    accounts[0] = IGasTank.Account({charge: 25 ether, operator: _user});
    accounts[1] = IGasTank.Account({charge: 75 ether, operator: _user2});

    vm.prank(proxyAdmin);
    gasTank.setBuilder(newBuilder);

    vm.prank(newBuilder);
    gasTank.batchCharge(accounts);

    assertEq(gasTank.balances(_user), 75 ether);
    assertEq(gasTank.balances(_user2), 25 ether);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Test batch charge reverts when one account is overcharged
  function test_batch_charge_overcharge_reverts() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user2);
    gasTank.deposit{value: 100 ether}();

    IGasTank.Account[] memory accounts = new IGasTank.Account[](2);
    accounts[0] = IGasTank.Account({charge: 25 ether, operator: _user});
    accounts[1] = IGasTank.Account({charge: type(uint256).max, operator: _user2});

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(daBuilder);
    gasTank.batchCharge(accounts);
  }

  /// @dev Test that the account cant be closed too soon
  function test_account_cant_be_closed_too_soon() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user);
    gasTank.initiateAccountClose();

    assertEq(gasTank.withdrawalStartedAt(_user), block.timestamp);

    vm.expectRevert(abi.encodeWithSelector(IGasTank.AccountCantBeClosed.selector));
    vm.prank(_user);
    gasTank.closeAccount(_user);
  }

  /// @dev Test that the account can be closed and user is charged before closure
  function test_account_can_be_closed_with_charge() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user);
    gasTank.initiateAccountClose();

    assertEq(gasTank.withdrawalStartedAt(_user), block.timestamp);

    vm.prank(daBuilder);
    IGasTank.Account memory account = IGasTank.Account({charge: 100 ether, operator: _user});
    gasTank.charge(account);

    vm.warp(block.timestamp + gasTank.WITHDRAWAL_DELAY());

    vm.prank(_user);
    gasTank.closeAccount(_user);

    assertEq(gasTank.balances(_user), 0);
    assertEq(gasTank.withdrawalStartedAt(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Tests that closing account with charges returns the correct amount
  function test_account_can_be_closed_partial_withdrawal() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    gasTank.deposit{value: 100 ether}();

    vm.prank(_user);
    gasTank.initiateAccountClose();

    assertEq(gasTank.withdrawalStartedAt(_user), block.timestamp);

    vm.prank(daBuilder);
    IGasTank.Account memory account = IGasTank.Account({charge: 50 ether, operator: _user});
    gasTank.charge(account);

    vm.warp(block.timestamp + gasTank.WITHDRAWAL_DELAY());

    vm.prank(_user);
    gasTank.closeAccount(_user);

    assertEq(gasTank.balances(_user), 0 ether);
    assertEq(gasTank.withdrawalStartedAt(_user), 0);
    assertEq(address(proxyAdmin).balance, 50 ether);
    assertEq(address(_user).balance, 50 ether);
  }
}
