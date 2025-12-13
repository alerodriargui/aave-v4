// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';

contract AaveV4BatchDeploymentTest is BatchTestProcedures {
  Logger public logger;
  FullDeployInputs public inputs;
  address public weth9;

  string[] public hubLabels;
  string[] public spokeLabels;

  function setUp() public override {
    super.setUp();

    deployer = makeAddr('deployer');
    logger = new Logger('dummy/path');
    weth9 = _deployWETH();

    hubLabels = ['hub1', 'hub2', 'hub3'];
    spokeLabels = ['spoke1', 'spoke2', 'spoke3'];

    inputs = FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      hubConfiguratorOwner: makeAddr('hubConfiguratorOwner'),
      hubAdmin: makeAddr('hubAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      spokeProxyAdminOwner: makeAddr('spokeProxyAdminOwner'),
      spokeConfiguratorOwner: makeAddr('spokeConfiguratorOwner'),
      spokeAdmin: makeAddr('spokeAdmin'),
      nativeWrapperAddress: weth9,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels
    });
  }

  function testAaveV4BatchDeployment() public {
    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withoutRoles() public {
    inputs.grantRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
  }

  function testAaveV4BatchDeployment_withoutNativeGateway() public {
    inputs.nativeWrapperAddress = address(0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withoutHubs() public {
    inputs.hubLabels = new string[](0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withoutSpokes() public {
    inputs.spokeLabels = new string[](0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdminAddress() public {
    inputs.accessManagerAdmin = address(0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdminAddress_withoutRoles() public {
    inputs.accessManagerAdmin = address(0);
    inputs.grantRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZerohubConfiguratorOwnerAddress() public {
    inputs.hubConfiguratorOwner = address(0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZerohubConfiguratorOwnerAddress_withoutRoles() public {
    inputs.hubConfiguratorOwner = address(0);
    inputs.grantRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZeroTreasurySpokeOwnerAddress() public {
    inputs.treasurySpokeOwner = address(0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZeroTreasurySpokeOwnerAddress_withoutRoles() public {
    inputs.treasurySpokeOwner = address(0);
    inputs.grantRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZeroSpokeProxyAdminOwnerAddress() public {
    inputs.spokeProxyAdminOwner = address(0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZeroSpokeProxyAdminOwnerAddress_withoutRoles() public {
    inputs.spokeProxyAdminOwner = address(0);
    inputs.grantRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZerospokeConfiguratorOwnerAddress() public {
    inputs.spokeConfiguratorOwner = address(0);

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }

  function testAaveV4BatchDeployment_withZerospokeConfiguratorOwnerAddress_withoutRoles() public {
    inputs.spokeConfiguratorOwner = address(0);
    inputs.grantRoles = false;

    OrchestrationReports.FullDeploymentReport memory report = deployAaveV4Testnet(logger, inputs);
    _checkDeployment(report, inputs);
    _checkRoles(report, inputs);
  }
}
