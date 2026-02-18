// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

contract AaveV4SpokeConfiguratorRolesProcedureTest is ProceduresBase {
  AaveV4SpokeConfiguratorRolesProcedureWrapper public wrapper;
  address public spokeConfigurator = makeAddr('spokeConfigurator');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4SpokeConfiguratorRolesProcedureWrapper();
  }

  function test_grantSpokeConfiguratorAdminRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantSpokeConfiguratorAdminRole({accessManager: address(0), admin: admin});

    vm.expectRevert('invalid admin');
    wrapper.grantSpokeConfiguratorAdminRole({accessManager: accessManager, admin: address(0)});
  }

  function test_grantSpokeFreezeRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantSpokeFreezeRole({accessManager: address(0), admin: admin});

    vm.expectRevert('invalid admin');
    wrapper.grantSpokeFreezeRole({accessManager: accessManager, admin: address(0)});
  }

  function test_grantSpokePauseRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.grantSpokePauseRole({accessManager: address(0), admin: admin});

    vm.expectRevert('invalid admin');
    wrapper.grantSpokePauseRole({accessManager: accessManager, admin: address(0)});
  }

  function test_setupSpokeConfiguratorRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator
    });

    vm.expectRevert('invalid spoke configurator');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: address(0)
    });
  }

  function test_setupSpokeConfiguratorAdminRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupSpokeConfiguratorAdminRole({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator
    });

    vm.expectRevert('invalid spoke configurator');
    wrapper.setupSpokeConfiguratorAdminRole({
      accessManager: accessManager,
      spokeConfigurator: address(0)
    });
  }

  function test_setupSpokeFreezeRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupSpokeFreezeRole({accessManager: address(0), spokeConfigurator: spokeConfigurator});

    vm.expectRevert('invalid spoke configurator');
    wrapper.setupSpokeFreezeRole({accessManager: accessManager, spokeConfigurator: address(0)});
  }

  function test_setupSpokePauseRole_reverts() public {
    vm.expectRevert('invalid access manager');
    wrapper.setupSpokePauseRole({accessManager: address(0), spokeConfigurator: spokeConfigurator});

    vm.expectRevert('invalid spoke configurator');
    wrapper.setupSpokePauseRole({accessManager: accessManager, spokeConfigurator: address(0)});
  }

  function test_getSpokeConfiguratorAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorAdminRoleSelectors();
    assertEq(selectors.length, 18);
    assertEq(selectors[0], ISpokeConfigurator.updateReservePriceSource.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateHealthFactorForMaxBonus.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateLiquidationBonusFactor.selector);
    assertEq(selectors[4], ISpokeConfigurator.updateLiquidationConfig.selector);
    assertEq(selectors[5], ISpokeConfigurator.addReserve.selector);
    assertEq(selectors[6], ISpokeConfigurator.updateBorrowable.selector);
    assertEq(selectors[7], ISpokeConfigurator.updateReceiveSharesEnabled.selector);
    assertEq(selectors[8], ISpokeConfigurator.updateCollateralRisk.selector);
    assertEq(selectors[9], ISpokeConfigurator.addCollateralFactor.selector);
    assertEq(selectors[10], ISpokeConfigurator.updateCollateralFactor.selector);
    assertEq(selectors[11], ISpokeConfigurator.addMaxLiquidationBonus.selector);
    assertEq(selectors[12], ISpokeConfigurator.updateMaxLiquidationBonus.selector);
    assertEq(selectors[13], ISpokeConfigurator.addLiquidationFee.selector);
    assertEq(selectors[14], ISpokeConfigurator.updateLiquidationFee.selector);
    assertEq(selectors[15], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(selectors[16], ISpokeConfigurator.updateDynamicReserveConfig.selector);
    assertEq(selectors[17], ISpokeConfigurator.updatePositionManager.selector);
  }

  function test_getSpokeFreezeRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeFreezeRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], ISpokeConfigurator.updateFrozen.selector);
    assertEq(selectors[1], ISpokeConfigurator.freezeAllReserves.selector);
    assertEq(selectors[2], ISpokeConfigurator.freezeReserve.selector);
  }

  function test_getSpokePauseRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokePauseRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], ISpokeConfigurator.updatePaused.selector);
    assertEq(selectors[1], ISpokeConfigurator.pauseAllReserves.selector);
    assertEq(selectors[2], ISpokeConfigurator.pauseReserve.selector);
  }
}
