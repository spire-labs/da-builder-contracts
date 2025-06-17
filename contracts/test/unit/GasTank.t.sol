// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {GasTank, IGasTank} from 'contracts/GasTank.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract Base is Helpers {
  error OwnableUnauthorizedAccount(address);

  address operator = makeAddr('operator');
  address nonOperator = makeAddr('nonOperator');
  address owner = makeAddr('owner');

  GasTank public gasTank;

  function setUp() public virtual {
    vm.startPrank(owner);
    gasTank = GasTank(payable(address(new ERC1967Proxy(address(new GasTank()), ''))));
    gasTank.initialize(owner, owner);
    vm.stopPrank();
  }
}

contract Unit_GasTank_constructor is Base {
  /// @dev Tests that the constructor sets the correct state
  function test_constructor_succeeds() public view {
    assertEq(gasTank.builder(), owner);
    assertEq(gasTank.owner(), owner);
  }
}

contract Unit_GasTank_authorizeUpgrade is Base {
  /// @dev Tests that the `authorizeUpgrade` function reverts if the caller is not the owner
  function testFuzz_authorizeUpgrade_onlyOwner_reverts(
    address nonOwner
  ) public {
    vm.assume(nonOwner != owner);

    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
    vm.prank(nonOwner);
    // Random address
    GasTank(payable(address(gasTank))).upgradeToAndCall(nonOwner, '');
  }
}

contract Unit_GasTank_setBuilder is Base {
  /// @dev Tests that the `setBuilder` function reverts if the caller is not the owner
  function test_setBuilder_onlyOwner_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOperator));
    vm.prank(nonOperator);
    gasTank.setBuilder(nonOperator);
  }

  /// @dev Tests that the `setBuilder` function succeeds if the caller is the owner
  function test_setBuilder_succeeds() public {
    vm.prank(owner);
    gasTank.setBuilder(nonOperator);

    assertEq(gasTank.builder(), nonOperator);
  }
}

contract Unit_GasTank_charge is Base {
  function setUp() public override {
    super.setUp();

    vm.deal(operator, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}();
  }

  /// @dev Tests that the `charge` function can be called by the owner
  function test_charge_onlyBuilder_reverts() public {
    IGasTank.Account memory account = IGasTank.Account({charge: 100, operator: operator});

    vm.expectRevert(abi.encodeWithSelector(IGasTank.NotBuilder.selector));
    vm.prank(nonOperator);
    gasTank.charge(account);
  }

  /// @dev Tests that the `charge` function reverts if the low level call fails
  function test_charge_lowLevelCallFails_reverts() public {
    vm.prank(owner);
    IGasTank.Account memory account = IGasTank.Account({charge: 100, operator: operator});
    vm.mockCallRevert(address(owner), 100, abi.encode(), abi.encode('ERROR_MESSAGE'));
    vm.expectRevert(abi.encodeWithSelector(IGasTank.FailedLowLevelCall.selector));
    gasTank.charge(account);
  }

  /// @dev Tests that the charge is successful
  function test_charge_succeeds() public {
    vm.prank(owner);
    IGasTank.Account memory account = IGasTank.Account({charge: 100, operator: operator});

    gasTank.charge(account);

    assertEq(gasTank.balances(operator), 0);
    assertEq(owner.balance, 100);
    assertEq(address(gasTank).balance, 0);
  }

  /// @dev Tests that the charge succeeds in fuzzing
  function testFuzz_charge_succeeds(
    IGasTank.Account memory account
  ) public {
    uint256 _deposit = type(uint256).max - 100;

    account.charge = bound(account.charge, 1, _deposit);
    vm.assume(account.operator != operator);

    vm.deal(account.operator, _deposit);

    vm.prank(account.operator);
    gasTank.deposit{value: _deposit}();

    vm.prank(owner);
    gasTank.charge(account);

    assertEq(gasTank.balances(account.operator), _deposit - account.charge);
    assertEq(owner.balance, account.charge);
  }
}

