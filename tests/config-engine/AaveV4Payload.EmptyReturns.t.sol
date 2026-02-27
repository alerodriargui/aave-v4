// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';
import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/IAaveV4ConfigEngine.sol';

/// @dev Minimal concrete payload that does NOT override any virtual methods.
///   Calling execute() on this exercises every base virtual method returning empty arrays,
///   plus the no-op _preExecute / _postExecute hooks.
contract MinimalAaveV4Payload is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}
}

/// @dev Payload that exposes base virtual methods through external wrappers for direct testing.
contract ExposedAaveV4Payload is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

  // Hub getters
  function exposed_hubAssetListings() external returns (IAaveV4ConfigEngine.AssetListing[] memory) {
    return hubAssetListings();
  }

  function exposed_hubFeeConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.FeeConfigUpdate[] memory)
  {
    return hubFeeConfigUpdates();
  }

  function exposed_hubInterestRateUpdates()
    external
    returns (IAaveV4ConfigEngine.InterestRateUpdate[] memory)
  {
    return hubInterestRateUpdates();
  }

  function exposed_hubReinvestmentControllerUpdates()
    external
    returns (IAaveV4ConfigEngine.ReinvestmentControllerUpdate[] memory)
  {
    return hubReinvestmentControllerUpdates();
  }

  function exposed_hubSpokeAdditions()
    external
    returns (IAaveV4ConfigEngine.SpokeAddition[] memory)
  {
    return hubSpokeAdditions();
  }

  function exposed_hubSpokeToAssetsAdditions()
    external
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory)
  {
    return hubSpokeToAssetsAdditions();
  }

  function exposed_hubSpokeCapsUpdates()
    external
    returns (IAaveV4ConfigEngine.SpokeCapsUpdate[] memory)
  {
    return hubSpokeCapsUpdates();
  }

  function exposed_hubSpokeRiskPremiumThresholdUpdates()
    external
    returns (IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[] memory)
  {
    return hubSpokeRiskPremiumThresholdUpdates();
  }

  function exposed_hubSpokeStatusUpdates()
    external
    returns (IAaveV4ConfigEngine.SpokeStatusUpdate[] memory)
  {
    return hubSpokeStatusUpdates();
  }

  function exposed_hubAssetHalts() external returns (IAaveV4ConfigEngine.AssetHalt[] memory) {
    return hubAssetHalts();
  }

  function exposed_hubAssetDeactivations()
    external
    returns (IAaveV4ConfigEngine.AssetDeactivation[] memory)
  {
    return hubAssetDeactivations();
  }

  function exposed_hubAssetCapsResets()
    external
    returns (IAaveV4ConfigEngine.AssetCapsReset[] memory)
  {
    return hubAssetCapsResets();
  }

  function exposed_hubSpokeHalts() external returns (IAaveV4ConfigEngine.SpokeHalt[] memory) {
    return hubSpokeHalts();
  }

  function exposed_hubSpokeDeactivations()
    external
    returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory)
  {
    return hubSpokeDeactivations();
  }

  function exposed_hubSpokeCapsResets()
    external
    returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory)
  {
    return hubSpokeCapsResets();
  }

  // Spoke getters
  function exposed_spokeReserveListings()
    external
    returns (IAaveV4ConfigEngine.ReserveListing[] memory)
  {
    return spokeReserveListings();
  }

  function exposed_spokeReserveConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory)
  {
    return spokeReserveConfigUpdates();
  }

  function exposed_spokeReservePriceSourceUpdates()
    external
    returns (IAaveV4ConfigEngine.ReservePriceSourceUpdate[] memory)
  {
    return spokeReservePriceSourceUpdates();
  }

  function exposed_spokeLiquidationConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory)
  {
    return spokeLiquidationConfigUpdates();
  }

  function exposed_spokeDynamicReserveConfigAdditions()
    external
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory)
  {
    return spokeDynamicReserveConfigAdditions();
  }

  function exposed_spokeDynamicReserveConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory)
  {
    return spokeDynamicReserveConfigUpdates();
  }

  function exposed_spokeCollateralFactorAdditions()
    external
    returns (IAaveV4ConfigEngine.CollateralFactorAddition[] memory)
  {
    return spokeCollateralFactorAdditions();
  }

  function exposed_spokeCollateralFactorUpdates()
    external
    returns (IAaveV4ConfigEngine.CollateralFactorUpdate[] memory)
  {
    return spokeCollateralFactorUpdates();
  }

  function exposed_spokeMaxLiquidationBonusAdditions()
    external
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] memory)
  {
    return spokeMaxLiquidationBonusAdditions();
  }

  function exposed_spokeMaxLiquidationBonusUpdates()
    external
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] memory)
  {
    return spokeMaxLiquidationBonusUpdates();
  }

  function exposed_spokeLiquidationFeeAdditions()
    external
    returns (IAaveV4ConfigEngine.LiquidationFeeAddition[] memory)
  {
    return spokeLiquidationFeeAdditions();
  }

  function exposed_spokeLiquidationFeeUpdates()
    external
    returns (IAaveV4ConfigEngine.LiquidationFeeUpdate[] memory)
  {
    return spokeLiquidationFeeUpdates();
  }

  function exposed_spokeAllReservesPauses()
    external
    returns (IAaveV4ConfigEngine.SpokePause[] memory)
  {
    return spokeAllReservesPauses();
  }

  function exposed_spokeAllReservesFreezes()
    external
    returns (IAaveV4ConfigEngine.SpokeFreeze[] memory)
  {
    return spokeAllReservesFreezes();
  }

  function exposed_spokeReservePauses()
    external
    returns (IAaveV4ConfigEngine.ReservePause[] memory)
  {
    return spokeReservePauses();
  }

  function exposed_spokeReserveFreezes()
    external
    returns (IAaveV4ConfigEngine.ReserveFreeze[] memory)
  {
    return spokeReserveFreezes();
  }

  function exposed_spokePositionManagerUpdates()
    external
    returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory)
  {
    return spokePositionManagerUpdates();
  }

  // Access manager getters
  function exposed_accessManagerRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrant[] memory)
  {
    return accessManagerRoleGrants();
  }

  function exposed_accessManagerRoleRevocations()
    external
    returns (IAaveV4ConfigEngine.RoleRevocation[] memory)
  {
    return accessManagerRoleRevocations();
  }

  function exposed_accessManagerRoleAdminUpdates()
    external
    returns (IAaveV4ConfigEngine.RoleAdminUpdate[] memory)
  {
    return accessManagerRoleAdminUpdates();
  }

  function exposed_accessManagerRoleGuardianUpdates()
    external
    returns (IAaveV4ConfigEngine.RoleGuardianUpdate[] memory)
  {
    return accessManagerRoleGuardianUpdates();
  }

  function exposed_accessManagerTargetFunctionRoleUpdates()
    external
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory)
  {
    return accessManagerTargetFunctionRoleUpdates();
  }

  function exposed_accessManagerTargetClosedUpdates()
    external
    returns (IAaveV4ConfigEngine.TargetClosedUpdate[] memory)
  {
    return accessManagerTargetClosedUpdates();
  }

  function exposed_accessManagerRoleLabelUpdates()
    external
    returns (IAaveV4ConfigEngine.RoleLabelUpdate[] memory)
  {
    return accessManagerRoleLabelUpdates();
  }

  function exposed_accessManagerGrantDelayUpdates()
    external
    returns (IAaveV4ConfigEngine.GrantDelayUpdate[] memory)
  {
    return accessManagerGrantDelayUpdates();
  }

  function exposed_accessManagerTargetAdminDelayUpdates()
    external
    returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory)
  {
    return accessManagerTargetAdminDelayUpdates();
  }

  // Convenience role grant getters
  function exposed_hubConfiguratorFeeUpdaterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorFeeUpdaterRoleGrants();
  }

  function exposed_hubConfiguratorReinvestmentUpdaterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorReinvestmentUpdaterRoleGrants();
  }

  function exposed_hubConfiguratorAssetListerRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorAssetListerRoleGrants();
  }

  function exposed_hubConfiguratorSpokeAdderRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorSpokeAdderRoleGrants();
  }

  function exposed_hubConfiguratorInterestRateUpdaterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorInterestRateUpdaterRoleGrants();
  }

  function exposed_hubConfiguratorHalterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorHalterRoleGrants();
  }

  function exposed_hubConfiguratorDeactivaterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorDeactivaterRoleGrants();
  }

  function exposed_hubConfiguratorCapsUpdaterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorCapsUpdaterRoleGrants();
  }

  function exposed_hubConfiguratorAllRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return hubConfiguratorAllRoleGrants();
  }

  function exposed_spokeConfiguratorAdminRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return spokeConfiguratorAdminRoleGrants();
  }

  function exposed_spokeConfiguratorLiquidationUpdaterRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return spokeConfiguratorLiquidationUpdaterRoleGrants();
  }

  function exposed_spokeConfiguratorReserveAdderRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return spokeConfiguratorReserveAdderRoleGrants();
  }

  function exposed_spokeConfiguratorFreezerRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return spokeConfiguratorFreezerRoleGrants();
  }

  function exposed_spokeConfiguratorPauserRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return spokeConfiguratorPauserRoleGrants();
  }

  function exposed_spokeConfiguratorAllRoleGrants()
    external
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return spokeConfiguratorAllRoleGrants();
  }
}

