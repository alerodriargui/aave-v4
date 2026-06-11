// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4AddressesProviderDeployProcedureTest is ProceduresBase {
  AaveV4AddressesProviderDeployProcedureWrapper
    public aaveV4AddressesProviderDeployProcedureWrapper;

  function setUp() public override {
    super.setUp();
    aaveV4AddressesProviderDeployProcedureWrapper = new AaveV4AddressesProviderDeployProcedureWrapper();
  }

  function test_deployAddressesProvider() public {
    (
      address addressesProviderProxy,
      address addressesProviderImplementation
    ) = aaveV4AddressesProviderDeployProcedureWrapper.deployAddressesProvider(owner, salt);
    assertEq(Ownable(addressesProviderProxy).owner(), owner);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(addressesProviderProxy)).owner(), owner);
    assertNotEq(addressesProviderImplementation, address(0));
    assertEq(
      ProxyHelper.getImplementation(addressesProviderProxy),
      addressesProviderImplementation
    );
  }

  function test_deployAddressesProvider_reverts() public {
    vm.expectRevert('invalid owner');
    aaveV4AddressesProviderDeployProcedureWrapper.deployAddressesProvider({
      owner: address(0),
      salt: salt
    });
  }
}