contract Unit_GasTank_batchCharge is Base {
  mapping(address => bool) public used;

  /// @dev Tests that the `batchCharge` function can be called by the owner
  function test_batchCharge_onlyBuilder_reverts() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}();

    IGasTank.Account[] memory accounts = new IGasTank.Account[](1);
    accounts[0] = IGasTank.Account({charge: 100, operator: operator});

    vm.expectRevert(abi.encodeWithSelector(IGasTank.NotBuilder.selector));
    vm.prank(nonOperator);
    gasTank.batchCharge(accounts);
  }

  //// @dev Tests that the `batchCharge` succeeds
  function test_batchCharge_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}();

    IGasTank.Account[] memory accounts = new IGasTank.Account[](1);
    accounts[0] = IGasTank.Account({charge: 100, operator: operator});

    vm.prank(owner);
    gasTank.batchCharge(accounts);

    assertEq(gasTank.balances(operator), 0);
    assertEq(owner.balance, 100);
    assertEq(address(gasTank).balance, 0);
  }

  /// @dev Tests that the `batchCharge` succeeds in fuzzing
  function testFuzz_batchCharge_succeeds(
    IGasTank.Account[] memory accounts
  ) public {
    vm.assume(accounts.length < 30);
    uint256 _deposit = 1e40;

    for (uint256 i; i < accounts.length; i++) {
      vm.assume(used[accounts[i].operator] == false);
      vm.deal(accounts[i].operator, _deposit);
      vm.prank(accounts[i].operator);
      gasTank.deposit{value: _deposit}();

      accounts[i].charge = bound(accounts[i].charge, 1, _deposit);
      used[accounts[i].operator] = true;
    }
    uint256 prevBalance = address(gasTank).balance;

    vm.prank(owner);
    gasTank.batchCharge(accounts);
    uint256 summationOfCharges;

    for (uint256 i; i < accounts.length; i++) {
      summationOfCharges += accounts[i].charge;
      assertEq(gasTank.balances(accounts[i].operator), _deposit - accounts[i].charge);
    }

    assertEq(summationOfCharges, prevBalance - address(gasTank).balance);
    assertEq(owner.balance, summationOfCharges);
  }
}

contract Unit_GasTank_deposit is Base {
  event AccountDeposited(address _operator, uint256 _newBalance);

  /// @dev Tests that the `deposit` function reverts if an account is being closed
  function test_deposit_accountClosing_reverts() public {
    vm.deal(operator, 200);

    vm.prank(operator);
    gasTank.deposit{value: 100}();

    vm.prank(operator);
    gasTank.initiateAccountClose();

    vm.expectRevert(abi.encodeWithSelector(IGasTank.AccountClosing.selector));
    vm.prank(operator);
    gasTank.deposit{value: 100}();
  }

  /// @dev Tests that the `deposit` function succeeds
  function test_deposit_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}();

    assertEq(gasTank.balances(operator), 100);
    assertEq(address(gasTank).balance, 100);
  }

  /// @dev Tests that deposit works by sending ether to the contract
  function test_deposit_receive_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    (bool _success,) = address(gasTank).call{value: 100}('');

    assertTrue(_success);
    assertEq(gasTank.balances(operator), 100);
    assertEq(address(gasTank).balance, 100);
  }

  /// @dev Tests that the `deposit` function emits an event
  function test_deposit_emitsEvent() public {
    vm.deal(operator, 100);

    vm.expectEmit(true, true, true, true);
    emit AccountDeposited(operator, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}();
  }

  /// @dev Tests that the `deposit` function works with fuzzing
  function testFuzz_deposit_succeeds(
    uint256 deposit
  ) public {
    vm.deal(operator, deposit);

    vm.prank(operator);
    gasTank.deposit{value: deposit}();

    assertEq(gasTank.balances(operator), deposit);
    assertEq(address(gasTank).balance, deposit);
  }

  /// @dev Tests that the `deposit` by receiving ether works with fuzzing
  function testFuzz_deposit_receive_succeeds(
    uint256 deposit
  ) public {
    vm.deal(operator, deposit);

    vm.prank(operator);
    (bool _success,) = address(gasTank).call{value: deposit}('');

    assertTrue(_success);
    assertEq(gasTank.balances(operator), deposit);
    assertEq(address(gasTank).balance, deposit);
  }

  /// @dev Tests that the `deposit` works with multiple different deposits
  function testFuzz_deposit_multipleDeposits_succeeds(
    uint256[] memory deposits
  ) public {
    vm.deal(operator, type(uint256).max);
    vm.assume(deposits.length < 10);

    for (uint256 i; i < deposits.length; i++) {
      vm.assume(deposits[i] < 1e40);
      uint256 _balanceBefore = gasTank.balances(operator);
      uint256 _contractBalanceBefore = address(gasTank).balance;

      vm.prank(operator);
      gasTank.deposit{value: deposits[i]}();

      assertEq(gasTank.balances(operator), _balanceBefore + deposits[i]);
      assertEq(address(gasTank).balance, _contractBalanceBefore + deposits[i]);
    }
  }
}

