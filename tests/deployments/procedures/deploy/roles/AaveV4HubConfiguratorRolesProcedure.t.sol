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
      role: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
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
    bytes4[] memory selectors = wrapper.getHubConfiguratorFeeUpdaterRoleSelectors();

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorRole({
      accessManager: address(0),
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      selectors: selectors
    });

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: address(0),
      role: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      selectors: selectors
    });
  }

  function test_grantHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    (bool hasFeeUpdater, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      admin
    );
    assertTrue(hasFeeUpdater);

    (bool hasReinvestmentUpdater, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      admin
    );
    assertTrue(hasReinvestmentUpdater);

    (bool hasAssetLister, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      admin
    );
    assertTrue(hasAssetLister);

    (bool hasSpokeAdder, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      admin
    );
    assertTrue(hasSpokeAdder);

    (bool hasIRUpdater, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      admin
    );
    assertTrue(hasIRUpdater);

    (bool hasHalter, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_HALTER_ROLE,
      admin
    );
    assertTrue(hasHalter);

    (bool hasDeactivater, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
      admin
    );
    assertTrue(hasDeactivater);

    (bool hasCapsUpdater, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE,
      admin
    );
    assertTrue(hasCapsUpdater);
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
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE
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
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.updateInterestRateStrategy.selector
      ),
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE
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
      Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.resetAssetCaps.selector
      ),
      Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE
    );
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.ACCESS_MANAGER_DEFAULT_ADMIN, _wrapper, 0);
  }

  function test_getHubConfiguratorFeeUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorFeeUpdaterRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], IHubConfigurator.updateLiquidityFee.selector);
    assertEq(selectors[1], IHubConfigurator.updateFeeReceiver.selector);
    assertEq(selectors[2], IHubConfigurator.updateFeeConfig.selector);
  }

  function test_getHubConfiguratorReinvestmentUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHubConfigurator.updateReinvestmentController.selector);
  }

  function test_getHubConfiguratorAssetListerRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorAssetListerRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.addAsset.selector);
    assertEq(selectors[1], IHubConfigurator.addAssetWithDecimals.selector);
  }

  function test_getHubConfiguratorSpokeAdderRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorSpokeAdderRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], IHubConfigurator.addSpoke.selector);
    assertEq(selectors[1], IHubConfigurator.addSpokeToAssets.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeRiskPremiumThreshold.selector);
  }

  function test_getHubConfiguratorInterestRateUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorInterestRateUpdaterRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.updateInterestRateStrategy.selector);
    assertEq(selectors[1], IHubConfigurator.updateInterestRateData.selector);
  }

  function test_getHubConfiguratorHalterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorHalterRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], IHubConfigurator.haltAsset.selector);
    assertEq(selectors[1], IHubConfigurator.haltSpoke.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeHalted.selector);
  }

  function test_getHubConfiguratorActivaterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorActivaterRoleSelectors();
    assertEq(selectors.length, 3);
    assertEq(selectors[0], IHubConfigurator.deactivateAsset.selector);
    assertEq(selectors[1], IHubConfigurator.deactivateSpoke.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeActive.selector);
  }

  function test_getHubConfiguratorCapSetterRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorCapSetterRoleSelectors();
    assertEq(selectors.length, 5);
    assertEq(selectors[0], IHubConfigurator.resetAssetCaps.selector);
    assertEq(selectors[1], IHubConfigurator.resetSpokeCaps.selector);
    assertEq(selectors[2], IHubConfigurator.updateSpokeCaps.selector);
    assertEq(selectors[3], IHubConfigurator.updateSpokeAddCap.selector);
    assertEq(selectors[4], IHubConfigurator.updateSpokeDrawCap.selector);
  }

  function test_canCall_hubFeeUpdaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorFeeUpdaterRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubReinvestmentUpdaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubAssetListerRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorAssetListerRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubSpokeAdderRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorSpokeAdderRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubInterestRateUpdaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorInterestRateUpdaterRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubHalterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_HALTER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorHalterRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_HALTER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubDeactivaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorActivaterRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubCapsUpdaterRole() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE,
      admin: admin
    });
    bytes4[] memory selectors = wrapper.getHubConfiguratorCapSetterRoleSelectors();
    wrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator,
      role: Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE,
      selectors: selectors
    });
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(
        unauthorized,
        hubConfigurator,
        selectors[i]
      );
      assertFalse(allowed);
    }
  }

  function test_canCall_hubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    bytes4[] memory feeUpdaterSelectors = wrapper.getHubConfiguratorFeeUpdaterRoleSelectors();
    for (uint256 i = 0; i < feeUpdaterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        feeUpdaterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory reinvestmentUpdaterSelectors = wrapper
      .getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    for (uint256 i = 0; i < reinvestmentUpdaterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        reinvestmentUpdaterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory assetListerSelectors = wrapper.getHubConfiguratorAssetListerRoleSelectors();
    for (uint256 i = 0; i < assetListerSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        assetListerSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory spokeAdderSelectors = wrapper.getHubConfiguratorSpokeAdderRoleSelectors();
    for (uint256 i = 0; i < spokeAdderSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        spokeAdderSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory irUpdaterSelectors = wrapper
      .getHubConfiguratorInterestRateUpdaterRoleSelectors();
    for (uint256 i = 0; i < irUpdaterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        irUpdaterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory haltSelectors = wrapper.getHubConfiguratorHalterRoleSelectors();
    for (uint256 i = 0; i < haltSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        haltSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory deactivateSelectors = wrapper.getHubConfiguratorActivaterRoleSelectors();
    for (uint256 i = 0; i < deactivateSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        deactivateSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory capsSetterSelectors = wrapper.getHubConfiguratorCapSetterRoleSelectors();
    for (uint256 i = 0; i < capsSetterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hubConfigurator,
        capsSetterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }
  }
}
