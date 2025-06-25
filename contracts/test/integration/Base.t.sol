// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {GasTank, IGasTank} from 'contracts/GasTank.sol';
import {IProposerMulticall, ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {Helpers} from 'test/utils/Helpers.sol';

abstract contract Base is Helpers {
  // Constants
  uint256 public constant MAINNET_FORK_BLOCK = 22_434_106;

  // Proxies
  ProposerMulticall public proposerMulticall;
  GasTank public gasTank;

  // Implementations
  ProposerMulticall public proposerMulticallImpl;
  GasTank public gasTankImpl;

  // Addresses
  address public daBuilder = makeAddr('daBuilder');
  address public proxyAdmin = makeAddr('proxyAdmin');

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), MAINNET_FORK_BLOCK);

    vm.startPrank(proxyAdmin);
    proposerMulticallImpl = new ProposerMulticall(daBuilder);
    gasTankImpl = new GasTank();

    gasTank = GasTank(
      payable(
        address(new ERC1967Proxy(address(gasTankImpl), abi.encodeCall(IGasTank.initialize, (proxyAdmin, daBuilder))))
      )
    );
    proposerMulticall = ProposerMulticall(
      payable(
        address(
          new ERC1967Proxy(address(proposerMulticallImpl), abi.encodeCall(IProposerMulticall.initialize, (proxyAdmin)))
        )
      )
    );

    vm.stopPrank();
  }
}

contract Integration_Setup is Base {
  /// @dev Tests that the fork is correctly set
  function test_fork_succeeds() public view {
    assertEq(block.number, MAINNET_FORK_BLOCK);
    assertEq(block.chainid, 1);
  }

  /// @dev Tests that the deployments were made correctly
  function test_deployments_succeeds() public view {
    // Version
    assertEq(proposerMulticall.version(), '1.0.0');
    assertEq(gasTank.version(), '1.0.0');

    // Initializers
    assertEq(proposerMulticall.BUILDER(), daBuilder);
    assertEq(proposerMulticall.owner(), proxyAdmin);
    assertEq(gasTank.builder(), daBuilder);
    assertEq(gasTank.owner(), proxyAdmin);

    // Proxy check
    assertEq(keccak256(address(proposerMulticall).code), keccak256(type(ERC1967Proxy).runtimeCode));
    assertEq(keccak256(address(gasTank).code), keccak256(type(ERC1967Proxy).runtimeCode));
  }
}