contract Unit_GasTank_initiateAccountClose is Base {
  event AccountCloseInitiated(address _operator);

  /// @dev Tests that the `initiateAccountClose` function sets the correct state
  function test_initiateAccountClose_succeeds() public {
    vm.prank(operator);
    gasTank.initiateAccountClose();

    assertEq(gasTank.withdrawalStartedAt(operator), block.timestamp);
  }

  /// @dev Tests that the `initiateAccountClose` function emits an event
  function test_initiateAccountClose_emitsEvent() public {
    vm.expectEmit(true, true, true, true);
    emit AccountCloseInitiated(operator);

    vm.prank(operator);
    gasTank.initiateAccountClose();
  }
}

contract Unit_GasTank_closeAccount is Base {
  event AccountClosed(address _operator);

  /// @dev Tests that the `closeAccount` function reverts if the account is not closing
  function test_closeAccount_notClosing_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(IGasTank.AccountCantBeClosed.selector));
    vm.prank(operator);
    gasTank.closeAccount(operator);

    vm.warp(gasTank.WITHDRAWAL_DELAY() + 2 days);

    assertEq(gasTank.withdrawalStartedAt(operator), 0);
  }

  /// @dev Tests that the `closeAccount` function reverts if the account is closing too soon
  function testFuzz_closeAccount_tooSoon_reverts(uint256 _delay, uint64 _initialBlockTimestamp) public {
    vm.assume(_initialBlockTimestamp > gasTank.WITHDRAWAL_DELAY());
    vm.warp(_initialBlockTimestamp);

    vm.prank(operator);
    gasTank.initiateAccountClose();

    vm.assume(_delay < gasTank.WITHDRAWAL_DELAY());
    vm.warp(block.timestamp + _delay);

    vm.expectRevert(abi.encodeWithSelector(IGasTank.AccountCantBeClosed.selector));
    vm.prank(operator);
    gasTank.closeAccount(operator);

    assertEq(gasTank.withdrawalStartedAt(operator), block.timestamp - _delay);
  }

  /// @dev Tests that the `closeAccount` function reverts if the low level call fails
  function test_closeAccount_lowLevelCallFails_reverts() public {
    vm.deal(operator, 100);
    vm.prank(operator);
    gasTank.deposit{value: 100}();

    vm.prank(operator);
    gasTank.initiateAccountClose();

    vm.warp(block.timestamp + gasTank.WITHDRAWAL_DELAY());
    vm.mockCallRevert(address(operator), 100, abi.encode(), abi.encode('ERROR_MESSAGE'));
    vm.expectRevert(abi.encodeWithSelector(IGasTank.FailedLowLevelCall.selector));
    vm.prank(operator);
    gasTank.closeAccount(operator);
  }

  /// @dev Tests that the `closeAccount` function succeeds
  function test_closeAccount_succeeds() public {
    vm.deal(operator, 100);
    vm.prank(operator);
    gasTank.deposit{value: 100}();

    vm.prank(operator);
    gasTank.initiateAccountClose();

    vm.warp(block.timestamp + gasTank.WITHDRAWAL_DELAY());

    vm.prank(operator);
    gasTank.closeAccount(operator);

    assertEq(gasTank.balances(operator), 0);
    assertEq(gasTank.withdrawalStartedAt(operator), 0);
    assertEq(address(gasTank).balance, 0);
    assertEq(operator.balance, 100);
  }

  /// @dev Tests that the `closeAccount` function emits an event
  function test_closeAccount_emitsEvent() public {
    vm.deal(operator, 100);
    vm.prank(operator);
    gasTank.deposit{value: 100}();

    vm.prank(operator);
    gasTank.initiateAccountClose();

    vm.warp(block.timestamp + gasTank.WITHDRAWAL_DELAY());

    vm.expectEmit(true, true, true, true);
    emit AccountClosed(operator);

    vm.prank(operator);
    gasTank.closeAccount(operator);
  }
}
