// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4NativeTokenGatewayDeployProcedureTest is ProceduresBase {
  AaveV4NativeTokenGatewayDeployProcedureWrapper
    public aaveV4NativeTokenGatewayDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4NativeTokenGatewayDeployProcedureWrapper = new AaveV4NativeTokenGatewayDeployProcedureWrapper();
  }

  function test_deployHubConfigurator() public {
    address nativeTokenGateway = aaveV4NativeTokenGatewayDeployProcedureWrapper
      .deployNativeTokenGateway(nativeWrapper, owner);
    assertNotEq(nativeTokenGateway, address(0));
    assertEq(Ownable(nativeTokenGateway).owner(), owner);
  }

  function test_deployNativeTokenGateway_revertsWithInvalidParam() public {
    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'native wrapper')
    );
    aaveV4NativeTokenGatewayDeployProcedureWrapper.deployNativeTokenGateway(address(0), owner);

    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'owner')
    );
    aaveV4NativeTokenGatewayDeployProcedureWrapper.deployNativeTokenGateway(
      nativeWrapper,
      address(0)
    );
  }
}
