// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {HubEngine} from 'src/config-engine/libraries/HubEngine.sol';
import {SpokeEngine} from 'src/config-engine/libraries/SpokeEngine.sol';
import {AccessManagerEngine} from 'src/config-engine/libraries/AccessManagerEngine.sol';

/// @title AaveV4ConfigEngine
/// @author Aave Labs
/// @notice Stateless implementation of IAaveV4ConfigEngine. Invoked via delegatecall from payload contracts.
contract AaveV4ConfigEngine is IAaveV4ConfigEngine {
  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetListings(AssetListing[] calldata listings) external {
    HubEngine.executeHubAssetListings(listings);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubFeeConfigUpdates(FeeConfigUpdate[] calldata updates) external {
    HubEngine.executeHubFeeConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubInterestRateUpdates(InterestRateUpdate[] calldata updates) external {
    HubEngine.executeHubInterestRateUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubReinvestmentControllerUpdates(
    ReinvestmentControllerUpdate[] calldata updates
  ) external {
    HubEngine.executeHubReinvestmentControllerUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeAdditions(SpokeAddition[] calldata additions) external {
    HubEngine.executeHubSpokeAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeToAssetsAdditions(SpokeToAssetsAddition[] calldata additions) external {
    HubEngine.executeHubSpokeToAssetsAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeCapsUpdates(SpokeCapsUpdate[] calldata updates) external {
    HubEngine.executeHubSpokeCapsUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeRiskPremiumThresholdUpdates(
    SpokeRiskPremiumThresholdUpdate[] calldata updates
  ) external {
    HubEngine.executeHubSpokeRiskPremiumThresholdUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeStatusUpdates(SpokeStatusUpdate[] calldata updates) external {
    HubEngine.executeHubSpokeStatusUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetHalts(AssetHalt[] calldata halts) external {
    HubEngine.executeHubAssetHalts(halts);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetDeactivations(AssetDeactivation[] calldata deactivations) external {
    HubEngine.executeHubAssetDeactivations(deactivations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetCapsResets(AssetCapsReset[] calldata resets) external {
    HubEngine.executeHubAssetCapsResets(resets);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeHalts(SpokeHalt[] calldata halts) external {
    HubEngine.executeHubSpokeHalts(halts);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeDeactivations(SpokeDeactivation[] calldata deactivations) external {
    HubEngine.executeHubSpokeDeactivations(deactivations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeCapsResets(SpokeCapsReset[] calldata resets) external {
    HubEngine.executeHubSpokeCapsResets(resets);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveListings(ReserveListing[] calldata listings) external {
    SpokeEngine.executeSpokeReserveListings(listings);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveConfigUpdates(ReserveConfigUpdate[] calldata updates) external {
    SpokeEngine.executeSpokeReserveConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReservePriceSourceUpdates(
    ReservePriceSourceUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeReservePriceSourceUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeLiquidationConfigUpdates(
    LiquidationConfigUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeLiquidationConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigAdditions(
    DynamicReserveConfigAddition[] calldata additions
  ) external {
    SpokeEngine.executeSpokeDynamicReserveConfigAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigUpdates(
    DynamicReserveConfigUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeDynamicReserveConfigUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeCollateralFactorAdditions(
    CollateralFactorAddition[] calldata additions
  ) external {
    SpokeEngine.executeSpokeCollateralFactorAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeCollateralFactorUpdates(CollateralFactorUpdate[] calldata updates) external {
    SpokeEngine.executeSpokeCollateralFactorUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeMaxLiquidationBonusAdditions(
    MaxLiquidationBonusAddition[] calldata additions
  ) external {
    SpokeEngine.executeSpokeMaxLiquidationBonusAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeMaxLiquidationBonusUpdates(
    MaxLiquidationBonusUpdate[] calldata updates
  ) external {
    SpokeEngine.executeSpokeMaxLiquidationBonusUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeLiquidationFeeAdditions(
    LiquidationFeeAddition[] calldata additions
  ) external {
    SpokeEngine.executeSpokeLiquidationFeeAdditions(additions);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeLiquidationFeeUpdates(LiquidationFeeUpdate[] calldata updates) external {
    SpokeEngine.executeSpokeLiquidationFeeUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeAllReservesPauses(SpokePause[] calldata pauses) external {
    SpokeEngine.executeSpokeAllReservesPauses(pauses);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeAllReservesFreezes(SpokeFreeze[] calldata freezes) external {
    SpokeEngine.executeSpokeAllReservesFreezes(freezes);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReservePauses(ReservePause[] calldata pauses) external {
    SpokeEngine.executeSpokeReservePauses(pauses);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveFreezes(ReserveFreeze[] calldata freezes) external {
    SpokeEngine.executeSpokeReserveFreezes(freezes);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokePositionManagerUpdates(PositionManagerUpdate[] calldata updates) external {
    SpokeEngine.executeSpokePositionManagerUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleGrants(RoleGrant[] calldata grants) external {
    AccessManagerEngine.executeRoleGrants(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleRevocations(RoleRevocation[] calldata revocations) external {
    AccessManagerEngine.executeRoleRevocations(revocations);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleAdminUpdates(RoleAdminUpdate[] calldata updates) external {
    AccessManagerEngine.executeRoleAdminUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleGuardianUpdates(RoleGuardianUpdate[] calldata updates) external {
    AccessManagerEngine.executeRoleGuardianUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetFunctionRoleUpdates(TargetFunctionRoleUpdate[] calldata updates) external {
    AccessManagerEngine.executeTargetFunctionRoleUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetClosedUpdates(TargetClosedUpdate[] calldata updates) external {
    AccessManagerEngine.executeTargetClosedUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleLabelUpdates(RoleLabelUpdate[] calldata updates) external {
    AccessManagerEngine.executeRoleLabelUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantDelayUpdates(GrantDelayUpdate[] calldata updates) external {
    AccessManagerEngine.executeGrantDelayUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetAdminDelayUpdates(TargetAdminDelayUpdate[] calldata updates) external {
    AccessManagerEngine.executeTargetAdminDelayUpdates(updates);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorFeeUpdaterRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorFeeUpdaterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorReinvestmentUpdaterRole(
    RoleGrantByName[] calldata grants
  ) external {
    AccessManagerEngine.executeGrantHubConfiguratorReinvestmentUpdaterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorAssetListerRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorAssetListerRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorSpokeAdderRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorSpokeAdderRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorInterestRateUpdaterRole(
    RoleGrantByName[] calldata grants
  ) external {
    AccessManagerEngine.executeGrantHubConfiguratorInterestRateUpdaterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorHalterRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorHalterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorDeactivaterRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorDeactivaterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorCapsUpdaterRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorCapsUpdaterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantHubConfiguratorAllRoles(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantHubConfiguratorAllRoles(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantSpokeConfiguratorAdminRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantSpokeConfiguratorAdminRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantSpokeConfiguratorLiquidationUpdaterRole(
    RoleGrantByName[] calldata grants
  ) external {
    AccessManagerEngine.executeGrantSpokeConfiguratorLiquidationUpdaterRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantSpokeConfiguratorReserveAdderRole(
    RoleGrantByName[] calldata grants
  ) external {
    AccessManagerEngine.executeGrantSpokeConfiguratorReserveAdderRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantSpokeConfiguratorFreezerRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantSpokeConfiguratorFreezerRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantSpokeConfiguratorPauserRole(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantSpokeConfiguratorPauserRole(grants);
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeGrantSpokeConfiguratorAllRoles(RoleGrantByName[] calldata grants) external {
    AccessManagerEngine.executeGrantSpokeConfiguratorAllRoles(grants);
  }
}
