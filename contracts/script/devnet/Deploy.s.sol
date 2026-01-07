// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GasTank} from 'contracts/GasTank.sol';
import {ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {SetNumber} from 'contracts/devnet/SetNumber.sol';
import {OPStackProposer} from 'contracts/proposer/OPStackProposer.sol';
import {Proposer} from 'contracts/proposer/Proposer.sol';
import {TrustlessProposerEntry} from 'contracts/proposer/TrustlessProposerEntry.sol';
import {Script, console} from 'forge-std/Script.sol';
import {ERC1967Proxy} from 'openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol';

contract Deploy is Script {
  uint256 constant ADMIN_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  uint256 constant PROPOSER_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
  uint256 constant TRUSTLESS_PROPOSER_PK = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;
  uint256 constant OPSTACK_PROPOSER_PK = 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97;
  uint256 constant SPONSOR_PK = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;

  function run() external {
    vm.startBroadcast(ADMIN_PK);
    GasTank gasTank = GasTank(
      payable(address(
          new ERC1967Proxy(
            address(new GasTank()), abi.encodeCall(GasTank.initialize, (vm.addr(ADMIN_PK), vm.addr(ADMIN_PK)))
          )
        ))
    );
    console.log('GasTank deployed to: ', address(gasTank));
    ProposerMulticall proposerMulticall = ProposerMulticall(
      address(
        new ERC1967Proxy(
          address(new ProposerMulticall(vm.addr(ADMIN_PK))),
          abi.encodeCall(ProposerMulticall.initialize, (vm.addr(ADMIN_PK)))
        )
      )
    );
    console.log('ProposerMulticall deployed to: ', address(proposerMulticall));
    Proposer proposer = new Proposer(address(proposerMulticall));
    console.log('Proposer deployed to: ', address(proposer));
    TrustlessProposerEntry trustlessProposer = new TrustlessProposerEntry(address(proposerMulticall));
    console.log('TrustlessProposer deployed to: ', address(trustlessProposer));
    OPStackProposer opStackProposer = new OPStackProposer(address(proposerMulticall));
    console.log('OPStackProposer deployed to: ', address(opStackProposer));
    SetNumber setNumber = new SetNumber();
    console.log('SetNumber deployed to: ', address(setNumber));
    vm.stopBroadcast();

    // Set the authorization list
    // Foundry for some reason is not letting us batch these, even though they can be batched
    vm.signAndAttachDelegation(address(trustlessProposer), TRUSTLESS_PROPOSER_PK);

    // Broadcast the transaction with the authorization list to set the account code
    vm.startBroadcast(SPONSOR_PK);
    (bool success,) = address(proposer).call('');
    require(success, 'Failed to set authorization list');
    vm.stopBroadcast();

    vm.signAndAttachDelegation(address(opStackProposer), OPSTACK_PROPOSER_PK);
    vm.startBroadcast(SPONSOR_PK);
    (success,) = address(proposer).call('');
    require(success, 'Failed to set authorization list');
    vm.stopBroadcast();

    vm.signAndAttachDelegation(address(proposer), PROPOSER_PK);
    vm.startBroadcast(SPONSOR_PK);
    (success,) = address(proposer).call('');
    require(success, 'Failed to set authorization list');
    vm.stopBroadcast();
  }
}
