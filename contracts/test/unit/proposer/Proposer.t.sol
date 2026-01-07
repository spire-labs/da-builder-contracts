// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

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
  function testFuzz_receive_succeeds(
    address _sender,
    uint256 _amount
  ) public {
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
    IProposer(proposer).onCall(nonProposer, '', 0);
  }

  /// @dev Tests that call reverts if low level call fails
  function test_call_lowLevelCallFails_reverts() public {
    vm.deal(address(proposer), 100);

    vm.mockCallRevert(nonProposer, 100, abi.encode(), abi.encode('ERROR_MESSAGE'));
    vm.expectRevert(abi.encodeWithSelector(IProposer.LowLevelCallFailed.selector));

    vm.prank(address(proposerMulticall));
    IProposer(proposer).onCall(nonProposer, '', 100);
  }

  /// @dev Tests that call succeeds
  function test_call_succeeds() public {
    vm.deal(address(proposer), 100);

    vm.prank(address(proposerMulticall));
    bool _returnedValue = IProposer(proposer).onCall(nonProposer, '', 100);

    assertEq(nonProposer.balance, 100);
    assertEq(address(proposer).balance, 0);
    assertTrue(_returnedValue);
  }

  /// @dev Tests that call succeeds with fuzzing
  function testFuzz_call_succeeds(
    uint256 _value,
    bytes memory _data
  ) public {
    vm.assume(_value < 1e40);
    vm.assume(_data.length < 100);

    vm.deal(address(proposer), _value);

    vm.prank(address(proposerMulticall));
    IProposer(proposer).onCall(nonProposer, _data, _value);

    assertEq(nonProposer.balance, _value);
    assertEq(address(proposer).balance, 0);
  }
}

contract Unit_Proposer_ERCReceiver is Base {
  /// @dev Tests that onERC721Received returns the correct selector
  function test_onERC721Received_returnsCorrectSelector() public view {
    bytes4 selector = proposerImplementation.onERC721Received(address(0), address(0), 0, '');
    assertEq(selector, proposerImplementation.onERC721Received.selector);
  }

  /// @dev Tests that onERC1155Received returns the correct selector
  function test_onERC1155Received_returnsCorrectSelector() public view {
    bytes4 selector = proposerImplementation.onERC1155Received(address(0), address(0), 0, 0, '');
    assertEq(selector, proposerImplementation.onERC1155Received.selector);
  }

  /// @dev Tests that onERC1155BatchReceived returns the correct selector
  function test_onERC1155BatchReceived_returnsCorrectSelector() public view {
    uint256[] memory ids = new uint256[](0);
    uint256[] memory values = new uint256[](0);
    bytes4 selector = proposerImplementation.onERC1155BatchReceived(address(0), address(0), ids, values, '');
    assertEq(selector, proposerImplementation.onERC1155BatchReceived.selector);
  }

  /// @dev Tests that supportsInterface returns true for ERC165 interface
  function test_supportsInterface_ERC165_returnsTrue() public view {
    assertTrue(proposerImplementation.supportsInterface(0x01ffc9a7));
  }

  /// @dev Tests that supportsInterface returns true for ERC721TokenReceiver interface
  function test_supportsInterface_ERC721TokenReceiver_returnsTrue() public view {
    assertTrue(proposerImplementation.supportsInterface(0x150b7a02));
  }

  /// @dev Tests that supportsInterface returns true for ERC1155TokenReceiver interface
  function test_supportsInterface_ERC1155TokenReceiver_returnsTrue() public view {
    assertTrue(proposerImplementation.supportsInterface(0x4e2312e0));
  }

  /// @dev Tests that supportsInterface returns false for unknown interface
  function test_supportsInterface_unknownInterface_returnsFalse() public view {
    assertFalse(proposerImplementation.supportsInterface(0x12345678));
  }
}
