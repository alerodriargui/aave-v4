// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

contract AaveV4HubConfiguratorRolesProcedureTest is ProceduresBase {
  AaveV4HubConfiguratorRolesProcedureWrapper public wrapper;
  address public hubConfigurator = makeAddr('hubConfigurator');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4HubConfiguratorRolesProcedureWrapper();
  }

  function test_grantHubConfiguratorRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.grantHubConfiguratorRole({
      accessManager: address(0),
      role: Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      admin: address(0)
    });
  }

  function test_setupHubConfiguratorAllRoles_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: address(0),
      hubConfigurator: hubConfigurator
    });

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: address(0)
    });
  }

  function test_setupHubConfiguratorRole_reverts() public {
    bytes4[] memory selectors = wrapper.getHubConfiguratorLiquidityFeeUpdaterRoleSelectors();

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorRole({
      accessManager: address(0),
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      selectors: selectors
    });

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: address(0),
      role: Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      selectors: selectors
    });
  }

  function test_grantHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    uint64[14] memory roles = [
      Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE,
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_HALTER_ROLE,
      Roles.HUB_CONFIGURATOR_DEACTIVATOR_ROLE,
      Roles.HUB_CONFIGURATOR_CAPS_RESETTER_ROLE,
      Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE
    ];

    for (uint256 idx; idx < roles.length; idx++) {
      (bool hasRole, ) = IAccessManager(accessManager).hasRole(roles[idx], admin);
      assertTrue(hasRole);
    }
  }

  function test_setupHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateLiquidityFee.selector
      ),
      Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateFeeReceiver.selector
      ),
      Roles.HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateFeeConfig.selector
      ),
      Roles.HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateReinvestmentController.selector
      ),
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.haltAsset.selector
      ),
      Roles.HUB_CONFIGURATOR_HALTER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.deactivateAsset.selector
      ),
      Roles.HUB_CONFIGURATOR_DEACTIVATOR_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.resetAssetCaps.selector
      ),
      Roles.HUB_CONFIGURATOR_CAPS_RESETTER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateSpokeCaps.selector
      ),
      Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateSpokeDrawCap.selector
      ),
      Roles.HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateSpokeAddCap.selector
      ),
      Roles.HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateSpokeRiskPremiumThreshold.selector
      ),
      Roles.HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateInterestRateStrategy.selector
      ),
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateInterestRateData.selector
      ),
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.addAsset.selector
      ),
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.addSpoke.selector
      ),
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE
    );
  }

  function _grantAdminToWrapper(address wrapperAddr) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_DEFAULT_ADMIN, wrapperAddr, 0);
  }

  function test_canCall_hubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    bytes4[][14] memory selectorGroups;
    selectorGroups[0] = wrapper.getHubConfiguratorLiquidityFeeUpdaterRoleSelectors();
    selectorGroups[1] = wrapper.getHubConfiguratorFeeConfiguratorRoleSelectors();
    selectorGroups[2] = wrapper.getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    selectorGroups[3] = wrapper.getHubConfiguratorHalterRoleSelectors();
    selectorGroups[4] = wrapper.getHubConfiguratorDeactivatorRoleSelectors();
    selectorGroups[5] = wrapper.getHubConfiguratorCapsResetterRoleSelectors();
    selectorGroups[6] = wrapper.getHubConfiguratorCapsUpdaterRoleSelectors();
    selectorGroups[7] = wrapper.getHubConfiguratorDrawCapUpdaterRoleSelectors();
    selectorGroups[8] = wrapper.getHubConfiguratorAddCapUpdaterRoleSelectors();
    selectorGroups[9] = wrapper.getHubConfiguratorSpokeRiskAdminRoleSelectors();
    selectorGroups[10] = wrapper.getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors();
    selectorGroups[11] = wrapper.getHubConfiguratorInterestRateDataUpdaterRoleSelectors();
    selectorGroups[12] = wrapper.getHubConfiguratorAssetListerRoleSelectors();
    selectorGroups[13] = wrapper.getHubConfiguratorSpokeAdderRoleSelectors();

    for (uint256 group; group < selectorGroups.length; group++) {
      _assertCanCall(hubConfigurator, selectorGroups[group]);
    }
  }

  function test_getHubConfiguratorLiquidityFeeUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorLiquidityFeeUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateLiquidityFee.selector);
  }

  function test_getHubConfiguratorFeeConfiguratorRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorFeeConfiguratorRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.updateFeeReceiver.selector);
    assertEq(selectors[1], IHubConfigurator.updateFeeConfig.selector);
  }

  function test_getHubConfiguratorReinvestmentUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateReinvestmentController.selector);
  }

  function test_getHubConfiguratorHalterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorHalterRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], IHubConfigurator.haltAsset.selector);
    assertEq(selectors[1], IHubConfigurator.haltSpoke.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeHalted.selector);
  }

  function test_getHubConfiguratorDeactivatorRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorDeactivatorRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], IHubConfigurator.deactivateAsset.selector);
    assertEq(selectors[1], IHubConfigurator.deactivateSpoke.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeActive.selector);
  }

  function test_getHubConfiguratorCapsResetterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorCapsResetterRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.resetAssetCaps.selector);
    assertEq(selectors[1], IHubConfigurator.resetSpokeCaps.selector);
  }

  function test_getHubConfiguratorCapsUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorCapsUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateSpokeCaps.selector);
  }

  function test_getHubConfiguratorDrawCapUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorDrawCapUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateSpokeDrawCap.selector);
  }

  function test_getHubConfiguratorAddCapUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorAddCapUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateSpokeAddCap.selector);
  }

  function test_getHubConfiguratorSpokeRiskAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorSpokeRiskAdminRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateSpokeRiskPremiumThreshold.selector);
  }

  function test_getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper
      .getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateInterestRateStrategy.selector);
  }

  function test_getHubConfiguratorInterestRateDataUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorInterestRateDataUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateInterestRateData.selector);
  }

  function test_getHubConfiguratorAssetListerRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorAssetListerRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.addAsset.selector);
    assertEq(selectors[1], IHubConfigurator.addAssetWithDecimals.selector);
  }

  function test_getHubConfiguratorSpokeAdderRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorSpokeAdderRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.addSpoke.selector);
    assertEq(selectors[1], IHubConfigurator.addSpokeToAssets.selector);
  }
}
