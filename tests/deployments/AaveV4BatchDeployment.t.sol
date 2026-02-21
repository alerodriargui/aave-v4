// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/utils/BatchTestProcedures.sol';

contract AaveV4BatchDeploymentTest is BatchTestProcedures {
  function setUp() public override {
    super.setUp();

    _inputs = FullDeployInputs({
      accessManagerAdmin: makeAddr('accessManagerAdmin'),
      hubConfiguratorAdmin: makeAddr('hubConfiguratorAdmin'),
      hubAdmin: makeAddr('hubAdmin'),
      treasurySpokeOwner: makeAddr('treasurySpokeOwner'),
      spokeProxyAdminOwner: makeAddr('spokeProxyAdminOwner'),
      spokeConfiguratorAdmin: makeAddr('spokeConfiguratorAdmin'),
      spokeAdmin: makeAddr('spokeAdmin'),
      gatewayOwner: makeAddr('gatewayOwner'),
      nativeWrapper: _weth9,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      grantRoles: true,
      hubLabels: _hubLabels,
      spokeLabels: _spokeLabels,
      spokeMaxReservesLimits: _defaultSpokeMaxReservesLimits(_spokeLabels.length),
      spokeOracleDecimals: _defaultSpokeOracleDecimals(_spokeLabels.length),
      spokeOracleDescriptions: _defaultSpokeOracleDescriptions(_spokeLabels),
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

  function testAaveV4BatchDeployment_withoutGateways() public {
    _inputs.deployNativeTokenGateway = false;
    _inputs.deploySignatureGateway = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutNativeTokenGateway() public {
    _inputs.deployNativeTokenGateway = false;
    _inputs.deploySignatureGateway = true;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutSignatureGateway() public {
    _inputs.deployNativeTokenGateway = true;
    _inputs.deploySignatureGateway = false;
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutHubs() public {
    _inputs.hubLabels = new string[](0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withoutSpokes() public {
    _inputs.spokeLabels = new string[](0);
    _inputs.spokeMaxReservesLimits = new uint16[](0);
    _inputs.spokeOracleDecimals = new uint8[](0);
    _inputs.spokeOracleDescriptions = new string[](0);
    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withRoles_reverts() public {
    // only reverts if grantRoles is true, as access manager admin replaces deployer as default admin
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('zero address');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroAccessManagerAdmin_withoutRoles() public {
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  /// @dev Only reverts when grantRoles is true, as hubConfiguratorAdmin is
  /// now used to grant configurator roles, not as authority
  function testAaveV4BatchDeployment_fuzz_withZeroHubConfiguratorAdmin(bool grantRoles) public {
    _inputs.hubConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;

    if (grantRoles && _inputs.hubLabels.length > 0) {
      vm.expectRevert('zero address');
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
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
      _inputs.spokeMaxReservesLimits = new uint16[](0);
      _inputs.spokeOracleDecimals = new uint8[](0);
      _inputs.spokeOracleDescriptions = new string[](0);
    }

    (bool isExpectedError, bytes memory errorMessage) = _getExpectedError();
    if (isExpectedError) {
      vm.expectRevert(errorMessage);
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  /// @dev Only reverts when grantRoles is true, as spokeConfiguratorAdmin is
  /// now used to grant configurator roles, not as authority
  function testAaveV4BatchDeployment_fuzz_withZeroSpokeConfiguratorAdmin(bool grantRoles) public {
    _inputs.spokeConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;

    if (grantRoles && _inputs.spokeLabels.length > 0) {
      vm.expectRevert('zero address');
      this.checkedV4Deployment();
    } else {
      checkedV4Deployment();
    }
  }

  function testAaveV4BatchDeployment_withZeroHubAdmin_withRoles_reverts() public {
    _inputs.hubAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('zero address');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroHubAdmin_withoutRoles() public {
    _inputs.hubAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroSpokeAdmin_withRoles_reverts() public {
    _inputs.spokeAdmin = address(0);
    _inputs.grantRoles = true;

    vm.expectRevert('zero address');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroSpokeAdmin_withoutRoles() public {
    _inputs.spokeAdmin = address(0);
    _inputs.grantRoles = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroGatewayOwner_withGateways_reverts() public {
    _inputs.gatewayOwner = address(0);
    _inputs.deployNativeTokenGateway = true;
    _inputs.deploySignatureGateway = true;

    vm.expectRevert('invalid owner');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroGatewayOwner_withoutGateways() public {
    _inputs.gatewayOwner = address(0);
    _inputs.deployNativeTokenGateway = false;
    _inputs.deploySignatureGateway = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroNativeWrapper_withNativeGateway_reverts() public {
    _inputs.nativeWrapper = address(0);
    _inputs.deployNativeTokenGateway = true;

    vm.expectRevert('invalid native wrapper');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroNativeWrapper_withoutNativeGateway() public {
    _inputs.nativeWrapper = address(0);
    _inputs.deployNativeTokenGateway = false;

    checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_withZeroDeployer_reverts() public {
    _deployer = address(0);

    vm.expectRevert('invalid admin');
    this.checkedV4Deployment();
  }

  function testAaveV4BatchDeployment_fuzz_withoutRoles(
    FullDeployInputs memory deployInputs,
    address deployer,
    bool withoutHubs,
    bool withoutSpokes,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway
  ) public {
    deployInputs.grantRoles = false;
    deployInputs.deployNativeTokenGateway = deployNativeTokenGateway;
    deployInputs.deploySignatureGateway = deploySignatureGateway;
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = _inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
      deployInputs.spokeMaxReservesLimits = new uint16[](0);
      deployInputs.spokeOracleDecimals = new uint8[](0);
      deployInputs.spokeOracleDescriptions = new string[](0);
    } else {
      deployInputs.spokeLabels = _inputs.spokeLabels;
      deployInputs.spokeMaxReservesLimits = _inputs.spokeMaxReservesLimits;
      deployInputs.spokeOracleDecimals = _inputs.spokeOracleDecimals;
      deployInputs.spokeOracleDescriptions = _inputs.spokeOracleDescriptions;
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
    bool deployNativeTokenGateway,
    bool deploySignatureGateway
  ) public {
    deployInputs.grantRoles = true;
    deployInputs.deployNativeTokenGateway = deployNativeTokenGateway;
    deployInputs.deploySignatureGateway = deploySignatureGateway;
    if (withoutHubs) {
      deployInputs.hubLabels = new string[](0);
    } else {
      deployInputs.hubLabels = _inputs.hubLabels;
    }
    if (withoutSpokes) {
      deployInputs.spokeLabels = new string[](0);
      deployInputs.spokeMaxReservesLimits = new uint16[](0);
      deployInputs.spokeOracleDecimals = new uint8[](0);
      deployInputs.spokeOracleDescriptions = new string[](0);
    } else {
      deployInputs.spokeLabels = _inputs.spokeLabels;
      deployInputs.spokeMaxReservesLimits = _inputs.spokeMaxReservesLimits;
      deployInputs.spokeOracleDecimals = _inputs.spokeOracleDecimals;
      deployInputs.spokeOracleDescriptions = _inputs.spokeOracleDescriptions;
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
    assertNotEq(deployInputs.hubConfiguratorAdmin, address(0));
    assertNotEq(deployInputs.treasurySpokeOwner, address(0));
    assertNotEq(deployInputs.spokeProxyAdminOwner, address(0));
    assertNotEq(deployInputs.spokeConfiguratorAdmin, address(0));
    assertNotEq(deployInputs.gatewayOwner, address(0));
    assertNotEq(deployInputs.hubAdmin, address(0));
    assertNotEq(deployInputs.spokeAdmin, address(0));

    _inputs = deployInputs;
    checkedV4Deployment();
  }

  /// @dev Predicts the first revert error based on execution order in deployAaveV4():
  ///      1. AuthorityBatch (deployer as initial admin)
  ///      2. Hubs (treasurySpokeOwner)
  ///      3. Spokes (spokeProxyAdminOwner)
  ///      4. Gateways (gatewayOwner, nativeWrapper)
  ///      5. Roles (hubAdmin, hubConfiguratorAdmin, spokeAdmin, spokeConfiguratorAdmin, accessManagerAdmin)
  function _getExpectedError()
    internal
    view
    returns (bool isExpectedError, bytes memory errorMessage)
  {
    // 1. deployer is initial admin for access manager
    if (_deployer == address(0)) return (true, bytes('invalid admin'));

    // 2. hubs require treasury owner when deployed
    if (_inputs.hubLabels.length > 0 && _inputs.treasurySpokeOwner == address(0)) {
      return (true, bytes('invalid owner'));
    }

    // 3. spokes require proxy admin owner when deployed
    if (_inputs.spokeLabels.length > 0 && _inputs.spokeProxyAdminOwner == address(0)) {
      return (true, bytes('invalid spoke proxy admin owner'));
    }

    // 4. gateways: native gateway checks nativeWrapper first, then owner;
    //    signature gateway checks owner
    if (_inputs.deployNativeTokenGateway && _inputs.nativeWrapper == address(0)) {
      return (true, bytes('invalid native wrapper'));
    }
    if (
      (_inputs.deployNativeTokenGateway || _inputs.deploySignatureGateway) &&
      _inputs.gatewayOwner == address(0)
    ) {
      return (true, bytes('invalid owner'));
    }

    if (_inputs.grantRoles) {
      bool hasHubs = _inputs.hubLabels.length > 0;
      bool hasSpokes = _inputs.spokeLabels.length > 0;

      if (
        (hasHubs &&
          (_inputs.hubAdmin == address(0) || _inputs.hubConfiguratorAdmin == address(0))) ||
        (hasSpokes &&
          (_inputs.spokeAdmin == address(0) || _inputs.spokeConfiguratorAdmin == address(0))) ||
        _inputs.accessManagerAdmin == address(0)
      ) {
        return (true, bytes('zero address'));
      }
    }
  }
}
