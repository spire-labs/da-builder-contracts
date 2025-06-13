// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {BlobAccountManager, IBlobAccountManager} from 'contracts/BlobAccountManager.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract Base is Helpers {
  error OwnableUnauthorizedAccount(address);

  address operator = makeAddr('operator');
  address nonOperator = makeAddr('nonOperator');
  address owner = makeAddr('owner');

  BlobAccountManager public accountManager;

  function setUp() public virtual {
    vm.startPrank(owner);
    accountManager = BlobAccountManager(payable(address(new ERC1967Proxy(address(new BlobAccountManager()), ''))));
    accountManager.initialize(owner, owner);
    vm.stopPrank();
  }
}

contract Unit_BlobAccountManager_constructor is Base {
  /// @dev Tests that the constructor sets the correct state
  function test_constructor_succeeds() public view {
    assertEq(accountManager.builder(), owner);
    assertEq(accountManager.owner(), owner);
  }
}

contract Unit_BlobAccountManager_authorizeUpgrade is Base {
  /// @dev Tests that the `authorizeUpgrade` function reverts if the caller is not the owner
  function testFuzz_authorizeUpgrade_onlyOwner_reverts(
    address nonOwner
  ) public {
    vm.assume(nonOwner != owner);

    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
    vm.prank(nonOwner);
    // Random address
    BlobAccountManager(payable(address(accountManager))).upgradeToAndCall(nonOwner, '');
  }
}

contract Unit_BlobAccountManager_setBuilder is Base {
  /// @dev Tests that the `setBuilder` function reverts if the caller is not the owner
  function test_setBuilder_onlyOwner_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOperator));
    vm.prank(nonOperator);
    accountManager.setBuilder(nonOperator);
  }

  /// @dev Tests that the `setBuilder` function succeeds if the caller is the owner
  function test_setBuilder_succeeds() public {
    vm.prank(owner);
    accountManager.setBuilder(nonOperator);

    assertEq(accountManager.builder(), nonOperator);
  }
}

contract Unit_BlobAccountManager_charge is Base {
  function setUp() public override {
    super.setUp();

    vm.deal(operator, 100);

    vm.prank(operator);
    accountManager.deposit{value: 100}();
  }

  /// @dev Tests that the `charge` function can be called by the owner
  function test_charge_onlyBuilder_reverts() public {
    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 100, operator: operator});

    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.NotBuilder.selector));
    vm.prank(nonOperator);
    accountManager.charge(account);
  }

  /// @dev Tests that the charge is successful
  function test_charge_succeeds() public {
    vm.prank(owner);
    IBlobAccountManager.Account memory account = IBlobAccountManager.Account({charge: 100, operator: operator});

    accountManager.charge(account);

    assertEq(accountManager.balances(operator), 0);
    assertEq(owner.balance, 100);
    assertEq(address(accountManager).balance, 0);
  }

  /// @dev Tests that the charge succeeds in fuzzing
  function testFuzz_charge_succeeds(
    IBlobAccountManager.Account memory account
  ) public {
    uint256 _deposit = type(uint256).max - 100;

    account.charge = bound(account.charge, 1, _deposit);
    vm.assume(account.operator != operator);

    vm.deal(account.operator, _deposit);

    vm.prank(account.operator);
    accountManager.deposit{value: _deposit}();

    vm.prank(owner);
    accountManager.charge(account);

    assertEq(accountManager.balances(account.operator), _deposit - account.charge);
    assertEq(owner.balance, account.charge);
  }
}

