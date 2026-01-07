// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IProposer, TrustlessProposer} from 'contracts/proposer/TrustlessProposer.sol';
import {Helpers} from 'test/utils/Helpers.sol';

contract forTest_GasConsumer {
  /// @notice Event emitted when gas is consumed, for debugging tests if needed
  event GasConsumed(uint256 gasUsed);

  /// @notice Variable to read/write to to waste gas
  uint256 internal __gasWaster;

  /// @notice Consumes 2 million gas
  ///
  /// @dev Not exact, but good enough for our purposes
  function consumeGas() public {
    uint256 gasLeft = gasleft();
    uint256 gasUsed = 0;
    while (gasUsed < 2_000_000) {
      __gasWaster++;
      gasUsed = gasLeft - gasleft();
    }

    emit GasConsumed(gasUsed);
  }
}

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
    uint256 _value,
    bytes memory _calldata,
    uint256 _gasLimit
  ) external view returns (bytes32) {
    return _hashTypedDataV4(
      keccak256(abi.encode(CALL_TYPEHASH, _deadline, _nonce, _target, _value, keccak256(_calldata), _gasLimit))
    );
  }
}

contract Base is Helpers {
  // This PK is from the publicly known anvil private keys
  // hardcoding it is safe
  uint256 constant PROPOSER_PK = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;
  address payable proposer = payable(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);

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

contract Unit_TrustlessProposer_call is Base {
  /// @dev Tests that call reverts if unauthorized
  function test_call_wrongSender_Unauthorized_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(IProposer.Unauthorized.selector));

    vm.prank(nonProposer);
    IProposer(proposer).onCall(nonProposer, '', 0);
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
    IProposer(proposer).onCall(nonProposer, abi.encode(bytes(''), _currentTime, 0, ''), 0);
  }

  /// @dev Tests that call reverts if nonce is too low
  function testFuzz_call_NonceToLow_reverts(
    uint256 _nonce
  ) public {
    vm.assume(_nonce > 0);
    forTest_TrustlessProposer(proposer).forTest_setNestedNonce(_nonce);

    vm.expectRevert(abi.encodeWithSelector(TrustlessProposer.NonceTooLow.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer).onCall(nonProposer, abi.encode(bytes(''), block.timestamp, _nonce - 1, ''), 0);
  }

  /// @dev Tests that call reverts if signature is invalid
  function test_call_SignatureInvalid_reverts() public {
    vm.expectRevert(abi.encodeWithSelector(TrustlessProposer.SignatureInvalid.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer).onCall(nonProposer, abi.encode(bytes(''), block.timestamp, 0, ''), 0);
  }

  /// @dev Tests that call reverts if low level call fails
  function test_call_LowLevelCallFailed_reverts() public {
    vm.mockCallRevert(nonProposer, abi.encode(), abi.encode('ERROR_MESSAGE'));

    bytes32 digest =
      forTest_TrustlessProposer(proposer).forTest_hashTypedDataV4(block.timestamp, 0, nonProposer, 0, '', 1_000_000);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PROPOSER_PK, digest);

    vm.expectRevert(abi.encodeWithSelector(IProposer.LowLevelCallFailed.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer)
      .onCall(nonProposer, abi.encode(abi.encodePacked(r, s, v), block.timestamp, 0, bytes(''), 1_000_000), 0);
  }

  /// @dev Tests that call reverts if gas limit is exceeded
  function test_call_GasLimitExceeded_reverts() public {
    forTest_GasConsumer gasConsumer = new forTest_GasConsumer();
    bytes memory _calldata = abi.encodeCall(forTest_GasConsumer.consumeGas, ());

    bytes32 digest = forTest_TrustlessProposer(proposer)
      .forTest_hashTypedDataV4(block.timestamp, 0, address(gasConsumer), 0, _calldata, 1_000_000);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PROPOSER_PK, digest);

    // Foundry will provide enough gas for the call to succeed, our error should catch it and revert
    vm.expectRevert(abi.encodeWithSelector(TrustlessProposer.GasLimitExceeded.selector));
    vm.prank(proposerMulticall);
    IProposer(proposer)
      .onCall(address(gasConsumer), abi.encode(abi.encodePacked(r, s, v), block.timestamp, 0, _calldata, 1_000_000), 0);
  }

  /// @dev Tests that call succeeds
  function test_call_succeeds() public {
    bytes32 digest =
      forTest_TrustlessProposer(proposer).forTest_hashTypedDataV4(999_999_999_999, 0, address(0), 0, '', 1_000_000);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(PROPOSER_PK, digest);

    vm.prank(proposerMulticall);
    bool result = IProposer(proposer)
      .onCall(address(0), abi.encode(abi.encodePacked(r, s, v), 999_999_999_999, 0, bytes(''), 1_000_000), 0);

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
