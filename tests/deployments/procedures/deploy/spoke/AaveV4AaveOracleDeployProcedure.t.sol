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
      oracleDecimals,
      oracleDescription
    );
    assertNotEq(aaveOracle, address(0));
    assertEq(IAaveOracle(aaveOracle).DECIMALS(), oracleDecimals);
    assertEq(IAaveOracle(aaveOracle).DESCRIPTION(), oracleDescription);
  }

  function test_deployAaveOracle_reverts_inputValidation() public {
    vm.expectRevert('invalid oracle decimals');
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      decimals: 0,
      description: oracleDescription
    });

    vm.expectRevert('invalid oracle description');
    aaveV4AaveOracleDeployProcedureWrapper.deployAaveOracle({
      decimals: oracleDecimals,
      description: ''
    });
  }
}
