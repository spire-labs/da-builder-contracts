// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IProposerMulticall, ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {IProposer, Proposer} from 'contracts/proposer/Proposer.sol';
import {stdError} from 'forge-std/Test.sol';
import {Base} from 'test/integration/Base.t.sol';

// The expectation is for our ProposerMulticall to work with any arbitrary proposer, so the logic of the proposer should not matter
// We do also test with a "standard" proposer
contract False_Proposer is IProposer {
  function call(address, bytes calldata) external payable returns (bool) {
    return false;
  }

  receive() external payable {}
}

contract True_Proposer is IProposer {
  function call(address, bytes calldata) external payable returns (bool) {
    return true;
  }

  receive() external payable {}
}

contract Integration_ProposerMulticall is Base {
  // Constants
  uint256 public constant TRUE_PROPOSER_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
  uint256 constant FALSE_PROPOSER_PK = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;
  uint256 public constant STANDARD_PROPOSER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

  // Addresses
  IProposer public trueProposer = IProposer(payable(vm.addr(TRUE_PROPOSER_PK)));
  IProposer public falseProposer = IProposer(payable(vm.addr(FALSE_PROPOSER_PK)));
  IProposer public standardProposer = IProposer(payable(vm.addr(STANDARD_PROPOSER_PK)));

  function setUp() public override {
    super.setUp();

    True_Proposer trueProposerImpl = new True_Proposer();
    False_Proposer falseProposerImpl = new False_Proposer();
    Proposer standardProposerImpl = new Proposer(address(proposerMulticall));

    vm.startPrank(daBuilder);
    _setAccountCode(address(trueProposerImpl), TRUE_PROPOSER_PK);
    _setAccountCode(address(falseProposerImpl), FALSE_PROPOSER_PK);
    _setAccountCode(address(standardProposerImpl), STANDARD_PROPOSER_PK);
    vm.stopPrank();
  }

  /// @dev Tests that a redeployment updates the builder
  function test_redeployment_succeeds() public {
    address newBuilder = makeAddr('newBuilder');
    address newImpl = address(new ProposerMulticall(newBuilder));

    vm.prank(proxyAdmin);
    proposerMulticall.upgradeToAndCall(newImpl, '');

    assertEq(proposerMulticall.BUILDER(), newBuilder);
    assertEq(proposerMulticall.owner(), proxyAdmin);
  }

  /// @dev Tests that multicall reverts if the proposer is a naked EOA
  function test_multicall_reverts_if_naked_eoa() public {
    address nakedProposer = makeAddr('nakedProposer');
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] =
      IProposerMulticall.Call({proposer: nakedProposer, target: address(0), data: '', value: 0, enforceRevert: true});

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.InvalidProposer.selector));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with naked eoa if enforce revert is false
  function test_multicall_passes_with_naked_eoa_if_enforce_revert_is_false() public {
    address nakedProposer = makeAddr('nakedProposer');
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] =
      IProposerMulticall.Call({proposer: nakedProposer, target: address(0), data: '', value: 0, enforceRevert: false});

    vm.expectCall(nakedProposer, abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall reverts if proposer returns false
  function test_multicall_reverts_if_false() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(falseProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.LowLevelCallFailed.selector));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall doesn't revert if proposer returns false and enforce revert is false
  function test_multicall_unenforcedRevert_with_false_return_succeeds() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(falseProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: false
    });

    vm.expectCall(address(falseProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with true proposer
  function test_multicall_passes_with_true() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with standard proposer
  function test_multicall_passes_with_standard() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });

    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with multiple different proposers
  function test_multicall_passes_with_multiple_different() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with multiple different proposers and different revert enforcements
  function test_multicall_passes_with_multiple_different_revert_enforcements() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](3);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: true
    });
    calls[2] = IProposerMulticall.Call({
      proposer: address(falseProposer),
      target: address(0),
      data: '',
      value: 0,
      enforceRevert: false
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.expectCall(address(falseProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests multicall with value
  function test_multicall_with_value() public {
    vm.deal(address(daBuilder), 100);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: true
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall{value: 100}(calls);
  }

  /// @dev Tests multiple multicalls with value
  function test_multiple_multicalls_with_value() public {
    vm.deal(address(daBuilder), 200);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: true
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: true
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall{value: 200}(calls);
  }

  /// @dev Tests multiple multicall reverts with invalid value summation
  function test_multiple_multicall_reverts_with_invalid_value_summation() public {
    vm.deal(address(daBuilder), 100);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: true
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: true
    });

    // When we run out of funds this will cause the low level call to internally revert with no calldata
    // which triggers an invalid proposer error message, potentially can be improved?
    vm.expectRevert(IProposerMulticall.InvalidProposer.selector);
    vm.prank(daBuilder);
    proposerMulticall.multicall{value: 100}(calls);
  }

  /// @dev Tests that multiple multicall with not enough value doesnt revert if enforce revert is false
  function test_multiple_multicall_with_not_enough_value_doesnt_revert_if_enforce_revert_is_false() public {
    vm.deal(address(daBuilder), 100);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: true
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 100,
      enforceRevert: false
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.call, (address(0), '')));
    vm.prank(daBuilder);
    proposerMulticall.multicall{value: 100}(calls);
  }
}
