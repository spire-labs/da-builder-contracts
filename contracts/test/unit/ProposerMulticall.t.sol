// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {IProposerMulticall, ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {IProposer} from 'interfaces/proposer/IProposer.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract Base is Helpers {
  // This is the builder address hypothetically
  address builder = makeAddr('builder');
  address multicall;

  ProposerMulticall public multicallImplementation;
  address proposer = makeAddr('proposer');
  address nonProposer = makeAddr('nonProposer');
  address nonProposer2 = makeAddr('nonProposer2');

  function setUp() public virtual {
    multicallImplementation = new ProposerMulticall(builder);
    multicall = address(new ERC1967Proxy(address(multicallImplementation), ''));
    IProposerMulticall(multicall).initialize(builder);
  }
}

contract Unit_ProposerMulticall_constructor is Base {
  /// @dev Tests that the constructor sets the correct state
  function test_constructor_succeeds() public view {
    assertEq(IProposerMulticall(multicall).BUILDER(), builder);
  }
}

contract Unit_ProposerMulticall_authorizeUpgrade is Base {
  error OwnableUnauthorizedAccount(address account);

  /// @dev Tests that the `authorizeUpgrade` function reverts if the caller is not the owner
  function testFuzz_authorizeUpgrade_onlyOwner_reverts(
    address nonOwner
  ) public {
    vm.assume(nonOwner != builder);

    vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, nonOwner));
    vm.prank(nonOwner);
    // Random address
    ProposerMulticall(multicall).upgradeToAndCall(nonProposer, '');
  }
}

contract Unit_ProposerMulticall_multicall is Base {
  /// @dev Tests that multicall reverts if unauthorized
  function testFuzz_multicall_Unauthorized_reverts(
    address _sender
  ) public {
    vm.assume(_sender != address(builder));

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.Unauthorized.selector));

    vm.prank(_sender);
    IProposerMulticall(multicall).multicall(new IProposerMulticall.Call[](0));
  }

  /// @dev Tests that multicall reverts if proposer call returns false
  function test_multicall_reverts_if_false() external {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);

    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 0, 21_000);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 0)), abi.encode(false));

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.LowLevelCallFailed.selector));
    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall reverts if it ran out of gas
  function test_multicall_outOfGas_reverts() external {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 0, 0);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 0)), abi.encode(true));

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.OutOfGas.selector));
    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall succeeds with a no value call
  function test_multicall_noValue_succeeds() external {
    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);

    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 0, 21_000);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 0)), abi.encode(true));

    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall succeeds with a value call
  function test_multicall_value_succeeds() external {
    vm.deal(address(proposer), 100);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);

    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 100, 21_000);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 100)), abi.encode(true));

    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall reverts if the low level call fails and revert is enforced
  function test_multicall_lowLevelCallFails_reverts() external {
    vm.deal(address(proposer), 100);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 100, 21_000);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 100)), abi.encode(false));

    vm.expectRevert(abi.encodeWithSelector(IProposerMulticall.LowLevelCallFailed.selector));
    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall succeeds with multiple calls
  function test_multicall_multipleCalls_succeeds() external {
    vm.deal(address(proposer), 200);

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](2);

    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 100, 21_000);
    calls[1] = IProposerMulticall.Call(proposer, nonProposer2, '', 100, 21_000);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 100)), abi.encode(true));
    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer2, '', 100)), abi.encode(true));

    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall emits the internal gas used
  function test_multicall_emits_internalGasUsed() external {
    uint256[] memory _internalCallsGasUsed = new uint256[](1);
    // This is the amount expected from the mock
    _internalCallsGasUsed[0] = 1684;

    IProposerMulticall.Call[] memory calls = new IProposerMulticall.Call[](1);
    calls[0] = IProposerMulticall.Call(proposer, nonProposer, '', 0, 2580);

    vm.expectEmit(true, true, true, true);
    emit IProposerMulticall.InternalGasUsed(_internalCallsGasUsed);

    _mockAndExpect(proposer, abi.encodeCall(IProposer.onCall, (nonProposer, '', 0)), abi.encode(true));

    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }

  /// @dev Tests that multicall succeeds with fuzzing
  function testFuzz_multicall_succeeds(
    IProposerMulticall.Call[] memory calls,
    uint256 summationValue
  ) public {
    vm.assume(calls.length < 10);
    summationValue = bound(summationValue, 1e8 * 10, type(uint256).max - 1);

    for (uint256 i; i < calls.length; ++i) {
      // This is fine because we always mock the return of the call anyway
      vm.assume(calls[i].gasLimit > 100_000);
      calls[i].value = bound(calls[i].value, 1, 1e8);
      // getting weird conflicts with foundry vm without this weird bound
      calls[i].proposer = address(uint160(bound(uint256(uint160(proposer)), type(uint64).max, type(uint160).max - 1)));
      vm.deal(calls[i].proposer, calls[i].value);
      _mockAndExpect(
        calls[i].proposer,
        abi.encodeCall(IProposer.onCall, (calls[i].target, calls[i].data, calls[i].value)),
        abi.encode(true)
      );
    }

    vm.prank(address(builder));
    IProposerMulticall(multicall).multicall(calls);
  }
}

contract Unit_ProposerMulticall_receive is Base {
  /// @dev Tests that receive succeeds
  function testFuzz_receive_succeeds(
    address _sender,
    uint256 _amount
  ) public {
    vm.assume(_sender != address(builder));

    vm.deal(_sender, _amount);

    vm.prank(_sender);
    (bool _success,) = address(builder).call{value: _amount}('');

    assertTrue(_success);
  }
}
