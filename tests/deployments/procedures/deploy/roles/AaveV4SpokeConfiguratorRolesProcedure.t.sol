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
      role: Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
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
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPriceAdminRoleSelectors();

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      selectors: selectors
    });

    vm.expectRevert('zero address');
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: address(0),
      role: Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      selectors: selectors
    });
  }

  function test_grantSpokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    uint64[9] memory roles = [
      Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE,
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
      Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
      Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE
    ];

    for (uint256 idx; idx < roles.length; idx++) {
      (bool hasRole, ) = IAccessManager(accessManager).hasRole(roles[idx], admin);
      assertTrue(hasRole);
    }
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
        ISpokeConfigurator.updateReservePriceSource.selector
      ),
      Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updateBorrowable.selector
      ),
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.addCollateralFactor.selector
      ),
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        spokeConfigurator,
        ISpokeConfigurator.updatePositionManager.selector
      ),
      Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE
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
        ISpokeConfigurator.addMaxLiquidationBonus.selector
      ),
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE
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

  function test_getSpokeConfiguratorPriceAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPriceAdminRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], ISpokeConfigurator.updateReservePriceSource.selector);
  }

  function test_getSpokeConfiguratorReserveAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorReserveAdminRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], ISpokeConfigurator.updateCollateralRisk.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateReceiveSharesEnabled.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateBorrowable.selector);
  }

  function test_getSpokeConfiguratorDynamicReserveAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDynamicReserveAdminRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], ISpokeConfigurator.addCollateralFactor.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateCollateralFactor.selector);
    assertEq(selectors[2], ISpokeConfigurator.addDynamicReserveConfig.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateDynamicReserveConfig.selector);
  }

  function test_getSpokeConfiguratorPositionManagerAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPositionManagerAdminRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], ISpokeConfigurator.updatePositionManager.selector);
  }

  function test_getSpokeConfiguratorLiquidationUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateHealthFactorForMaxBonus.selector);
    assertEq(selectors[2], ISpokeConfigurator.updateLiquidationBonusFactor.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateLiquidationConfig.selector);
  }

  function test_getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper
      .getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors();
    assertEq(selectors.length, 4);
    assertEq(selectors[0], ISpokeConfigurator.addMaxLiquidationBonus.selector);
    assertEq(selectors[1], ISpokeConfigurator.updateMaxLiquidationBonus.selector);
    assertEq(selectors[2], ISpokeConfigurator.addLiquidationFee.selector);
    assertEq(selectors[3], ISpokeConfigurator.updateLiquidationFee.selector);
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

  function test_canCall_spokePriceAdminRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPriceAdminRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      selectors: selectors
    });
    _assertCanCall(spokeConfigurator, selectors);
  }

  function test_canCall_spokeReserveAdminRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorReserveAdminRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE,
      selectors: selectors
    });
    _assertCanCall(spokeConfigurator, selectors);
  }

  function test_canCall_spokeDynamicReserveAdminRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorDynamicReserveAdminRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE,
      selectors: selectors
    });
    _assertCanCall(spokeConfigurator, selectors);
  }

  function test_canCall_spokePositionManagerAdminRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getSpokeConfiguratorPositionManagerAdminRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE,
      selectors: selectors
    });
    _assertCanCall(spokeConfigurator, selectors);
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
    _assertCanCall(spokeConfigurator, selectors);
  }

  function test_canCall_spokeDynamicLiquidationUpdaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper
      .getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors();
    wrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator,
      role: Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE,
      selectors: selectors
    });
    _assertCanCall(spokeConfigurator, selectors);
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
    _assertCanCall(spokeConfigurator, selectors);
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
    _assertCanCall(spokeConfigurator, selectors);
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
    _assertCanCall(spokeConfigurator, selectors);
  }

  function test_canCall_spokeConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantSpokeConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupSpokeConfiguratorRoles({
      accessManager: accessManager,
      spokeConfigurator: spokeConfigurator
    });

    bytes4[][9] memory selectorGroups;
    selectorGroups[0] = wrapper.getSpokeConfiguratorPriceAdminRoleSelectors();
    selectorGroups[1] = wrapper.getSpokeConfiguratorReserveAdminRoleSelectors();
    selectorGroups[2] = wrapper.getSpokeConfiguratorDynamicReserveAdminRoleSelectors();
    selectorGroups[3] = wrapper.getSpokeConfiguratorPositionManagerAdminRoleSelectors();
    selectorGroups[4] = wrapper.getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    selectorGroups[5] = wrapper.getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors();
    selectorGroups[6] = wrapper.getSpokeConfiguratorReserveAdderRoleSelectors();
    selectorGroups[7] = wrapper.getSpokeConfiguratorFreezerRoleSelectors();
    selectorGroups[8] = wrapper.getSpokeConfiguratorPauserRoleSelectors();

    for (uint256 group; group < selectorGroups.length; group++) {
      _assertCanCall(spokeConfigurator, selectorGroups[group]);
    }
  }
}
