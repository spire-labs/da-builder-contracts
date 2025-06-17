// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IProposer, TrustlessProposer} from 'contracts/proposer/TrustlessProposer.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract forTest_TrustlessProposer is TrustlessProposer {
  constructor(
    address _proposerMulticall
  ) TrustlessProposer(_proposerMulticall) {}

  function forTest_setNestedNonce(
    uint256 _nestedNonce
  ) external {
    nestedNonce = _nestedNonce;
  }

  function forTest_hashTypedDataV4(
    uint256 _deadline,
    uint256 _nonce,
    address _target,
    bytes memory _calldata
  ) external view returns (bytes32) {
    return _hashTypedDataV4(keccak256(abi.encode(CALL_TYPEHASH, _deadline, _nonce, _target, _calldata)));
  }
}

contract Base is Helpers {
  // This PK is from the publicly known anvil private keys
  // hardcoding it is safe
  uint256 constant PROPOSER_PK = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
  address payable proposer = payable(0x90F79bf6EB2c4f870365E785982E1f101E93b906);

  forTest_TrustlessProposer public proposerImplementation;
  address proposerMulticall = makeAddr('proposerMulticall');
  address nonProposer = makeAddr('nonProposer');

  function setUp() public virtual {
    proposerImplementation = new forTest_TrustlessProposer(proposerMulticall);

    vm.signAndAttachDelegation(address(proposerImplementation), PROPOSER_PK);
  }
}

contract Unit_TrustlessProposer_receive is Base {
  /// @dev Tests that receive succeeds
  function testFuzz_receive_succeeds(address _sender, uint256 _amount) public {
    vm.assume(_sender != address(proposer));

    vm.deal(_sender, _amount);

    vm.prank(_sender);
    (bool _success,) = address(proposer).call{value: _amount}('');

    assertTrue(_success);
  }
}

contract Unit_TrustlessProposer_call is Base {
  /// @dev Tests that call reverts if unauthorized
  function test_call_wrongSender_Unauthorized_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(IProposer.Unauthorized.selector));

    vm.prank(nonProposer);
    IProposer(proposer).call(nonProposer, '');
  }

  /// @dev Tests that call reverts if deadline has passed
  function testFuzz_call_DeadlinePassed_reverts(
    uint256 _timePassed
  ) public {
    _timePassed = bound(_timePassed, 1, 1e40);

    uint256 _currentTime = block.timestamp;
    vm.assume(_timePassed > 0);
    vm.warp(_currentTime + _timePassed);

    vm.expectRevert(abi.encodeWithSelector(TrustlessProposer.DeadlinePassed.selector));

    vm.prank(proposerMulticall);
    IProposer(proposer).call(nonProposer, abi.encode(bytes(''), _currentTime, 0, ''));
  }

  /// @dev Tests that call reverts if nonce is too low
  function testFuzz_call_NonceToLow_reverts(
    uint256 _nonce
  ) public {
    vm.assume(_nonce > 0);
    forTest_TrustlessProposer(proposer).forTest_setNestedNonce(_nonce);

    vm.expectRevert(abi.encodeWithSelector(TrustlessProposer.NonceTooLow.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer).call(nonProposer, abi.encode(bytes(''), block.timestamp, _nonce - 1, ''));
  }

  /// @dev Tests that call reverts if signature is invalid
  function testFuzz_call_SignatureInvalid_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(TrustlessProposer.SignatureInvalid.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer).call(nonProposer, abi.encode(bytes(''), block.timestamp, 0, ''));
  }

  /// @dev Tests that call reverts if low level call fails
  function testFuzz_call_LowLevelCallFailed_reverts() public {
    vm.mockCallRevert(nonProposer, abi.encode(), abi.encode('ERROR_MESSAGE'));

    bytes32 digest = forTest_TrustlessProposer(proposer).forTest_hashTypedDataV4(block.timestamp, 0, nonProposer, '');
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PROPOSER_PK, digest);

    vm.expectRevert(abi.encodeWithSelector(IProposer.LowLevelCallFailed.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer).call(nonProposer, abi.encode(abi.encodePacked(r, s, v), block.timestamp, 0, bytes('')));
  }

  /// @dev Tests that call succeeds
  function testFuzz_call_succeeds() public {
    bytes32 digest = forTest_TrustlessProposer(proposer).forTest_hashTypedDataV4(block.timestamp, 0, nonProposer, '');
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PROPOSER_PK, digest);

    vm.prank(proposerMulticall);
    bool result =
      IProposer(proposer).call(nonProposer, abi.encode(abi.encodePacked(r, s, v), block.timestamp, 0, bytes('')));

    assertTrue(result);
  }
}

contract Unit_TrustlessProposer_ERCReceiver is Base {
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