contract Unit_BlobAccountManager_batchCharge is Base {
  mapping(address => bool) public used;

  /// @dev Tests that the `batchCharge` function can be called by the owner
  function test_batchCharge_onlyBuilder_reverts() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    accountManager.deposit{value: 100}();

    IBlobAccountManager.Account[] memory accounts = new IBlobAccountManager.Account[](1);
    accounts[0] = IBlobAccountManager.Account({charge: 100, operator: operator});

    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.NotBuilder.selector));
    vm.prank(nonOperator);
    accountManager.batchCharge(accounts);
  }

  //// @dev Tests that the `batchCharge` succeeds
  function test_batchCharge_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    accountManager.deposit{value: 100}();

    IBlobAccountManager.Account[] memory accounts = new IBlobAccountManager.Account[](1);
    accounts[0] = IBlobAccountManager.Account({charge: 100, operator: operator});

    vm.prank(owner);
    accountManager.batchCharge(accounts);

    assertEq(accountManager.balances(operator), 0);
    assertEq(owner.balance, 100);
    assertEq(address(accountManager).balance, 0);
  }

  /// @dev Tests that the `batchCharge` succeeds in fuzzing
  function testFuzz_batchCharge_succeeds(
    IBlobAccountManager.Account[] memory accounts
  ) public {
    vm.assume(accounts.length < 30);
    uint256 _deposit = 1e40;

    for (uint256 i; i < accounts.length; i++) {
      vm.assume(used[accounts[i].operator] == false);
      vm.deal(accounts[i].operator, _deposit);
      vm.prank(accounts[i].operator);
      accountManager.deposit{value: _deposit}();

      accounts[i].charge = bound(accounts[i].charge, 1, _deposit);
      used[accounts[i].operator] = true;
    }
    uint256 prevBalance = address(accountManager).balance;

    vm.prank(owner);
    accountManager.batchCharge(accounts);
    uint256 summationOfCharges;

    for (uint256 i; i < accounts.length; i++) {
      summationOfCharges += accounts[i].charge;
      assertEq(accountManager.balances(accounts[i].operator), _deposit - accounts[i].charge);
    }

    assertEq(summationOfCharges, prevBalance - address(accountManager).balance);
    assertEq(owner.balance, summationOfCharges);
  }
}

contract Unit_BlobAccountManager_deposit is Base {
  event AccountDeposited(address _operator, uint256 _newBalance);

  /// @dev Tests that the `deposit` function reverts if an account is being closed
  function test_deposit_accountClosing_reverts() public {
    vm.deal(operator, 200);

    vm.prank(operator);
    accountManager.deposit{value: 100}();

    vm.prank(operator);
    accountManager.initiateAccountClose();

    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.AccountClosing.selector));
    vm.prank(operator);
    accountManager.deposit{value: 100}();
  }

  /// @dev Tests that the `deposit` function succeeds
  function test_deposit_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    accountManager.deposit{value: 100}();

    assertEq(accountManager.balances(operator), 100);
    assertEq(address(accountManager).balance, 100);
  }

  /// @dev Tests that deposit works by sending ether to the contract
  function test_deposit_receive_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    (bool _success,) = address(accountManager).call{value: 100}('');

    assertTrue(_success);
    assertEq(accountManager.balances(operator), 100);
    assertEq(address(accountManager).balance, 100);
  }

  /// @dev Tests that the `deposit` function emits an event
  function test_deposit_emitsEvent() public {
    vm.deal(operator, 100);

    vm.expectEmit(true, true, true, true);
    emit AccountDeposited(operator, 100);

    vm.prank(operator);
    accountManager.deposit{value: 100}();
  }

  /// @dev Tests that the `deposit` function works with fuzzing
  function testFuzz_deposit_succeeds(
    uint256 deposit
  ) public {
    vm.deal(operator, deposit);

    vm.prank(operator);
    accountManager.deposit{value: deposit}();

    assertEq(accountManager.balances(operator), deposit);
    assertEq(address(accountManager).balance, deposit);
  }

  /// @dev Tests that the `deposit` by receiving ether works with fuzzing
  function testFuzz_deposit_receive_succeeds(
    uint256 deposit
  ) public {
    vm.deal(operator, deposit);

    vm.prank(operator);
    (bool _success,) = address(accountManager).call{value: deposit}('');

    assertTrue(_success);
    assertEq(accountManager.balances(operator), deposit);
    assertEq(address(accountManager).balance, deposit);
  }

  /// @dev Tests that the `deposit` works with multiple different deposits
  function testFuzz_deposit_multipleDeposits_succeeds(
    uint256[] memory deposits
  ) public {
    vm.deal(operator, type(uint256).max);
    vm.assume(deposits.length < 10);

    for (uint256 i; i < deposits.length; i++) {
      vm.assume(deposits[i] < 1e40);
      uint256 _balanceBefore = accountManager.balances(operator);
      uint256 _contractBalanceBefore = address(accountManager).balance;

      vm.prank(operator);
      accountManager.deposit{value: deposits[i]}();

      assertEq(accountManager.balances(operator), _balanceBefore + deposits[i]);
      assertEq(address(accountManager).balance, _contractBalanceBefore + deposits[i]);
    }
  }
}

