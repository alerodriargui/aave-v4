// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';

contract AaveV4BatchDeploymentTest is BatchTestProcedures {
  function setUp() public override {
    super.setUp();

    _inputs = FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      hubConfiguratorOwner: makeAddr('hubConfiguratorOwner'),
      hubAdmin: makeAddr('hubAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      spokeProxyAdminOwner: makeAddr('spokeProxyAdminOwner'),
      spokeConfiguratorOwner: makeAddr('spokeConfiguratorOwner'),
      spokeAdmin: makeAddr('spokeAdmin'),
      gatewayOwner: makeAddr('gatewayOwner'),
      nativeWrapper: _weth9,
      grantRoles: true,
      hubLabels: _hubLabels,
      spokeLabels: _spokeLabels,
      salt: bytes32(0)
    });
  }

  function testAaveV4BatchDeployment() public {
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutRoles() public {
    _inputs.grantRoles = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutNativeGateway() public {
    _inputs.nativeWrapper = address(0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutHubs() public {
    _inputs.hubLabels = new string[](0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutSpokes() public {
    _inputs.spokeLabels = new string[](0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withRoles_reverts() public {
    // only reverts if grantRoles is true, as access manager admin replaces deployer as default admin
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('invalid admin to add');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withoutRoles() public {
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  /// @dev Reverts as hubConfigurator is always deployed
  /// and owners are needed on initial deployment
  function testAaveV4BatchDeployment_withZeroHubConfiguratorOwner_reverts() public {
    _inputs.hubConfiguratorOwner = address(0);
    _inputs.grantRoles = vm.randomBool();

    vm.expectRevert('invalid owner');
    this.checkedV4Deployment();
  }

  /// @dev Reverts as treasurySpoke is always deployed if hubs are being deployed
  /// and owner is needed on initial deployment
  function testAaveV4BatchDeployment_fuzz_withZeroTreasurySpokeOwner(
    bool withoutHubs,
    bool grantRoles
  ) public {
    _inputs.treasurySpokeOwner = address(0);
    _inputs.grantRoles = grantRoles;

    if (withoutHubs) {
      _inputs.hubLabels = new string[](0);
    }

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  function testAaveV4BatchDeployment_fuzz_withZeroSpokeProxyAdminOwner(
    bool withoutSpokes,
    bool grantRoles
  ) public {
    _inputs.spokeProxyAdminOwner = address(0);
    _inputs.grantRoles = grantRoles;
    if (withoutSpokes) {
      _inputs.spokeLabels = new string[](0);
    }

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  function testAaveV4BatchDeployment_withZeroSpokeConfiguratorOwner_reverts() public {
    _inputs.spokeConfiguratorOwner = address(0);
    _inputs.grantRoles = vm.randomBool();

    vm.expectRevert('invalid owner');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroSpokeConfiguratorOwner_withoutRoles_reverts() public {
    _inputs.spokeConfiguratorOwner = address(0);
    _inputs.grantRoles = false;

    vm.expectRevert('invalid owner');
    this.checkedV4Deployment();
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
      deployInputs.nativeWrapper = _inputs.nativeWrapper;
    }
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = _inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
    } else {
      deployInputs.spokeLabels = _inputs.spokeLabels;
    }
    _deployer = deployer;
    _inputs = deployInputs;

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
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
      deployInputs.nativeWrapper = _inputs.nativeWrapper;
    }
    deployInputs.nativeWrapper = _inputs.nativeWrapper;
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = _inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
    } else {
      deployInputs.spokeLabels = _inputs.spokeLabels;
    }
    _deployer = deployer;
    _inputs = deployInputs;

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
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

    checkedV4Deployment();
  }

  function _getExpectedError()
    internal
    view
    returns (bool isExpectedError, bytes memory errorMessage)
  {
    // deployer is initial admin for access manager
    if (_deployer == address(0)) return (true, bytes('invalid deployer'));

    // configurators always deployed
    if (_inputs.spokeConfiguratorOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }
    if (_inputs.hubConfiguratorOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    // gateways only when native wrapper is set
    if (_inputs.nativeWrapper != address(0) && _inputs.gatewayOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    // hubs require treasury owner when deployed
    if (_inputs.hubLabels.length > 0 && _inputs.treasurySpokeOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    // spokes require proxy admin owner when deployed
    if (_inputs.spokeLabels.length > 0 && _inputs.spokeProxyAdminOwner == address(0)) {
      return (true, bytes('invalid spoke proxy admin owner'));
    }

    if (_inputs.grantRoles) {
      if (_inputs.accessManagerAdmin == address(0)) {
        return (true, bytes('invalid admin'));
      }
      if (_inputs.hubLabels.length > 0 && _inputs.hubAdmin == address(0)) {
        return (true, bytes('invalid admin'));
      }
      if (_inputs.spokeLabels.length > 0 && _inputs.spokeAdmin == address(0)) {
        return (true, bytes('invalid admin'));
      }
    }
  }
}
