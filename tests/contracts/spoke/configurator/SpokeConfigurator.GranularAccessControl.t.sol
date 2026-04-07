// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeConfiguratorGranularAccessControlTest is Base {
  using SafeCast for uint256;

  // Granular role constants (must not collide with Roles.sol IDs 0-113, 200-309)
  uint64 constant RESERVE_MANAGER_ROLE = 1002;
  uint64 constant LIQUIDATION_CONFIG_MANAGER_ROLE = 1003;
  uint64 constant POSITION_MANAGER_ADMIN_ROLE = 1004;

  // Role holders
  address public RESERVE_MANAGER = makeAddr('RESERVE_MANAGER');
  address public LIQUIDATION_CONFIG_MANAGER = makeAddr('LIQUIDATION_CONFIG_MANAGER');
  address public POSITION_MANAGER_ADMIN = makeAddr('POSITION_MANAGER_ADMIN');

  IAccessManager public manager;

  address public spokeAddr;
  ISpoke public spoke;
  uint256 public reserveId;

  // Arrays storing calldata for each role's functions
  bytes[] internal reserveManagerCalldata;
  bytes[] internal liquidationConfigManagerCalldata;
  bytes[] internal positionManagerAdminCalldata;

  function setUp() public virtual override {
    super.setUp();

    manager = IAccessManager(spoke1.authority());
    spokeConfigurator = new SpokeConfigurator(address(manager));

    // Grant SPOKE_CONFIGURATOR_ROLE to spokeConfigurator so it can call spoke functions
    vm.startPrank(ADMIN);
    manager.grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, address(spokeConfigurator), 0);

    // Grant granular roles to role holders and set permissions from baseline
    manager.grantRole(RESERVE_MANAGER_ROLE, RESERVE_MANAGER, 0);
    manager.grantRole(LIQUIDATION_CONFIG_MANAGER_ROLE, LIQUIDATION_CONFIG_MANAGER, 0);
    manager.grantRole(POSITION_MANAGER_ADMIN_ROLE, POSITION_MANAGER_ADMIN, 0);

    (uint64[] memory roles, bytes4[][] memory selectorSets) = _expectedRoleMappings();
    for (uint256 r; r < roles.length; ++r) {
      manager.setTargetFunctionRole(address(spokeConfigurator), selectorSets[r], roles[r]);
    }

    vm.stopPrank();

    // Set up test data
    spokeAddr = address(spoke1);
    spoke = ISpoke(spokeAddr);
    reserveId = 0;

    // Build calldata arrays for testing
    _buildReserveManagerCalldata();
    _buildLiquidationConfigManagerCalldata();
    _buildPositionManagerAdminCalldata();
  }

  function _buildReserveManagerCalldata() internal {
    address newPriceSource = _deployMockPriceFeed(spoke, 1000e8);
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: 80_00,
      maxLiquidationBonus: 110_00,
      liquidationFee: 5_00
    });

    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateReservePriceSource,
        (spokeAddr, reserveId, newPriceSource)
      )
    );
    // Skipping addReserve as it requires more complex setup
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updatePaused, (spokeAddr, reserveId, true))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateFrozen, (spokeAddr, reserveId, true))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateBorrowable, (spokeAddr, reserveId, false))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateReceiveSharesEnabled, (spokeAddr, reserveId, false))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateCollateralRisk, (spokeAddr, reserveId, 50_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addCollateralFactor, (spokeAddr, reserveId, 75_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateCollateralFactor, (spokeAddr, reserveId, 0, 70_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addMaxLiquidationBonus, (spokeAddr, reserveId, 115_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateMaxLiquidationBonus,
        (spokeAddr, reserveId, 0, 112_00)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.addLiquidationFee, (spokeAddr, reserveId, 8_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateLiquidationFee, (spokeAddr, reserveId, 0, 6_00))
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.addDynamicReserveConfig,
        (spokeAddr, reserveId, dynamicConfig)
      )
    );
    reserveManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateDynamicReserveConfig,
        (spokeAddr, reserveId, 0, dynamicConfig)
      )
    );
    reserveManagerCalldata.push(abi.encodeCall(ISpokeConfigurator.pauseAllReserves, (spokeAddr)));
    reserveManagerCalldata.push(abi.encodeCall(ISpokeConfigurator.freezeAllReserves, (spokeAddr)));
  }

  function _buildLiquidationConfigManagerCalldata() internal {
    ISpoke.LiquidationConfig memory newConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: 50_00
    });

    liquidationConfigManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateLiquidationTargetHealthFactor,
        (spokeAddr, HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2)
      )
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(
        ISpokeConfigurator.updateHealthFactorForMaxBonus,
        (spokeAddr, HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2)
      )
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateLiquidationBonusFactor, (spokeAddr, 50_00))
    );
    liquidationConfigManagerCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updateLiquidationConfig, (spokeAddr, newConfig))
    );
  }

  function _buildPositionManagerAdminCalldata() internal {
    address newPM = makeAddr('NEW_POSITION_MANAGER');

    positionManagerAdminCalldata.push(
      abi.encodeCall(ISpokeConfigurator.updatePositionManager, (spokeAddr, newPM, true))
    );
  }

  function test_fuzz_unauthorized_cannotCall_reserveManagerMethods(address caller) public {
    vm.assume(caller != RESERVE_MANAGER);
    vm.assume(caller != ADMIN);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < reserveManagerCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(reserveManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_fuzz_unauthorized_cannotCall_liquidationConfigManagerMethods(
    address caller
  ) public {
    vm.assume(caller != LIQUIDATION_CONFIG_MANAGER);
    vm.assume(caller != ADMIN);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < liquidationConfigManagerCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        liquidationConfigManagerCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_fuzz_unauthorized_cannotCall_positionManagerAdminMethods(address caller) public {
    vm.assume(caller != POSITION_MANAGER_ADMIN);
    vm.assume(caller != ADMIN);
    vm.assume(caller != address(0));

    for (uint256 i = 0; i < positionManagerAdminCalldata.length; ++i) {
      vm.prank(caller);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        positionManagerAdminCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    }
  }

  function test_reserveManager_cannotCall_anyLiquidationConfigMethod() public {
    for (uint256 i = 0; i < liquidationConfigManagerCalldata.length; ++i) {
      vm.prank(RESERVE_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        liquidationConfigManagerCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, RESERVE_MANAGER)
      );
    }
  }

  function test_reserveManager_cannotCall_anyPositionManagerAdminMethod() public {
    for (uint256 i = 0; i < positionManagerAdminCalldata.length; ++i) {
      vm.prank(RESERVE_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        positionManagerAdminCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, RESERVE_MANAGER)
      );
    }
  }

  function test_liquidationConfigManager_cannotCall_anyReserveMethod() public {
    for (uint256 i = 0; i < reserveManagerCalldata.length; ++i) {
      vm.prank(LIQUIDATION_CONFIG_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(reserveManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          LIQUIDATION_CONFIG_MANAGER
        )
      );
    }
  }

  function test_liquidationConfigManager_cannotCall_anyPositionManagerAdminMethod() public {
    for (uint256 i = 0; i < positionManagerAdminCalldata.length; ++i) {
      vm.prank(LIQUIDATION_CONFIG_MANAGER);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        positionManagerAdminCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          LIQUIDATION_CONFIG_MANAGER
        )
      );
    }
  }

  function test_positionManagerAdmin_cannotCall_anyReserveMethod() public {
    for (uint256 i = 0; i < reserveManagerCalldata.length; ++i) {
      vm.prank(POSITION_MANAGER_ADMIN);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(reserveManagerCalldata[i]);
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          POSITION_MANAGER_ADMIN
        )
      );
    }
  }

  function test_positionManagerAdmin_cannotCall_anyLiquidationConfigMethod() public {
    for (uint256 i = 0; i < liquidationConfigManagerCalldata.length; ++i) {
      vm.prank(POSITION_MANAGER_ADMIN);
      (bool ok, bytes memory ret) = address(spokeConfigurator).call(
        liquidationConfigManagerCalldata[i]
      );
      assertFalse(ok);
      assertEq(
        ret,
        abi.encodeWithSelector(
          IAccessManaged.AccessManagedUnauthorized.selector,
          POSITION_MANAGER_ADMIN
        )
      );
    }
  }

  function test_reserveManager_canCall_updatePaused() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.updatePaused(spokeAddr, reserveId, true);

    assertTrue(spoke.getReserveConfig(reserveId).paused);
  }

  function test_reserveManager_canCall_updateFrozen() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.updateFrozen(spokeAddr, reserveId, true);

    assertTrue(spoke.getReserveConfig(reserveId).frozen);
  }

  function test_reserveManager_canCall_pauseAllReserves() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.pauseAllReserves(spokeAddr);

    for (uint256 i = 0; i < spoke.getReserveCount(); ++i) {
      assertTrue(spoke.getReserveConfig(i).paused);
    }
  }

  function test_reserveManager_canCall_freezeAllReserves() public {
    vm.prank(RESERVE_MANAGER);
    spokeConfigurator.freezeAllReserves(spokeAddr);

    for (uint256 i = 0; i < spoke.getReserveCount(); ++i) {
      assertTrue(spoke.getReserveConfig(i).frozen);
    }
  }

  function test_liquidationConfigManager_canCall_updateLiquidationTargetHealthFactor() public {
    uint128 newTarget = HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2;

    vm.prank(LIQUIDATION_CONFIG_MANAGER);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spokeAddr, newTarget);

    assertEq(spoke.getLiquidationConfig().targetHealthFactor, newTarget);
  }

  function test_liquidationConfigManager_canCall_updateLiquidationConfig() public {
    ISpoke.LiquidationConfig memory newConfig = ISpoke.LiquidationConfig({
      targetHealthFactor: HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 2,
      healthFactorForMaxBonus: HEALTH_FACTOR_LIQUIDATION_THRESHOLD / 2,
      liquidationBonusFactor: 50_00
    });

    vm.prank(LIQUIDATION_CONFIG_MANAGER);
    spokeConfigurator.updateLiquidationConfig(spokeAddr, newConfig);

    assertEq(spoke.getLiquidationConfig(), newConfig);
  }

  function test_positionManagerAdmin_canCall_updatePositionManager() public {
    address newPM = makeAddr('NEW_POSITION_MANAGER');

    vm.prank(POSITION_MANAGER_ADMIN);
    spokeConfigurator.updatePositionManager({
      spoke: spokeAddr,
      positionManager: newPM,
      active: true
    });

    assertTrue(spoke.isPositionManagerActive(newPM));
  }

  /// @notice Validates that every SpokeConfigurator selector is assigned to exactly one role.
  function test_static_allSelectorsAssignedToExactlyOneRole() public pure {
    bytes4[] memory allSelectors = _allSpokeConfiguratorSelectors();
    (uint64[] memory roles, bytes4[][] memory selectorSets) = _expectedRoleMappings();

    for (uint256 s; s < allSelectors.length; ++s) {
      uint256 assignedCount;
      for (uint256 r; r < roles.length; ++r) {
        for (uint256 i; i < selectorSets[r].length; ++i) {
          if (selectorSets[r][i] == allSelectors[s]) {
            ++assignedCount;
          }
        }
      }
      assertEq(assignedCount, 1, 'selector not assigned to exactly one role');
    }
  }

  /// @dev Returns all external restricted selectors on SpokeConfigurator.
  function _allSpokeConfiguratorSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](24);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.addReserve.selector;
    selectors[2] = ISpokeConfigurator.updatePaused.selector;
    selectors[3] = ISpokeConfigurator.updateFrozen.selector;
    selectors[4] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[5] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[6] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[7] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[8] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[9] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[10] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[11] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[12] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[13] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[14] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[15] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[16] = ISpokeConfigurator.freezeAllReserves.selector;
    selectors[17] = ISpokeConfigurator.pauseReserve.selector;
    selectors[18] = ISpokeConfigurator.freezeReserve.selector;
    selectors[19] = ISpokeConfigurator.updatePositionManager.selector;
    selectors[20] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[21] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[22] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[23] = ISpokeConfigurator.updateLiquidationConfig.selector;
    return selectors;
  }

  /// @dev Returns the expected role-to-selector mapping as parallel arrays.
  function _expectedRoleMappings()
    internal
    pure
    returns (uint64[] memory roles, bytes4[][] memory selectorSets)
  {
    roles = new uint64[](3);
    selectorSets = new bytes4[][](3);

    // RESERVE_MANAGER_ROLE
    roles[0] = RESERVE_MANAGER_ROLE;
    selectorSets[0] = new bytes4[](19);
    selectorSets[0][0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectorSets[0][1] = ISpokeConfigurator.addReserve.selector;
    selectorSets[0][2] = ISpokeConfigurator.updatePaused.selector;
    selectorSets[0][3] = ISpokeConfigurator.updateFrozen.selector;
    selectorSets[0][4] = ISpokeConfigurator.updateBorrowable.selector;
    selectorSets[0][5] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectorSets[0][6] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectorSets[0][7] = ISpokeConfigurator.addCollateralFactor.selector;
    selectorSets[0][8] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectorSets[0][9] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectorSets[0][10] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectorSets[0][11] = ISpokeConfigurator.addLiquidationFee.selector;
    selectorSets[0][12] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectorSets[0][13] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectorSets[0][14] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectorSets[0][15] = ISpokeConfigurator.pauseAllReserves.selector;
    selectorSets[0][16] = ISpokeConfigurator.freezeAllReserves.selector;
    selectorSets[0][17] = ISpokeConfigurator.pauseReserve.selector;
    selectorSets[0][18] = ISpokeConfigurator.freezeReserve.selector;

    // LIQUIDATION_CONFIG_MANAGER_ROLE
    roles[1] = LIQUIDATION_CONFIG_MANAGER_ROLE;
    selectorSets[1] = new bytes4[](4);
    selectorSets[1][0] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectorSets[1][1] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectorSets[1][2] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectorSets[1][3] = ISpokeConfigurator.updateLiquidationConfig.selector;

    // POSITION_MANAGER_ADMIN_ROLE
    roles[2] = POSITION_MANAGER_ADMIN_ROLE;
    selectorSets[2] = new bytes4[](1);
    selectorSets[2][0] = ISpokeConfigurator.updatePositionManager.selector;
  }

  /// @notice Validates that test role IDs don't collide with production Roles.sol constants.
  function test_static_granularRoleIds_noCollision() public pure {
    uint64[4] memory productionRoles = [
      Roles.ACCESS_MANAGER_ADMIN_ROLE,
      Roles.SPOKE_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
    ];

    uint64[3] memory testRoles = [
      RESERVE_MANAGER_ROLE,
      LIQUIDATION_CONFIG_MANAGER_ROLE,
      POSITION_MANAGER_ADMIN_ROLE
    ];

    for (uint256 i; i < testRoles.length; ++i) {
      for (uint256 j; j < productionRoles.length; ++j) {
        assertTrue(testRoles[i] != productionRoles[j], 'test role collides with production role');
      }
    }
  }
}