contract Unit_BlobAccountManager_initiateAccountClose is Base {
  event AccountCloseInitiated(address _operator);

  /// @dev Tests that the `initiateAccountClose` function sets the correct state
  function test_initiateAccountClose_succeeds() public {
    vm.prank(operator);
    accountManager.initiateAccountClose();

    assertEq(accountManager.withdrawalStartedAt(operator), block.timestamp);
  }

  /// @dev Tests that the `initiateAccountClose` function emits an event
  function test_initiateAccountClose_emitsEvent() public {
    vm.expectEmit(true, true, true, true);
    emit AccountCloseInitiated(operator);

    vm.prank(operator);
    accountManager.initiateAccountClose();
  }
}

contract Unit_BlobAccountManager_closeAccount is Base {
  event AccountClosed(address _operator);

  /// @dev Tests that the `closeAccount` function reverts if the account is not closing
  function test_closeAccount_notClosing_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.AccountCantBeClosed.selector));
    vm.prank(operator);
    accountManager.closeAccount(operator);

    vm.warp(accountManager.WITHDRAWAL_DELAY() + 2 days);

    assertEq(accountManager.withdrawalStartedAt(operator), 0);
  }

  /// @dev Tests that the `closeAccount` function reverts if the account is closing too soon
  function testFuzz_closeAccount_tooSoon_reverts(uint256 _delay, uint64 _initialBlockTimestamp) public {
    vm.assume(_initialBlockTimestamp > accountManager.WITHDRAWAL_DELAY());
    vm.warp(_initialBlockTimestamp);

    vm.prank(operator);
    accountManager.initiateAccountClose();

    vm.assume(_delay < accountManager.WITHDRAWAL_DELAY());
    vm.warp(block.timestamp + _delay);

    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.AccountCantBeClosed.selector));
    vm.prank(operator);
    accountManager.closeAccount(operator);

    assertEq(accountManager.withdrawalStartedAt(operator), block.timestamp - _delay);
  }

  /// @dev Tests that the `closeAccount` function reverts if the low level call fails
  function test_closeAccount_lowLevelCallFails_reverts() public {
    vm.deal(operator, 100);
    vm.prank(operator);
    accountManager.deposit{value: 100}();

    vm.prank(operator);
    accountManager.initiateAccountClose();

    vm.warp(block.timestamp + accountManager.WITHDRAWAL_DELAY());
    vm.mockCallRevert(address(operator), 100, abi.encode(), abi.encode('ERROR_MESSAGE'));
    vm.expectRevert(abi.encodeWithSelector(IBlobAccountManager.FailedLowLevelCall.selector));
    vm.prank(operator);
    accountManager.closeAccount(operator);
  }

  /// @dev Tests that the `closeAccount` function succeeds
  function test_closeAccount_succeeds() public {
    vm.deal(operator, 100);
    vm.prank(operator);
    accountManager.deposit{value: 100}();

    vm.prank(operator);
    accountManager.initiateAccountClose();

    vm.warp(block.timestamp + accountManager.WITHDRAWAL_DELAY());

    vm.prank(operator);
    accountManager.closeAccount(operator);

    assertEq(accountManager.balances(operator), 0);
    assertEq(accountManager.withdrawalStartedAt(operator), 0);
    assertEq(address(accountManager).balance, 0);
    assertEq(operator.balance, 100);
  }

  /// @dev Tests that the `closeAccount` function emits an event
  function test_closeAccount_emitsEvent() public {
    vm.deal(operator, 100);
    vm.prank(operator);
    accountManager.deposit{value: 100}();

    vm.prank(operator);
    accountManager.initiateAccountClose();

    vm.warp(block.timestamp + accountManager.WITHDRAWAL_DELAY());

    vm.expectEmit(true, true, true, true);
    emit AccountClosed(operator);

    vm.prank(operator);
    accountManager.closeAccount(operator);
  }
}
