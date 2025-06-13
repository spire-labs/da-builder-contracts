// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BlobAccountManager, IBlobAccountManager} from 'contracts/BlobAccountManager.sol';
import {stdError} from 'forge-std/Test.sol';
import {Base} from 'test/integration/Base.t.sol';

contract Mock_BlobAccountManager is BlobAccountManager {
  uint256 public number;

  function initialize(
    uint256 _number
  ) external {
    number = _number;
  }
}

contract Integration_BlobAccountManager is Base {
  /// @dev Tests that the upgrade works and new parameters are set
  function test_upgrade_differentBuilder_succeeds() public {
    address newImpl = address(new Mock_BlobAccountManager());

    vm.prank(proxyAdmin);
    blobAccountManager.upgradeToAndCall(newImpl, abi.encodeCall(Mock_BlobAccountManager.initialize, (100)));

    assertEq(blobAccountManager.builder(), daBuilder);
    assertEq(blobAccountManager.owner(), proxyAdmin);
    assertEq(Mock_BlobAccountManager(payable(address(blobAccountManager))).number(), 100);
  }

  /// @dev Tests the deposit and single charge flow
  function test_deposit_and_charge_succeeds() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 100 ether, operator: _user});

    vm.prank(daBuilder);
    blobAccountManager.charge(account);

    assertEq(blobAccountManager.balances(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Tests the deposit and charge flow by sending ether to the contract
  function test_direct_deposit_and_charge_succeeds() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    (bool _success,) = address(blobAccountManager).call{value: 100 ether}('');
    assertTrue(_success);

    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 100 ether, operator: _user});

    vm.prank(daBuilder);
    blobAccountManager.charge(account);

    assertEq(blobAccountManager.balances(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Tests a partial charge on the account
  function test_partial_charge_succeeds() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 50 ether, operator: _user});

    vm.prank(daBuilder);
    blobAccountManager.charge(account);

    assertEq(blobAccountManager.balances(_user), 50 ether);
    assertEq(address(proxyAdmin).balance, 50 ether);
  }

  /// @dev Tests a charge with a new builder
  function test_charge_with_newBuilder_succeeds() public {
    address _user = makeAddr('user');
    address newBuilder = makeAddr('newBuilder');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 100 ether, operator: _user});

    vm.prank(proxyAdmin);
    blobAccountManager.setBuilder(newBuilder);

    vm.prank(newBuilder);
    blobAccountManager.charge(account);

    assertEq(blobAccountManager.balances(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Test overcharge reverts with aritmetic overflow
  function test_charge_overcharge_reverts() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account memory account =
      IBlobAccountManager.Account({charge: type(uint256).max, operator: _user});

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(daBuilder);
    blobAccountManager.charge(account);
  }

  /// @dev Tests a batch charge
  function test_batch_charge_succeeds() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user2);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account[] memory accounts = new IBlobAccountManager.Account[](2);
    accounts[0] = IBlobAccountManager.Account({charge: 100 ether, operator: _user});
    accounts[1] = IBlobAccountManager.Account({charge: 100 ether, operator: _user2});

    vm.prank(daBuilder);
    blobAccountManager.batchCharge(accounts);

    assertEq(blobAccountManager.balances(_user), 0);
    assertEq(blobAccountManager.balances(_user2), 0);
    assertEq(address(proxyAdmin).balance, 200 ether);
  }

  /// @dev Tests a batch charge with partial charges
  function test_batch_charge_partial_succeeds() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user2);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account[] memory accounts = new IBlobAccountManager.Account[](2);
    accounts[0] = IBlobAccountManager.Account({charge: 25 ether, operator: _user});
    accounts[1] = IBlobAccountManager.Account({charge: 75 ether, operator: _user2});

    vm.prank(daBuilder);
    blobAccountManager.batchCharge(accounts);

    assertEq(blobAccountManager.balances(_user), 75 ether);
    assertEq(blobAccountManager.balances(_user2), 25 ether);
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
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user2);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account[] memory accounts = new IBlobAccountManager.Account[](2);
    accounts[0] = IBlobAccountManager.Account({charge: 25 ether, operator: _user});
    accounts[1] = IBlobAccountManager.Account({charge: 75 ether, operator: _user2});

    vm.prank(proxyAdmin);
    blobAccountManager.setBuilder(newBuilder);

    vm.prank(newBuilder);
    blobAccountManager.batchCharge(accounts);

    assertEq(blobAccountManager.balances(_user), 75 ether);
    assertEq(blobAccountManager.balances(_user2), 25 ether);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Test batch charge reverts when one account is overcharged
  function test_batch_charge_overcharge_reverts() public {
    address _user = makeAddr('user');
    address _user2 = makeAddr('user2');

    vm.deal(_user, 100 ether);
    vm.deal(_user2, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user2);
    blobAccountManager.deposit{value: 100 ether}();

    IBlobAccountManager.Account[] memory accounts = new IBlobAccountManager.Account[](2);
    accounts[0] = IBlobAccountManager.Account({charge: 25 ether, operator: _user});
    accounts[1] = IBlobAccountManager.Account({charge: type(uint256).max, operator: _user2});

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(daBuilder);
    blobAccountManager.batchCharge(accounts);
  }

  /// @dev Test that the account cant be closed too soon
  function test_account_cant_be_closed_too_soon() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user);
    blobAccountManager.initiateAccountClose();

    assertEq(blobAccountManager.withdrawalStartedAt(_user), block.timestamp);

    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.AccountCantBeClosed.selector));
    vm.prank(_user);
    blobAccountManager.closeAccount(_user);
  }

  /// @dev Test that the account can be closed and user is charged before closure
  function test_account_can_be_closed_with_charge() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user);
    blobAccountManager.initiateAccountClose();

    assertEq(blobAccountManager.withdrawalStartedAt(_user), block.timestamp);

    vm.prank(daBuilder);
    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 100 ether, operator: _user});
    blobAccountManager.charge(account);

    vm.warp(block.timestamp + blobAccountManager.WITHDRAWAL_DELAY());

    vm.prank(_user);
    blobAccountManager.closeAccount(_user);

    assertEq(blobAccountManager.balances(_user), 0);
    assertEq(blobAccountManager.withdrawalStartedAt(_user), 0);
    assertEq(address(proxyAdmin).balance, 100 ether);
  }

  /// @dev Tests that closing account with charges returns the correct amount
  function test_account_can_be_closed_partial_withdrawal() public {
    address _user = makeAddr('user');

    vm.deal(_user, 100 ether);

    vm.prank(_user);
    blobAccountManager.deposit{value: 100 ether}();

    vm.prank(_user);
    blobAccountManager.initiateAccountClose();

    assertEq(blobAccountManager.withdrawalStartedAt(_user), block.timestamp);

    vm.prank(daBuilder);
    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 50 ether, operator: _user});
    blobAccountManager.charge(account);

    vm.warp(block.timestamp + blobAccountManager.WITHDRAWAL_DELAY());

    vm.prank(_user);
    blobAccountManager.closeAccount(_user);

    assertEq(blobAccountManager.balances(_user), 0 ether);
    assertEq(blobAccountManager.withdrawalStartedAt(_user), 0);
    assertEq(address(proxyAdmin).balance, 50 ether);
    assertEq(address(_user).balance, 50 ether);
  }
}
