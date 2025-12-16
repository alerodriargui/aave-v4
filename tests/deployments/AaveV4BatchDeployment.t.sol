// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';
import {stdError} from 'forge-std/StdError.sol';

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
      gatewayOwner: makeAddr('gatewayOwner'),
      nativeWrapper: weth9,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels
    });
  }

  function testAaveV4BatchDeployment() public {
    checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withoutRoles() public {
    inputs.grantRoles = false;
    checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withoutNativeGateway() public {
    inputs.nativeWrapper = address(0);
    checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withoutHubs() public {
    inputs.hubLabels = new string[](0);
    checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withoutSpokes() public {
    inputs.spokeLabels = new string[](0);
    checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withRoles_revertsWithAssertionError()
    public
  {
    // only reverts if grantRoles is true, as access manager admin replaces deployer as default admin
    inputs.accessManagerAdmin = address(0);
    inputs.grantRoles = true;

    // reverts in AaveV4AccessBatch
    vm.expectRevert(stdError.assertionError);
    this.checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withoutRoles() public {
    inputs.accessManagerAdmin = address(0);
    inputs.grantRoles = false;

    checkedV4Deployment(logger, inputs);
  }

  /// @dev Reverts as hubConfigurator is always deployed
  /// and owners are needed on initial deployment
  function testAaveV4BatchDeployment_withZeroHubConfiguratorOwner() public {
    inputs.hubConfiguratorOwner = address(0);
    inputs.grantRoles = vm.randomBool();

    // reverts in AaveV4ConfiguratorBatch
    vm.expectRevert(stdError.assertionError);
    this.checkedV4Deployment(logger, inputs);
  }

  /// @dev Reverts as treasurySpoke is always deployed if hubs are being deployed
  /// and owner is needed on initial deployment
  function testAaveV4BatchDeployment_fuzz_withZeroTreasurySpokeOwner(
    bool withoutHubs,
    bool grantRoles
  ) public {
    inputs.treasurySpokeOwner = address(0);
    inputs.grantRoles = grantRoles;

    if (withoutHubs) {
      inputs.hubLabels = new string[](0);
    }

    if (_isExpectAssertionError(inputs, deployer)) {
      // reverts in AaveV4HubBatch
      vm.expectRevert(stdError.assertionError);
      this.checkedV4Deployment(logger, inputs);
    } else {
      checkedV4Deployment(logger, inputs);
    }
  }

  function testAaveV4BatchDeployment_fuzz_withZeroSpokeProxyAdminOwner(
    bool withoutSpokes,
    bool grantRoles
  ) public {
    inputs.spokeProxyAdminOwner = address(0);
    inputs.grantRoles = grantRoles;
    if (withoutSpokes) {
      inputs.spokeLabels = new string[](0);
    }

    if (_isExpectAssertionError(inputs, deployer)) {
      // reverts in AaveV4SpokeInstanceBatch
      vm.expectRevert(stdError.assertionError);
      this.checkedV4Deployment(logger, inputs);
    } else {
      checkedV4Deployment(logger, inputs);
    }
  }

  function testAaveV4BatchDeployment_withZeroSpokeConfiguratorOwner() public {
    inputs.spokeConfiguratorOwner = address(0);
    inputs.grantRoles = vm.randomBool();

    // reverts in AaveV4ConfiguratorBatch
    vm.expectRevert(stdError.assertionError);
    this.checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_withZeroSpokeConfiguratorOwner_withoutRoles_revertsWithAssertionError()
    public
  {
    inputs.spokeConfiguratorOwner = address(0);
    inputs.grantRoles = false;

    // reverts in AaveV4ConfiguratorBatch
    vm.expectRevert(stdError.assertionError);
    this.checkedV4Deployment(logger, inputs);
  }

  function testAaveV4BatchDeployment_fuzz_withoutRoles(
    FullDeployInputs memory deployInputs,
    address deployer,
    bool withoutHubs,
    bool withoutSpokes,
    bool withoutNativeWrapper
  ) public {
    deployInputs.grantRoles = false;
    if (withoutNativeWrapper) {
      deployInputs.nativeWrapper = address(0);
    } else {
      deployInputs.nativeWrapper = inputs.nativeWrapper;
    }
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
    } else {
      deployInputs.spokeLabels = inputs.spokeLabels;
    }

    if (_isExpectAssertionError(deployInputs, deployer)) {
      vm.expectRevert(stdError.assertionError);
      this.checkedV4Deployment(logger, deployInputs);
    } else {
      checkedV4Deployment(logger, deployInputs);
    }
  }

  function testAaveV4BatchDeployment_fuzz_withRoles(
    FullDeployInputs memory deployInputs,
    address deployer,
    bool withoutHubs,
    bool withoutSpokes,
    bool withoutNativeWrapper
  ) public {
    deployInputs.grantRoles = true;
    if (withoutNativeWrapper) {
      deployInputs.nativeWrapper = address(0);
    } else {
      deployInputs.nativeWrapper = inputs.nativeWrapper;
    }
    deployInputs.nativeWrapper = inputs.nativeWrapper;
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
    } else {
      deployInputs.spokeLabels = inputs.spokeLabels;
    }

    if (_isExpectAssertionError(deployInputs, deployer)) {
      vm.expectRevert(stdError.assertionError);
      this.checkedV4Deployment(logger, deployInputs);
    } else {
      checkedV4Deployment(logger, deployInputs);
    }
  }

  /// @dev Sanitized inputs should never fail when deploying
  function testAaveV4BatchDeployment_fuzz_sanitizedInputs(
    FullDeployInputs memory deployInputs
  ) public {
    deployInputs = _sanitizeInputs(deployInputs);

    assertNotEq(deployInputs.accessManagerAdmin, address(0));
    assertNotEq(deployInputs.hubConfiguratorOwner, address(0));
    assertNotEq(deployInputs.treasurySpokeOwner, address(0));
    assertNotEq(deployInputs.spokeProxyAdminOwner, address(0));
    assertNotEq(deployInputs.spokeConfiguratorOwner, address(0));
    assertNotEq(deployInputs.gatewayOwner, address(0));
    assertNotEq(deployInputs.accessManagerAdmin, address(0));
    assertNotEq(deployInputs.hubAdmin, address(0));
    assertNotEq(deployInputs.spokeAdmin, address(0));

    checkedV4Deployment(logger, deployInputs);
  }

  function _isExpectAssertionError(
    FullDeployInputs memory deployInputs,
    address deployer
  ) internal pure returns (bool isExpectedError) {
    // deployer is initial admin for access manager
    if (deployer == address(0)) return true;

    // configurators always deployed
    if (deployInputs.spokeConfiguratorOwner == address(0)) return true;
    if (deployInputs.hubConfiguratorOwner == address(0)) return true;

    // gateways only when native wrapper is set
    if (deployInputs.nativeWrapper != address(0) && deployInputs.gatewayOwner == address(0)) {
      return true;
    }

    // hubs require treasury owner when deployed
    if (deployInputs.hubLabels.length > 0 && deployInputs.treasurySpokeOwner == address(0)) {
      return true;
    }

    // spokes require proxy admin owner when deployed
    if (deployInputs.spokeLabels.length > 0 && deployInputs.spokeProxyAdminOwner == address(0)) {
      return true;
    }

    if (deployInputs.grantRoles) {
      if (deployInputs.accessManagerAdmin == address(0)) return true;
      if (deployInputs.hubLabels.length > 0 && deployInputs.hubAdmin == address(0)) return true;
      if (deployInputs.spokeLabels.length > 0 && deployInputs.spokeAdmin == address(0)) return true;
    }
  }
}
