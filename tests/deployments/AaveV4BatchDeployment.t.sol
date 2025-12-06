// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';

contract AaveV4BatchDeploymentTest is BatchTestProcedures {
  address public deployer;
  IProgressLogger public logger;
  FullDeployInputs public inputs;
  address public weth9;

  string[] public hubLabels;
  string[] public spokeLabels;

  function setUp() public override {
    super.setUp();

    deployer = makeAddr('deployer');
    logger = new MockLogger();
    weth9 = _deployWETH();

    hubLabels = ['hub1', 'hub2', 'hub3'];
    spokeLabels = ['spoke1', 'spoke2', 'spoke3'];

    inputs = FullDeployInputs({
      admin: makeAddr('admin'),
      nativeWrapperAddress: weth9,
      setRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels
    });
  }

  function testAaveV4BatchDeployment_withRoles() public {
    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(
      deployer,
      logger,
      inputs
    );
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withoutRoles() public {
    inputs.setRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(
      deployer,
      logger,
      inputs
    );
    _checkDeployment(report, inputs);
  }
}
