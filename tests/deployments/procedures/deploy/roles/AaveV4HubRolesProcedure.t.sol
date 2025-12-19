// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubRolesProcedureTest is ProceduresBase {
  AaveV4HubRolesProcedureWrapper public aaveV4HubRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4HubRolesProcedureWrapper = new AaveV4HubRolesProcedureWrapper();
  }

  function test_grantHubAdminRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4HubRolesProcedureWrapper.grantHubAdminRole({accessManager: address(0), admin: admin});

    vm.expectRevert('invalid admin');
    aaveV4HubRolesProcedureWrapper.grantHubAdminRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantHubFeeMinterRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4HubRolesProcedureWrapper.grantHubFeeMinterRole({accessManager: address(0), admin: admin});

    vm.expectRevert('invalid admin');
    aaveV4HubRolesProcedureWrapper.grantHubFeeMinterRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantHubConfiguratorRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4HubRolesProcedureWrapper.grantHubConfiguratorRole({
      accessManager: address(0),
      admin: admin
    });

    vm.expectRevert('invalid admin');
    aaveV4HubRolesProcedureWrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_setupHubRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4HubRolesProcedureWrapper.setupHubRoles({accessManager: address(0), hub: hub});

    vm.expectRevert('invalid hub');
    aaveV4HubRolesProcedureWrapper.setupHubRoles({accessManager: accessManager, hub: address(0)});
  }

  function test_setupHubFeeMinterRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4HubRolesProcedureWrapper.setupHubFeeMinterRole({accessManager: address(0), hub: hub});

    vm.expectRevert('invalid hub');
    aaveV4HubRolesProcedureWrapper.setupHubFeeMinterRole({
      accessManager: accessManager,
      hub: address(0)
    });
  }

  function test_setupHubConfiguratorRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4HubRolesProcedureWrapper.setupHubConfiguratorRole({accessManager: address(0), hub: hub});

    vm.expectRevert('invalid hub');
    aaveV4HubRolesProcedureWrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hub: address(0)
    });
  }

  function test_getHubFeeMinterRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4HubRolesProcedureWrapper.getHubFeeMinterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHub.mintFeeShares.selector);
  }

  function test_getHubConfiguratorRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4HubRolesProcedureWrapper.getHubConfiguratorRoleSelectors();
    assertEq(selectors.length, 5);
    assertEq(selectors[0], IHub.addAsset.selector);
    assertEq(selectors[1], IHub.updateAssetConfig.selector);
    assertEq(selectors[2], IHub.addSpoke.selector);
    assertEq(selectors[3], IHub.updateSpokeConfig.selector);
    assertEq(selectors[4], IHub.setInterestRateData.selector);
  }
}
