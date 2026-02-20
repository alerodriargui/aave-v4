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

  function test_grantSpokeConfiguratorRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: address(0),
      role: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      admin: address(0)
    });
  }

  function test_setupSpokeConfiguratorRoles_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator
    });

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: address(0)
    });
  }

  function test_setupSpokeConfiguratorRole_reverts() public {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorAdminRoleSelectors();

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: address(0),
      role: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      selectors: selectors
    });
  }

  function test_grantSpokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    (bool hasAdmin, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      admin
    );
    assertTrue(hasAdmin);

    (bool hasFreeze, ) = IAccessManager(accessManager).hasRole(Roles.SPOKE_FREEZE_ROLE, admin);
    assertTrue(hasFreeze);

    (bool hasPause, ) = IAccessManager(accessManager).hasRole(Roles.SPOKE_PAUSE_ROLE, admin);
    assertTrue(hasPause);
  }

  function test_setupSpokeConfiguratorRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.addReserve.selector
      ),
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updateFrozen.selector
      ),
      Roles.SPOKE_FREEZE_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updatePaused.selector
      ),
      Roles.SPOKE_PAUSE_ROLE
    );
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.DEFAULT_ADMIN_ROLE, _wrapper, 0);
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

  function test_canCall_spokeConfiguratorAdminRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorAdminRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        spokeConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_spokeFreezeRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_FREEZE_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeFreezeRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_FREEZE_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        spokeConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_spokePauseRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_PAUSE_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokePauseRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_PAUSE_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        spokeConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_spokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    bytes4[] memory adminSelectors = wrapper.getSpokeConfiguratorAdminRoleSelectors();
    for (uint256 i = 0; i < adminSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        adminSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory freezeSelectors = wrapper.getSpokeFreezeRoleSelectors();
    for (uint256 i = 0; i < freezeSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        freezeSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory pauseSelectors = wrapper.getSpokePauseRoleSelectors();
    for (uint256 i = 0; i < pauseSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        pauseSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }
  }
}
