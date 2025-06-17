// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {EIP712} from '@openzeppelin/contracts/utils/cryptography/EIP712.sol';
import {IProposer} from 'interfaces/proposer/IProposer.sol';

/// @title TrustlessProposer
///
/// @dev An example implementation of a proposer contract that is compatible with the aggregation service
///      Intended to be set as an EOA account code (EIP-7702)
///      This contract is meant to be an example implementation, and is stateless for the sake of simple storage management
///
/// @dev This version is an example of how a TrustlessProposer would be implemented
///      Requires custom encoding of calldata before submitting to DA Builder
///
/// @dev Marked as abstract because it should be deployed infront of a custom storage layout for safety
///      We provide this as "TrustlessProposerEntry"
abstract contract TrustlessProposer is IProposer, EIP712 {
  /// @notice Error thrown when the nonce is too low
  error NonceTooLow();

  /// @notice Error thrown when the deadline has passed
  error DeadlinePassed();

  /// @notice Error thrown when the signature is invalid
  error SignatureInvalid();

  /// @notice The typehash for the call struct
  bytes32 public constant CALL_TYPEHASH =
    keccak256('Call(uint256 deadline,uint256 nonce,address target,bytes calldata)');

  /// @notice The address of the proposer multicall contract
  address public immutable PROPOSER_MULTICALL;

  /// @notice A separate nonce for nested calls from external callers
  ///
  /// @dev Nonce is used as a uint256 instead of a mapping for gas reasons
  uint256 public nestedNonce;

  /// @notice Constructor
  ///
  /// @param _proposerMulticall The address of the proposer multicall contract
  constructor(
    address _proposerMulticall
  ) EIP712('TrustlessProposer', '1') {
    PROPOSER_MULTICALL = _proposerMulticall;
  }

  /// @dev     To support EIP 721 and EIP 1155, we need to respond to those methods with their own method signature
  ///
  /// @return  bytes4  onERC721Received function selector
  function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  /// @dev     To support EIP 721 and EIP 1155, we need to respond to those methods with their own method signature
  ///
  /// @return  bytes4  onERC1155Received function selector
  function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

  /// @dev     To support EIP 721 and EIP 1155, we need to respond to those methods with their own method signature
  ///
  /// @return  bytes4  onERC1155BatchReceived function selector
  function onERC1155BatchReceived(
    address,
    address,
    uint256[] calldata,
    uint256[] calldata,
    bytes calldata
  ) external pure returns (bytes4) {
    return this.onERC1155BatchReceived.selector;
  }

  /// @notice  nothing to do here
  ///
  /// @dev     this contract can accept ETH with calldata, hence payable
  fallback() external payable {}

  /// @notice  EIP-1155 implementation
  /// we pretty much only need to signal that we support the interface for 165, but for 1155 we also need the fallback function
  ///
  /// @param   _interfaceID  the interface we're signaling support for
  ///
  /// @return  bool  True if the interface is supported, false otherwise.
  function supportsInterface(
    bytes4 _interfaceID
  ) external pure returns (bool) {
    bool _supported = _interfaceID == 0x01ffc9a7 // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
      || _interfaceID == 0x150b7a02 // ERC721TokenReceiver
      || _interfaceID == 0x4e2312e0; // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
    return _supported;
  }

  /// @notice Fallback function to receive ether
  receive() external payable {}

  /// @notice Makes an arbitrary low level call
  ///
  /// @param _target The address to call
  /// @param _data The calldata to send
  ///
  /// @return True by default if the call succeeds
  ///
  /// @dev The interface expectation is the boolean return value matches the status of the call, if it returns false for any reason
  ///      the builder will ignore the transaction
  /// @dev Has a whitelist check to enforce an authorized caller
  /// @dev Used to allow for contracts to make arbitrary calls for an EOA
  function call(address _target, bytes calldata _data) external payable returns (bool) {
    if (msg.sender != PROPOSER_MULTICALL && address(this) != msg.sender) revert Unauthorized();

    (bytes memory _sig, uint256 _deadline, uint256 _nonce, bytes memory _calldata) =
      abi.decode(_data, (bytes, uint256, uint256, bytes));

    // Revert if deadline has passed
    // This prevents external services from holding onto the transaction
    if (block.timestamp > _deadline) revert DeadlinePassed();

    uint256 _currentNonce = nestedNonce;

    // Revert if the nested nonce is too low
    // This nonce check is needed to prevent replay attacks
    if (_currentNonce != _nonce) revert NonceTooLow();

    // Recover the signer from the signature
    bytes32 _messageHash = _hashTypedDataV4(keccak256(abi.encode(CALL_TYPEHASH, _deadline, _nonce, _target, _calldata)));

    // Signature values
    uint8 v;
    bytes32 r;
    bytes32 s;

    // ecrecover takes the signature parameters
    /// @solidity memory-safe-assembly
    assembly {
      r := mload(add(_sig, 0x20))
      s := mload(add(_sig, 0x40))
      v := byte(0, mload(add(_sig, 0x60)))
    }

    address _signer = ecrecover(_messageHash, v, r, s);

    // EIP-7702 account needs to be the signer
    if (_signer != address(this)) revert SignatureInvalid();

    (bool _success,) = _target.call{value: msg.value}(_calldata);
    if (!_success) {
      revert LowLevelCallFailed();
    }

    unchecked {
      nestedNonce = _currentNonce + 1;
    }

    return true;
  }
}
