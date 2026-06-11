// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Initializable} from 'src/dependencies/openzeppelin-upgradeable/Initializable.sol';
import {OwnableUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/OwnableUpgradeable.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IERC1967} from 'src/dependencies/openzeppelin/IERC1967.sol';
import {
  TransparentUpgradeableProxy,
  ITransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {V4AddressesProviderInstance} from 'src/addresses-provider/instances/V4AddressesProviderInstance.sol';
import {MockV4AddressesProviderInstance} from 'tests/helpers/mocks/MockV4AddressesProviderInstance.sol';
import {ProxyHelpers} from 'tests/helpers/commons/ProxyHelpers.sol';

contract V4AddressesProviderUpgradeableTest is Test, ProxyHelpers {
  address internal OWNER = makeAddr('OWNER');
  address internal proxyAdminOwner = makeAddr('proxyAdminOwner');

  function test_implementation_constructor_fuzz(uint64 revision) public {
    address implAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    vm.expectEmit(implAddress);
    emit Initializable.Initialized(type(uint64).max);

    MockV4AddressesProviderInstance impl = new MockV4AddressesProviderInstance(revision);

    assertEq(address(impl), implAddress);
    assertEq(impl.ADDRESSES_PROVIDER_REVISION(), revision);
    assertEq(_getProxyInitializedVersion(implAddress), type(uint64).max);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    impl.initialize(OWNER);
  }

  function test_proxy_constructor_fuzz(uint64 revision) public {
    revision = uint64(bound(revision, 1, type(uint64).max));

    MockV4AddressesProviderInstance impl = new MockV4AddressesProviderInstance(revision);
    address proxyAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)));
    address proxyAdminAddress = vm.computeCreateAddress(proxyAddress, 1);

    vm.expectEmit(proxyAddress);
    emit IERC1967.Upgraded(address(impl));
    vm.expectEmit(proxyAddress);
    emit OwnableUpgradeable.OwnershipTransferred(address(0), OWNER);
    vm.expectEmit(proxyAddress);
    emit Initializable.Initialized(revision);
    vm.expectEmit(proxyAdminAddress);
    emit OwnableUpgradeable.OwnershipTransferred(address(0), proxyAdminOwner);
    vm.expectEmit(proxyAddress);
    emit IERC1967.AdminChanged(address(0), proxyAdminAddress);

    address proxy = _proxify(address(impl));

    assertEq(proxy, proxyAddress);
    assertEq(_getProxyAdminAddress(proxy), proxyAdminAddress);
    assertEq(_getImplementationAddress(proxy), address(impl));

    assertEq(_getProxyInitializedVersion(proxy), revision);
    assertEq(Ownable2StepUpgradeable(proxy).owner(), OWNER);
  }

  function test_proxy_reinitialization_fuzz(uint64 initialRevision) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max - 1));
    MockV4AddressesProviderInstance impl = new MockV4AddressesProviderInstance(initialRevision);
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(_proxify(address(impl)));

    uint64 secondRevision = uint64(vm.randomUint(initialRevision + 1, type(uint64).max));
    MockV4AddressesProviderInstance impl2 = new MockV4AddressesProviderInstance(secondRevision);

    vm.expectEmit(address(proxy));
    emit OwnableUpgradeable.OwnershipTransferred(OWNER, OWNER);
    vm.prank(_getProxyAdminAddress(address(proxy)));
    proxy.upgradeToAndCall(
      address(impl2),
      abi.encodeCall(MockV4AddressesProviderInstance.initialize, (OWNER))
    );

    assertEq(Ownable2StepUpgradeable(address(proxy)).owner(), OWNER);
  }

  function test_proxy_constructor_revertsWith_InvalidInitialization_ZeroRevision() public {
    MockV4AddressesProviderInstance impl = new MockV4AddressesProviderInstance(0);

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    _proxify(address(impl));
  }

  function test_proxy_constructor_fuzz_revertsWith_InvalidInitialization(
    uint64 initialRevision
  ) public {
    initialRevision = uint64(bound(initialRevision, 1, type(uint64).max));

    MockV4AddressesProviderInstance impl = new MockV4AddressesProviderInstance(initialRevision);
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(_proxify(address(impl)));

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(proxy)));
    proxy.upgradeToAndCall(
      address(impl),
      abi.encodeCall(MockV4AddressesProviderInstance.initialize, (OWNER))
    );

    uint64 secondRevision = uint64(vm.randomUint(0, initialRevision));
    MockV4AddressesProviderInstance impl2 = new MockV4AddressesProviderInstance(secondRevision);
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    vm.prank(_getProxyAdminAddress(address(proxy)));
    proxy.upgradeToAndCall(
      address(impl2),
      abi.encodeCall(MockV4AddressesProviderInstance.initialize, (OWNER))
    );
  }

  function test_proxy_constructor_revertsWith_InvalidAddress() public {
    V4AddressesProviderInstance impl = new V4AddressesProviderInstance();
    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableInvalidOwner.selector, address(0))
    );
    new TransparentUpgradeableProxy(
      address(impl),
      proxyAdminOwner,
      abi.encodeCall(V4AddressesProviderInstance.initialize, (address(0)))
    );
  }

  function test_proxy_reinitialization_revertsWith_CallerNotProxyAdmin() public {
    V4AddressesProviderInstance impl = new V4AddressesProviderInstance();
    ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(_proxify(address(impl)));

    V4AddressesProviderInstance impl2 = new V4AddressesProviderInstance();
    vm.expectRevert();
    vm.prank(makeAddr('user'));
    proxy.upgradeToAndCall(
      address(impl2),
      abi.encodeCall(V4AddressesProviderInstance.initialize, (OWNER))
    );
  }

  function _proxify(address impl) internal returns (address) {
    return
      address(
        new TransparentUpgradeableProxy(
          impl,
          proxyAdminOwner,
          abi.encodeCall(V4AddressesProviderInstance.initialize, (OWNER))
        )
      );
  }
}
