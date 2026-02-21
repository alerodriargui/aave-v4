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

    (bool hasLiquidationUpdater, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      admin
    );
    assertTrue(hasLiquidationUpdater);

    (bool hasReserveAdder, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
      admin
    );
    assertTrue(hasReserveAdder);

    (bool hasFreezer, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
      admin
    );
    assertTrue(hasFreezer);

    (bool hasPauser, ) = IAccessManager(accessManager).hasRole(
      Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
      admin
    );
    assertTrue(hasPauser);
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
        ISpokeConfigurator.updateBorrowable.selector
      ),
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updateLiquidationConfig.selector
      ),
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.addReserve.selector
      ),
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updateFrozen.selector
      ),
      Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updatePaused.selector
      ),
      Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE
    );
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_DEFAULT_ADMIN, _wrapper, 0);
  }

  function test_getSpokeConfiguratorAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorAdminRoleSelectors();
    assertEq(selectors.length, 9);
    assertEq(selectors[0], ISpokeConfigurator.updateReservePriceSource.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateBorrowable.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateReceiveSharesEnabled.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateCollateralRisk.selector);
    assertEq(selectors[4], ISpokeConfigurator.addCollateralFactor.selector);
    assertEq(selectors[5], ISpokeConfigurator.updateCollateralFactor.selector);
    assertEq(selectors[6], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(selectors[7], ISpokeConfigurator.updateDynamicReserveConfig.selector);
    assertEq(selectors[8], ISpokeConfigurator.updatePositionManager.selector);
  }

  function test_getSpokeConfiguratorLiquidationUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    assertEq(selectors.length, 8);
    assertEq(selectors[0], ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateHealthFactorForMaxBonus.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateLiquidationBonusFactor.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateLiquidationConfig.selector);
    assertEq(selectors[4], ISpokeConfigurator.addMaxLiquidationBonus.selector);
    assertEq(selectors[5], ISpokeConfigurator.updateMaxLiquidationBonus.selector);
    assertEq(selectors[6], ISpokeConfigurator.addLiquidationFee.selector);
    assertEq(selectors[7], ISpokeConfigurator.updateLiquidationFee.selector);
  }

  function test_getSpokeConfiguratorReserveAdderRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorReserveAdderRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], ISpokeConfigurator.addReserve.selector);
  }

  function test_getSpokeConfiguratorFreezerRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorFreezerRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], ISpokeConfigurator.updateFrozen.selector);
    assertEq(selectors[1], ISpokeConfigurator.freezeAllReserves.selector);
    assertEq(selectors[2], ISpokeConfigurator.freezeReserve.selector);
  }

  function test_getSpokeConfiguratorPauserRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPauserRoleSelectors();
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

  function test_canCall_spokeLiquidationUpdaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
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

  function test_canCall_spokeReserveAdderRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorReserveAdderRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
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

  function test_canCall_spokeFreezerRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorFreezerRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
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

  function test_canCall_spokePauserRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPauserRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
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

    bytes4[] memory liquidationUpdaterSelectors = wrapper
      .getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    for (uint256 i = 0; i < liquidationUpdaterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        liquidationUpdaterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory reserveAdderSelectors = wrapper.getSpokeConfiguratorReserveAdderRoleSelectors();
    for (uint256 i = 0; i < reserveAdderSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        reserveAdderSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory freezerSelectors = wrapper.getSpokeConfiguratorFreezerRoleSelectors();
    for (uint256 i = 0; i < freezerSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        freezerSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory pauserSelectors = wrapper.getSpokeConfiguratorPauserRoleSelectors();
    for (uint256 i = 0; i < pauserSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        spokeConfigurator,
        pauserSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }
  }
}
