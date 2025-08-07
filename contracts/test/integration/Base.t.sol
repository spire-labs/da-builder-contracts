// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {GasTank, IGasTank} from 'contracts/GasTank.sol';
import {IProposerMulticall, ProposerMulticall} from 'contracts/ProposerMulticall.sol';
import {Helpers} from 'test/utils/Helpers.sol';

abstract contract Base is Helpers {
  // Constants
  uint256 public constant MAINNET_FORK_BLOCK = 22_932_368;

  // Proxies
  ProposerMulticall public proposerMulticall = ProposerMulticall(payable(0x9ccc2f3ecdE026230e11a5c8799ac7524f2bb294));
  GasTank public gasTank = GasTank(payable(0x2565c0A726cB0f2F79cd16510c117B4da6a6534b));

  // Implementations
  ProposerMulticall public proposerMulticallImpl;
  GasTank public gasTankImpl;

  // Addresses
  address public daBuilder = makeAddr('daBuilder');
  address public proxyAdmin = 0xE6419B6df836aa33e642F8E9663Ad003F996306C;

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl('mainnet'), MAINNET_FORK_BLOCK);

    vm.startPrank(proxyAdmin);
    proposerMulticallImpl = new ProposerMulticall(daBuilder);
    gasTankImpl = new GasTank();
    vm.stopPrank();

    // Upgrade the proxies
    _upgrade(proposerMulticallImpl, gasTankImpl);
  }

  function _upgrade(ProposerMulticall _proposerMulticallImpl, GasTank _gasTankImpl) internal {
    // Contracts on mainnet should already be initialized
    vm.startPrank(proxyAdmin);
    proposerMulticall.upgradeToAndCall(address(_proposerMulticallImpl), '');
    gasTank.upgradeToAndCall(address(_gasTankImpl), abi.encodeCall(IGasTank.setBuilder, (daBuilder)));
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
    // Initializers
    assertEq(proposerMulticall.BUILDER(), daBuilder);
    assertEq(proposerMulticall.owner(), proxyAdmin);
    assertEq(gasTank.builder(), daBuilder);
    assertEq(gasTank.owner(), proxyAdmin);

    // Version checks
    assertEq(proposerMulticall.version(), proposerMulticallImpl.version());
    assertEq(gasTank.version(), gasTankImpl.version());

    // Check implementation code is correct
    // This is the slot for ERC1967 Proxy implementation address
    address proposerMulticallImplFromProxy = address(
      uint160(
        uint256(vm.load(address(proposerMulticall), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
      )
    );
    address gasTankImplFromProxy = address(
      uint160(uint256(vm.load(address(gasTank), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc)))
    );

    // Check implementation addresses are correct
    assertEq(proposerMulticallImplFromProxy, address(proposerMulticallImpl));
    assertEq(gasTankImplFromProxy, address(gasTankImpl));

    // Check implementation code is correct
    assertEq(keccak256(proposerMulticallImplFromProxy.code), keccak256(address(proposerMulticallImpl).code));
    assertEq(keccak256(gasTankImplFromProxy.code), keccak256(address(gasTankImpl).code));
  }
}
