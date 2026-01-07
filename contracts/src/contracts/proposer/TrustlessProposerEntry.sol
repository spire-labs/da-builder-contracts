// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TrustlessProposer} from 'contracts/proposer/TrustlessProposer.sol';

/// @title TrustlessProposerEntry
///
/// @notice This is the entry point for the trustless proposer
///
/// @custom:storage-location keccak256(abi.encode(uint256(keccak256("Spire.TrustlessProposer.1.0.0")) - 1)) & ~bytes32(uint256(0xff))
///
/// @dev keccak256(abi.encode(uint256(keccak256("Spire.TrustlessProposer.1.0.0")) - 1)) & ~bytes32(uint256(0xff))
///      Forge fmt doesn't support hexadecimal due to existing issue, so we use the number instead
contract TrustlessProposerEntry layout at 25_732_701_950_170_629_563_862_734_149_613_701_595_693_524_766_703_709_478_375_563_609_458_162_252_544
  is
  TrustlessProposer
{
  constructor(
    address _proposerMulticall
  ) TrustlessProposer(_proposerMulticall) {}
}
