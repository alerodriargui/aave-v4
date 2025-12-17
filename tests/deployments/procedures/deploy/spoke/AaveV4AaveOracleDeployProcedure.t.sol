// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4AaveOracleDeployProcedureTest is ProceduresBase {
  AaveV4AaveOracleDeployProcedureWrapper public aaveV4AaveOracleDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4AaveOracleDeployProcedureWrapper = new AaveV4AaveOracleDeployProcedureWrapper();
  }

  function test_deployAaveOracle() public {
    address aaveOracle = aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle(
      spoke,
      oracleDecimals,
      oracleDescription
    );
    assertNotEq(aaveOracle, address(0));
    assertEq(IAaveOracle(aaveOracle).DECIMALS(), oracleDecimals);
    assertEq(IAaveOracle(aaveOracle).DESCRIPTION(), oracleDescription);
  }

  function test_deployAaveOracle_revertsWithInvalidParam() public {
    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'spoke')
    );
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      spoke: address(0),
      decimals: oracleDecimals,
      description: oracleDescription
    });

    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'oracle decimals')
    );
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      spoke: spoke,
      decimals: 0,
      description: oracleDescription
    });

    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'oracle description')
    );
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      spoke: spoke,
      decimals: oracleDecimals,
      description: ''
    });
  }
}
