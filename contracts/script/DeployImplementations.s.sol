// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GasTank} from 'contracts/GasTank.sol';
import {ProposerMulticall} from 'contracts/ProposerMulticall.sol';

import {OPStackProposer} from 'contracts/proposer/OPStackProposer.sol';
import {Proposer} from 'contracts/proposer/Proposer.sol';
import {TrustlessProposerEntry} from 'contracts/proposer/TrustlessProposerEntry.sol';

import {Script, console} from 'forge-std/Script.sol';

contract DeployImplementations is Script {
  function run() external {
    address multicallProxy = 0x9ccc2f3ecdE026230e11a5c8799ac7524f2bb294;

    vm.createSelectFork(vm.envString('RPC_URL'));
    vm.startBroadcast(vm.envUint('DEPLOYER_PK'));
    GasTank gasTank = new GasTank();
    console.log('GasTank deployed to: ', address(gasTank));

    ProposerMulticall proposerMulticall = new ProposerMulticall(0x8b5606469e21c75Edd7c74d1c7a65824675D9Aff);
    console.log('ProposerMulticall deployed to: ', address(proposerMulticall));

    Proposer proposer = new Proposer(multicallProxy);
    console.log('Proposer deployed to: ', address(proposer));

    OPStackProposer opStackProposer = new OPStackProposer(multicallProxy);
    console.log('OPStackProposer deployed to: ', address(opStackProposer));

    TrustlessProposerEntry trustlessProposerEntry = new TrustlessProposerEntry(multicallProxy);
    console.log('TrustlessProposerEntry deployed to: ', address(trustlessProposerEntry));

    vm.stopBroadcast();
  }
}
