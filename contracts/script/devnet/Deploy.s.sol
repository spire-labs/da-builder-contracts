// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GasTank} from 'contracts/GasTank.sol';
import {ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {Proposer} from 'contracts/proposer/Proposer.sol';
import {Script, console} from 'forge-std/Script.sol';
import {ERC1967Proxy} from 'openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol';

contract Deploy is Script {
  uint256 constant ADMIN_PK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
  uint256 constant PROPOSER_PK = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
  uint256 constant SPONSOR_PK = 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a;

  function run() external {
    vm.startBroadcast(ADMIN_PK);
    GasTank gasTank = GasTank(
      payable(
        address(
          new ERC1967Proxy(
            address(new GasTank()), abi.encodeCall(GasTank.initialize, (vm.addr(ADMIN_PK), vm.addr(ADMIN_PK)))
          )
        )
      )
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
    vm.stopBroadcast();

    // Set the authorization list
    vm.signAndAttachDelegation(address(proposerMulticall), ADMIN_PK);
    vm.signAndAttachDelegation(address(proposer), PROPOSER_PK);

    // Broadcast the transaction with the authorization list to set the account code
    vm.startBroadcast(SPONSOR_PK);
    address(proposer).call('');
    vm.stopBroadcast();
  }
}
