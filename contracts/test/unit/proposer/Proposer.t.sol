// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {IProposer, Proposer} from 'contracts/proposer/Proposer.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract Base is Helpers {
  // This PK is from the publicly known anvil private keys
  // hardcoding it is safe
  uint256 constant PROPOSER_PK = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
  address proposer = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

  Proposer public proposerImplementation;
  address proposerMulticall = makeAddr('proposerMulticall');
  address nonProposer = makeAddr('nonProposer');

  function setUp() public virtual {
    proposerImplementation = new Proposer(proposerMulticall);

    vm.signAndAttachDelegation(address(proposerImplementation), PROPOSER_PK);
  }
}

contract Unit_Proposer_receive is Base {
  /// @dev Tests that receive succeeds
  function testFuzz_receive_succeeds(address _sender, uint256 _amount) public {
    vm.assume(_sender != address(proposer));

    vm.deal(_sender, _amount);

    vm.prank(_sender);
    (bool _success,) = address(proposer).call{value: _amount}('');

    assertTrue(_success);
  }
}

contract Unit_Proposer_call is Base {
  /// @dev Tests that call reverts if unauthorized
  function test_call_Unauthorized_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(IProposer.Unauthorized.selector));

    vm.prank(nonProposer);
    IProposer(proposer).call(nonProposer, '');
  }

  /// @dev Tests that call reverts if low level call fails
  function test_call_lowLevelCallFails_reverts() public {
    vm.deal(address(proposerMulticall), 100);

    vm.mockCallRevert(nonProposer, 100, abi.encode(), abi.encode('ERROR_MESSAGE'));
    vm.expectRevert(abi.encodeWithSelector(IProposer.LowLevelCallFailed.selector));

    vm.prank(address(proposerMulticall));
    IProposer(proposer).call{value: 100}(nonProposer, '');
  }

  /// @dev Tests that call succeeds
  function test_call_succeeds() public {
    vm.deal(address(proposerMulticall), 100);

    vm.prank(address(proposerMulticall));
    bool _value = IProposer(proposer).call{value: 100}(nonProposer, '');

    assertEq(nonProposer.balance, 100);
    assertTrue(_value);
  }

  /// @dev Tests that call succeeds with fuzzing
  function testFuzz_call_succeeds(uint256 _value, bytes memory _data) public {
    vm.assume(_value < 1e40);
    vm.assume(_data.length < 100);

    vm.deal(address(proposerMulticall), _value);

    vm.prank(address(proposerMulticall));
    IProposer(proposer).call{value: _value}(nonProposer, _data);

    assertEq(nonProposer.balance, _value);
  }
}
