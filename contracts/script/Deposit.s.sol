// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import {BlobAccountManager} from 'contracts/BlobAccountManager.sol';
import {Script, console} from 'forge-std/Script.sol';

// NOTE: Used internally for testing
// TODO: Cleanup
contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    // Env not working because of repo structure
    BlobAccountManager accountManager = BlobAccountManager(payable(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512));
    accountManager.deposit{value: 1e18}();
    vm.stopBroadcast();
  }
}
