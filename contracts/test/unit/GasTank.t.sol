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
  event BuilderSet(address _builder);

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

  /// @dev Tests that the `setBuilder` function emits an event
  function test_setBuilder_emitsEvent() public {
    vm.expectEmit(true, true, true, true);
    emit BuilderSet(nonOperator);

    vm.prank(owner);
    gasTank.setBuilder(nonOperator);
  }
}

contract Unit_GasTank_deposit is Base {
  event AccountDeposited(address _operator, uint256 _newBalance);

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
    uint256 deposit,
    uint256 length
  ) public {
    vm.deal(operator, type(uint256).max);
    vm.assume(length < 10);
    vm.assume(deposit < 1e40);

    for (uint256 i; i < length; i++) {
      uint256 _balanceBefore = gasTank.balances(operator);
      uint256 _contractBalanceBefore = address(gasTank).balance;

      vm.prank(operator);
      gasTank.deposit{value: deposit}();

      assertEq(gasTank.balances(operator), _balanceBefore + deposit);
      assertEq(address(gasTank).balance, _contractBalanceBefore + deposit);
    }
  }
}

contract Unit_GasTank_depositOnBehalfOf is Base {
  event AccountDeposited(address _operator, uint256 _newBalance);

  address beneficiary = makeAddr('beneficiary');

  /// @dev Tests that the `deposit` function succeeds
  function test_depositOnBehalfOf_succeeds() public {
    vm.deal(operator, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}(beneficiary);

    assertEq(gasTank.balances(beneficiary), 100);
    assertEq(address(gasTank).balance, 100);
  }

  /// @dev Tests that the `deposit` function emits an event
  function test_depositOnBehalfOf_emitsEvent() public {
    vm.deal(operator, 100);

    vm.expectEmit(true, true, true, true);
    emit AccountDeposited(beneficiary, 100);

    vm.prank(operator);
    gasTank.deposit{value: 100}(beneficiary);
  }

  /// @dev Tests that the `deposit` function works with fuzzing
  function testFuzz_depositOnBehalfOf_succeeds(
    uint256 deposit,
    address randomBeneficiary
  ) public {
    vm.deal(operator, deposit);
    vm.assume(randomBeneficiary != operator);

    vm.prank(operator);
    gasTank.deposit{value: deposit}(randomBeneficiary);

    assertEq(gasTank.balances(randomBeneficiary), deposit);
    assertEq(address(gasTank).balance, deposit);
  }

  /// @dev Tests that the `deposit` works with multiple different deposits
  function testFuzz_depositOnBehalfOf_multipleDeposits_succeeds(
    uint256 deposit,
    address randomBeneficiary,
    uint256 length
  ) public {
    vm.deal(operator, type(uint256).max);
    vm.assume(length < 10);
    vm.assume(randomBeneficiary != operator);
    vm.assume(deposit < 1e40);

    for (uint256 i; i < length; i++) {
      uint256 _balanceBefore = gasTank.balances(randomBeneficiary);
      uint256 _contractBalanceBefore = address(gasTank).balance;

      vm.prank(operator);
      gasTank.deposit{value: deposit}(randomBeneficiary);

      assertEq(gasTank.balances(randomBeneficiary), _balanceBefore + deposit);
      assertEq(address(gasTank).balance, _contractBalanceBefore + deposit);
    }
  }
}

contract Unit_GasTank_withdraw is Base {
  event Withdrawn(uint256 _amount);

  /// @dev Tests that the `withdraw` function reverts if the caller is not the builder
  function test_withdraw_onlyBuilder_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(IGasTank.NotBuilder.selector));
    vm.prank(nonOperator);
    gasTank.withdraw(100);
  }

  /// @dev Tests that the `withdraw` function succeeds if the caller is the builder
  function testFuzz_withdraw_succeeds(
    uint256 amount
  ) public {
    vm.deal(address(gasTank), amount);

    vm.prank(owner);
    gasTank.withdraw(amount);

    assertEq(address(gasTank).balance, 0);
    assertEq(owner.balance, amount);
  }

  /// @dev Tests that the `withdraw` function emits an event
  function testFuzz_withdraw_emitsEvent(
    uint256 amount
  ) public {
    vm.deal(address(gasTank), amount);

    vm.expectEmit(true, true, true, true);
    emit Withdrawn(amount);

    vm.prank(owner);
    gasTank.withdraw(amount);
  }
}
