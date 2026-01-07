// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {GasTank} from 'contracts/GasTank.sol';
import {Script} from 'forge-std/Script.sol';

// NOTE: Used internally for testing
// TODO: Cleanup
contract Deploy is Script {
  function run() external {
    vm.startBroadcast();
    // Env not working because of repo structure
    GasTank gasTank = GasTank(payable(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512));
    gasTank.deposit{value: 1e18}();
    vm.stopBroadcast();
  }
}
