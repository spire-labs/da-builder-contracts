// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IProposerMulticall, ProposerMulticall} from 'contracts/ProposerMulticall.sol';

import {OPStackProposer} from 'contracts/proposer/OPStackProposer.sol';
import {IProposer, Proposer} from 'contracts/proposer/Proposer.sol';
import {Base} from 'test/integration/Base.t.sol';

// The expectation is for our ProposerMulticall to work with any arbitrary proposer, so the logic of the proposer should not matter
// We do also test with a "standard" proposer
contract False_Proposer is IProposer {
  function onCall(
    address,
    bytes calldata,
    uint256
  ) external pure returns (bool) {
    return false;
  }

  receive() external payable {}
}

contract True_Proposer is IProposer {
  function onCall(
    address,
    bytes calldata,
    uint256
  ) external pure returns (bool) {
    return true;
  }

  receive() external payable {}
}

contract Integration_ProposerMulticall is Base {
  // Constants
  uint256 public constant TRUE_PROPOSER_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
  uint256 constant FALSE_PROPOSER_PK = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;
  uint256 public constant STANDARD_PROPOSER_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  uint256 public constant OP_STACK_PROPOSER_PK = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;

  // Addresses
  IProposer public trueProposer = IProposer(payable(vm.addr(TRUE_PROPOSER_PK)));
  IProposer public falseProposer = IProposer(payable(vm.addr(FALSE_PROPOSER_PK)));
  IProposer public standardProposer = IProposer(payable(vm.addr(STANDARD_PROPOSER_PK)));
  IProposer public opStackProposer = IProposer(payable(vm.addr(OP_STACK_PROPOSER_PK)));

  function setUp() public override {
    super.setUp();

    True_Proposer trueProposerImpl = new True_Proposer();
    False_Proposer falseProposerImpl = new False_Proposer();
    Proposer standardProposerImpl = new Proposer(address(proposerMulticall));
    OPStackProposer opStackProposerImpl = new OPStackProposer(address(proposerMulticall));

    vm.startPrank(daBuilder);
    _setAccountCode(address(trueProposerImpl), TRUE_PROPOSER_PK);
    _setAccountCode(address(falseProposerImpl), FALSE_PROPOSER_PK);
    _setAccountCode(address(standardProposerImpl), STANDARD_PROPOSER_PK);
    _setAccountCode(address(opStackProposerImpl), OP_STACK_PROPOSER_PK);
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
      IProposerMulticall.Call({proposer: nakedProposer, target: address(0), data: '', value: 0, gasLimit: 21_000});

    vm.expectRevert();
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall reverts if proposer returns false
  function test_multicall_reverts_if_false() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(falseProposer), target: address(0), data: '', value: 0, gasLimit: 21_000
    });

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.LowLevelCallFailed.selector));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall reverts if the call runs out of gas
  function test_multicall_reverts_if_out_of_gas() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] =
      IProposerMulticall.Call({proposer: address(trueProposer), target: address(0), data: '', value: 0, gasLimit: 0});

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.OutOfGas.selector));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with true proposer
  function test_multicall_passes_with_true() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer), target: address(0), data: '', value: 0, gasLimit: 21_000
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 0)));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with standard proposer
  function test_multicall_passes_with_standard() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(standardProposer), target: address(0), data: '', value: 0, gasLimit: 21_000
    });

    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 0)));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests that multicall passes with multiple different proposers
  function test_multicall_passes_with_multiple_different() public {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);
    calls[0] = IProposerMulticall.Call({
      proposer: address(trueProposer), target: address(0), data: '', value: 0, gasLimit: 21_000
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer), target: address(0), data: '', value: 0, gasLimit: 21_000
    });

    vm.expectCall(address(trueProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 0)));
    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 0)));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  /// @dev Tests multicall with value
  function test_multicall_with_value() public {
    vm.deal(address(standardProposer), 100);

    uint256 _preBalance = address(0).balance;

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(standardProposer), target: address(0), data: '', value: 100, gasLimit: 21_000
    });

    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 100)));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);

    assertEq(address(standardProposer).balance, 0);
    assertEq(address(0).balance, _preBalance + 100);
  }

  /// @dev Tests multiple multicalls with value
  function test_multiple_multicalls_with_value() public {
    vm.deal(address(standardProposer), 200);

    uint256 _preBalance = address(0).balance;

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);
    calls[0] = IProposerMulticall.Call({
      proposer: address(standardProposer), target: address(0), data: '', value: 100, gasLimit: 21_000
    });
    calls[1] = IProposerMulticall.Call({
      proposer: address(standardProposer),
      target: address(0),
      data: '',
      value: 100,
      gasLimit: 25_000 // Needs to be 25k because there is some overhead from the internal Proposer logic
    });

    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 100)));
    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.onCall, (address(0), '', 100)));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);

    assertEq(address(standardProposer).balance, 0);
    assertEq(address(0).balance, _preBalance + 200);
  }

  /// @dev Tests multicall with a random EOA
  function test_multicall_random_eoa_with_value() public {
    address _eoa = makeAddr('eoa');
    vm.assume(_eoa.code.length == 0);
    // Assume no precompiles not working for some reason, so we do this
    vm.assume(uint256(uint160(_eoa)) > uint256(uint160(address(256))));

    vm.deal(address(standardProposer), 100);

    uint256 _preBalance = _eoa.balance;

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(standardProposer), target: _eoa, data: '', value: 100, gasLimit: 100_000
    });

    vm.expectCall(address(standardProposer), abi.encodeCall(IProposer.onCall, (_eoa, '', 100)));
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);

    assertEq(address(standardProposer).balance, 0);
    assertEq(address(_eoa).balance, _preBalance + 100);
  }

  function test_multicall_passes_with_op_stack() public {
    bytes32[] memory _versionedHashes = new bytes32[](1);
    _versionedHashes[0] = keccak256('test');

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(opStackProposer),
      target: address(opStackProposer),
      data: abi.encode(_versionedHashes),
      value: 0,
      gasLimit: 21_000
    });

    vm.expectCall(
      address(opStackProposer),
      abi.encodeCall(IProposer.onCall, (address(opStackProposer), abi.encode(_versionedHashes), 0))
    );
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }

  function test_multicall_passes_with_op_stack_max_blobs() public {
    // The max from manual testing with 9 blobs is 13_429 internal gas used
    uint256[] memory _gasUsed = new uint256[](1);
    _gasUsed[0] = 13_429;

    // Current max blobs is 9, so we need to test with 9
    bytes32[] memory _versionedHashes = new bytes32[](9);
    _versionedHashes[0] = keccak256('test');
    _versionedHashes[1] = keccak256('test2');
    _versionedHashes[2] = keccak256('test3');
    _versionedHashes[3] = keccak256('test4');
    _versionedHashes[4] = keccak256('test5');
    _versionedHashes[5] = keccak256('test6');
    _versionedHashes[6] = keccak256('test7');
    _versionedHashes[7] = keccak256('test8');
    _versionedHashes[8] = keccak256('test9');

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call({
      proposer: address(opStackProposer),
      target: address(opStackProposer),
      data: abi.encode(_versionedHashes),
      value: 0,
      gasLimit: 21_000
    });

    vm.expectEmit(true, true, true, true);
    emit IProposerMulticall.InternalGasUsed(_gasUsed);

    vm.expectCall(
      address(opStackProposer),
      abi.encodeCall(IProposer.onCall, (address(opStackProposer), abi.encode(_versionedHashes), 0))
    );
    vm.prank(daBuilder);
    proposerMulticall.multicall(calls);
  }
}
