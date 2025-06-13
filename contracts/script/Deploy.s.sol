// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BlobAccountManager} from 'contracts/BlobAccountManager.sol';
import {ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {Proposer} from 'contracts/proposer/Proposer.sol';

import {Script, console} from 'forge-std/Script.sol';
import {ERC1967Proxy} from 'openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol';

contract Deploy is Script {
  function run() external {
    address _daBuilderSigner = vm.envAddress('DA_BUILDER_SIGNER_ADDRESS');
    address _proxyAdmin = vm.envAddress('PROXY_ADMIN_ADDRESS');
    console.log('Deploying with signer for builder: ', _daBuilderSigner);
    console.log('Deploying with proxy admin: ', _proxyAdmin);

    vm.createSelectFork(vm.envString('RPC_URL'));
    vm.startBroadcast(vm.envUint('DEPLOYER_PK'));
    BlobAccountManager accountManager = BlobAccountManager(
      payable(
        address(
          new ERC1967Proxy(
            address(new BlobAccountManager()),
            abi.encodeCall(BlobAccountManager.initialize, (_proxyAdmin, _daBuilderSigner))
          )
        )
      )
    );
    console.log('BlobAccountManager deployed to: ', address(accountManager));
    ProposerMulticall proposerMulticall = ProposerMulticall(
      address(
        new ERC1967Proxy(
          address(new ProposerMulticall(_daBuilderSigner)), abi.encodeCall(ProposerMulticall.initialize, (_proxyAdmin))
        )
      )
    );
    console.log('ProposerMulticall deployed to: ', address(proposerMulticall));
    Proposer proposer = new Proposer(address(proposerMulticall));
    console.log('Proposer deployed to: ', address(proposer));

    // Sanity assertions
    assert(address(proposerMulticall).code.length > 0);
    assert(address(proposer).code.length > 0);
    assert(address(accountManager).code.length > 0);

    assert(proposerMulticall.BUILDER() == _daBuilderSigner);
    assert(proposer.PROPOSER_MULTICALL() == address(proposerMulticall));
    assert(accountManager.builder() == _daBuilderSigner);
    vm.stopBroadcast();
  }
}