contract AaveV4PayloadEmptyReturnsTest is BaseConfigEngineTest {
  MinimalAaveV4Payload public minimal;
  ExposedAaveV4Payload public exposed;

  function setUp() public override {
    super.setUp();
    minimal = new MinimalAaveV4Payload(IAaveV4ConfigEngine(address(engine)));
    exposed = new ExposedAaveV4Payload(IAaveV4ConfigEngine(address(engine)));
  }

  /// @dev Calling execute() on the minimal payload exercises _preExecute, _postExecute,
  ///   _executeHubActions, _executeSpokeActions, _executeAccessManagerActions, and every
  ///   base virtual getter (all returning empty arrays, so no delegatecalls are made).
  function test_minimalPayload_execute_noReverts() public {
    minimal.execute();
  }

  // ============================================================
  // Hub virtual methods return empty arrays
  // ============================================================

  function test_hubAssetListings_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetListings().length, 0);
  }

  function test_hubFeeConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubFeeConfigUpdates().length, 0);
  }

  function test_hubInterestRateUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubInterestRateUpdates().length, 0);
  }

  function test_hubReinvestmentControllerUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubReinvestmentControllerUpdates().length, 0);
  }

  function test_hubSpokeAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeAdditions().length, 0);
  }

  function test_hubSpokeToAssetsAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeToAssetsAdditions().length, 0);
  }

  function test_hubSpokeCapsUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeCapsUpdates().length, 0);
  }

  function test_hubSpokeRiskPremiumThresholdUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeRiskPremiumThresholdUpdates().length, 0);
  }

  function test_hubSpokeStatusUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeStatusUpdates().length, 0);
  }

  function test_hubAssetHalts_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetHalts().length, 0);
  }

  function test_hubAssetDeactivations_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetDeactivations().length, 0);
  }

  function test_hubAssetCapsResets_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetCapsResets().length, 0);
  }

  function test_hubSpokeHalts_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeHalts().length, 0);
  }

  function test_hubSpokeDeactivations_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeDeactivations().length, 0);
  }

  function test_hubSpokeCapsResets_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeCapsResets().length, 0);
  }

  // ============================================================
  // Spoke virtual methods return empty arrays
  // ============================================================

  function test_spokeReserveListings_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReserveListings().length, 0);
  }

  function test_spokeReserveConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReserveConfigUpdates().length, 0);
  }

  function test_spokeReservePriceSourceUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReservePriceSourceUpdates().length, 0);
  }

  function test_spokeLiquidationConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeLiquidationConfigUpdates().length, 0);
  }

  function test_spokeDynamicReserveConfigAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_spokeDynamicReserveConfigAdditions().length, 0);
  }

  function test_spokeDynamicReserveConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeDynamicReserveConfigUpdates().length, 0);
  }

  function test_spokeCollateralFactorAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_spokeCollateralFactorAdditions().length, 0);
  }

  function test_spokeCollateralFactorUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeCollateralFactorUpdates().length, 0);
  }

  function test_spokeMaxLiquidationBonusAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_spokeMaxLiquidationBonusAdditions().length, 0);
  }

  function test_spokeMaxLiquidationBonusUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeMaxLiquidationBonusUpdates().length, 0);
  }

  function test_spokeLiquidationFeeAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_spokeLiquidationFeeAdditions().length, 0);
  }

  function test_spokeLiquidationFeeUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeLiquidationFeeUpdates().length, 0);
  }

  function test_spokeAllReservesPauses_returnsEmpty() public {
    assertEq(exposed.exposed_spokeAllReservesPauses().length, 0);
  }

  function test_spokeAllReservesFreezes_returnsEmpty() public {
    assertEq(exposed.exposed_spokeAllReservesFreezes().length, 0);
  }

  function test_spokeReservePauses_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReservePauses().length, 0);
  }

  function test_spokeReserveFreezes_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReserveFreezes().length, 0);
  }

  function test_spokePositionManagerUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokePositionManagerUpdates().length, 0);
  }

  // ============================================================
  // Access Manager virtual methods return empty arrays
  // ============================================================

  function test_accessManagerRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleGrants().length, 0);
  }

  function test_accessManagerRoleRevocations_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleRevocations().length, 0);
  }

  function test_accessManagerRoleAdminUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleAdminUpdates().length, 0);
  }

  function test_accessManagerRoleGuardianUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleGuardianUpdates().length, 0);
  }

  function test_accessManagerTargetFunctionRoleUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerTargetFunctionRoleUpdates().length, 0);
  }

  function test_accessManagerTargetClosedUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerTargetClosedUpdates().length, 0);
  }

  function test_accessManagerRoleLabelUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleLabelUpdates().length, 0);
  }

  function test_accessManagerGrantDelayUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerGrantDelayUpdates().length, 0);
  }

  function test_accessManagerTargetAdminDelayUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerTargetAdminDelayUpdates().length, 0);
  }

  // ============================================================
  // Convenience role grant virtual methods return empty arrays
  // ============================================================

  function test_hubConfiguratorFeeUpdaterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorFeeUpdaterRoleGrants().length, 0);
  }

  function test_hubConfiguratorReinvestmentUpdaterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorReinvestmentUpdaterRoleGrants().length, 0);
  }

  function test_hubConfiguratorAssetListerRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorAssetListerRoleGrants().length, 0);
  }

  function test_hubConfiguratorSpokeAdderRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorSpokeAdderRoleGrants().length, 0);
  }

  function test_hubConfiguratorInterestRateUpdaterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorInterestRateUpdaterRoleGrants().length, 0);
  }

  function test_hubConfiguratorHalterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorHalterRoleGrants().length, 0);
  }

  function test_hubConfiguratorDeactivaterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorDeactivaterRoleGrants().length, 0);
  }

  function test_hubConfiguratorCapsUpdaterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorCapsUpdaterRoleGrants().length, 0);
  }

  function test_hubConfiguratorAllRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_hubConfiguratorAllRoleGrants().length, 0);
  }

  function test_spokeConfiguratorAdminRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_spokeConfiguratorAdminRoleGrants().length, 0);
  }

  function test_spokeConfiguratorLiquidationUpdaterRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_spokeConfiguratorLiquidationUpdaterRoleGrants().length, 0);
  }

  function test_spokeConfiguratorReserveAdderRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_spokeConfiguratorReserveAdderRoleGrants().length, 0);
  }

  function test_spokeConfiguratorFreezerRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_spokeConfiguratorFreezerRoleGrants().length, 0);
  }

  function test_spokeConfiguratorPauserRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_spokeConfiguratorPauserRoleGrants().length, 0);
  }

  function test_spokeConfiguratorAllRoleGrants_returnsEmpty() public {
    assertEq(exposed.exposed_spokeConfiguratorAllRoleGrants().length, 0);
  }
}
