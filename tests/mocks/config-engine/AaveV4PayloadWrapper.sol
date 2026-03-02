// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

contract AaveV4PayloadWrapper is AaveV4Payload {
  bool public constant IS_TEST = true;

  // Hook tracking
  bool public preExecuteCalled;
  bool public postExecuteCalled;
  uint256 public preExecuteOrder;
  uint256 public postExecuteOrder;
  uint256 private _callCounter;

  // Hub action storage
  IAaveV4ConfigEngine.AssetListing[] private _hubAssetListings;
  IAaveV4ConfigEngine.FeeConfigUpdate[] private _hubFeeConfigUpdates;
  IAaveV4ConfigEngine.InterestRateUpdate[] private _hubInterestRateUpdates;
  IAaveV4ConfigEngine.ReinvestmentControllerUpdate[] private _hubReinvestmentControllerUpdates;
  IAaveV4ConfigEngine.SpokeAddition[] private _hubSpokeAdditions;
  bytes private _hubSpokeToAssetsAdditionsEncoded;
  IAaveV4ConfigEngine.SpokeCapsUpdate[] private _hubSpokeCapsUpdates;
  IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[]
    private _hubSpokeRiskPremiumThresholdUpdates;
  IAaveV4ConfigEngine.SpokeStatusUpdate[] private _hubSpokeStatusUpdates;
  IAaveV4ConfigEngine.AssetHalt[] private _hubAssetHalts;
  IAaveV4ConfigEngine.AssetDeactivation[] private _hubAssetDeactivations;
  IAaveV4ConfigEngine.AssetCapsReset[] private _hubAssetCapsResets;
  IAaveV4ConfigEngine.SpokeHalt[] private _hubSpokeHalts;
  IAaveV4ConfigEngine.SpokeDeactivation[] private _hubSpokeDeactivations;
  IAaveV4ConfigEngine.SpokeCapsReset[] private _hubSpokeCapsResets;

  // Spoke action storage
  IAaveV4ConfigEngine.ReserveListing[] private _spokeReserveListings;
  IAaveV4ConfigEngine.ReserveConfigUpdate[] private _spokeReserveConfigUpdates;
  IAaveV4ConfigEngine.ReservePriceSourceUpdate[] private _spokeReservePriceSourceUpdates;
  IAaveV4ConfigEngine.LiquidationConfigUpdate[] private _spokeLiquidationConfigUpdates;
  IAaveV4ConfigEngine.DynamicReserveConfigAddition[] private _spokeDynamicReserveConfigAdditions;
  IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] private _spokeDynamicReserveConfigUpdates;
  IAaveV4ConfigEngine.CollateralFactorAddition[] private _spokeCollateralFactorAdditions;
  IAaveV4ConfigEngine.CollateralFactorUpdate[] private _spokeCollateralFactorUpdates;
  IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] private _spokeMaxLiquidationBonusAdditions;
  IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] private _spokeMaxLiquidationBonusUpdates;
  IAaveV4ConfigEngine.LiquidationFeeAddition[] private _spokeLiquidationFeeAdditions;
  IAaveV4ConfigEngine.LiquidationFeeUpdate[] private _spokeLiquidationFeeUpdates;
  IAaveV4ConfigEngine.SpokePause[] private _spokeAllReservesPauses;
  IAaveV4ConfigEngine.SpokeFreeze[] private _spokeAllReservesFreezes;
  IAaveV4ConfigEngine.ReservePause[] private _spokeReservePauses;
  IAaveV4ConfigEngine.ReserveFreeze[] private _spokeReserveFreezes;
  IAaveV4ConfigEngine.PositionManagerUpdate[] private _spokePositionManagerUpdates;

  // Position manager action storage
  IAaveV4ConfigEngine.SpokeRegistration[] private _positionManagerSpokeRegistrations;
  IAaveV4ConfigEngine.TokenRescue[] private _positionManagerTokenRescues;
  IAaveV4ConfigEngine.NativeRescue[] private _positionManagerNativeRescues;
  IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] private _positionManagerRoleRenouncements;

  // Access manager action storage
  IAaveV4ConfigEngine.RoleGrant[] private _accessManagerRoleGrants;
  IAaveV4ConfigEngine.RoleRevocation[] private _accessManagerRoleRevocations;
  IAaveV4ConfigEngine.RoleAdminUpdate[] private _accessManagerRoleAdminUpdates;
  IAaveV4ConfigEngine.RoleGuardianUpdate[] private _accessManagerRoleGuardianUpdates;
  IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] private _accessManagerTargetFunctionRoleUpdates;
  IAaveV4ConfigEngine.TargetClosedUpdate[] private _accessManagerTargetClosedUpdates;
  IAaveV4ConfigEngine.RoleLabelUpdate[] private _accessManagerRoleLabelUpdates;
  IAaveV4ConfigEngine.GrantDelayUpdate[] private _accessManagerGrantDelayUpdates;
  IAaveV4ConfigEngine.TargetAdminDelayUpdate[] private _accessManagerTargetAdminDelayUpdates;

  // Convenience role grant storage
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorFeeUpdaterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorReinvestmentUpdaterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorAssetListerRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorSpokeAdderRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorInterestRateUpdaterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorHalterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorDeactivaterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorCapsUpdaterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _hubConfiguratorAllRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _spokeConfiguratorAdminRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _spokeConfiguratorLiquidationUpdaterRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _spokeConfiguratorReserveAdderRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _spokeConfiguratorFreezerRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _spokeConfiguratorPauserRoleGrants;
  IAaveV4ConfigEngine.RoleGrantByName[] private _spokeConfiguratorAllRoleGrants;

  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

  // Hook overrides
  function _preExecute() internal override {
    preExecuteCalled = true;
    preExecuteOrder = ++_callCounter;
  }

  function _postExecute() internal override {
    postExecuteCalled = true;
    postExecuteOrder = ++_callCounter;
  }

  // Hub setters
  function setHubAssetListings(IAaveV4ConfigEngine.AssetListing[] memory items) external {
    delete _hubAssetListings;
    for (uint256 i = 0; i < items.length; i++) _hubAssetListings.push(items[i]);
  }

  function setHubFeeConfigUpdates(IAaveV4ConfigEngine.FeeConfigUpdate[] memory items) external {
    delete _hubFeeConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) _hubFeeConfigUpdates.push(items[i]);
  }

  function setHubInterestRateUpdates(
    IAaveV4ConfigEngine.InterestRateUpdate[] memory items
  ) external {
    delete _hubInterestRateUpdates;
    for (uint256 i = 0; i < items.length; i++) _hubInterestRateUpdates.push(items[i]);
  }

  function setHubReinvestmentControllerUpdates(
    IAaveV4ConfigEngine.ReinvestmentControllerUpdate[] memory items
  ) external {
    delete _hubReinvestmentControllerUpdates;
    for (uint256 i = 0; i < items.length; i++) _hubReinvestmentControllerUpdates.push(items[i]);
  }

  function setHubSpokeAdditions(IAaveV4ConfigEngine.SpokeAddition[] memory items) external {
    delete _hubSpokeAdditions;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeAdditions.push(items[i]);
  }

  function setHubSpokeToAssetsAdditions(
    IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory items
  ) external {
    _hubSpokeToAssetsAdditionsEncoded = abi.encode(items);
  }

  function setHubSpokeCapsUpdates(IAaveV4ConfigEngine.SpokeCapsUpdate[] memory items) external {
    delete _hubSpokeCapsUpdates;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeCapsUpdates.push(items[i]);
  }

  function setHubSpokeRiskPremiumThresholdUpdates(
    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[] memory items
  ) external {
    delete _hubSpokeRiskPremiumThresholdUpdates;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeRiskPremiumThresholdUpdates.push(items[i]);
  }

  function setHubSpokeStatusUpdates(IAaveV4ConfigEngine.SpokeStatusUpdate[] memory items) external {
    delete _hubSpokeStatusUpdates;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeStatusUpdates.push(items[i]);
  }

  function setHubAssetHalts(IAaveV4ConfigEngine.AssetHalt[] memory items) external {
    delete _hubAssetHalts;
    for (uint256 i = 0; i < items.length; i++) _hubAssetHalts.push(items[i]);
  }

  function setHubAssetDeactivations(IAaveV4ConfigEngine.AssetDeactivation[] memory items) external {
    delete _hubAssetDeactivations;
    for (uint256 i = 0; i < items.length; i++) _hubAssetDeactivations.push(items[i]);
  }

  function setHubAssetCapsResets(IAaveV4ConfigEngine.AssetCapsReset[] memory items) external {
    delete _hubAssetCapsResets;
    for (uint256 i = 0; i < items.length; i++) _hubAssetCapsResets.push(items[i]);
  }

  function setHubSpokeHalts(IAaveV4ConfigEngine.SpokeHalt[] memory items) external {
    delete _hubSpokeHalts;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeHalts.push(items[i]);
  }

  function setHubSpokeDeactivations(IAaveV4ConfigEngine.SpokeDeactivation[] memory items) external {
    delete _hubSpokeDeactivations;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeDeactivations.push(items[i]);
  }

  function setHubSpokeCapsResets(IAaveV4ConfigEngine.SpokeCapsReset[] memory items) external {
    delete _hubSpokeCapsResets;
    for (uint256 i = 0; i < items.length; i++) _hubSpokeCapsResets.push(items[i]);
  }

  // Spoke setters
  function setSpokeReserveListings(IAaveV4ConfigEngine.ReserveListing[] memory items) external {
    delete _spokeReserveListings;
    for (uint256 i = 0; i < items.length; i++) _spokeReserveListings.push(items[i]);
  }

  function setSpokeReserveConfigUpdates(
    IAaveV4ConfigEngine.ReserveConfigUpdate[] memory items
  ) external {
    delete _spokeReserveConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeReserveConfigUpdates.push(items[i]);
  }

  function setSpokeReservePriceSourceUpdates(
    IAaveV4ConfigEngine.ReservePriceSourceUpdate[] memory items
  ) external {
    delete _spokeReservePriceSourceUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeReservePriceSourceUpdates.push(items[i]);
  }

  function setSpokeLiquidationConfigUpdates(
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory items
  ) external {
    delete _spokeLiquidationConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeLiquidationConfigUpdates.push(items[i]);
  }

  function setSpokeDynamicReserveConfigAdditions(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory items
  ) external {
    delete _spokeDynamicReserveConfigAdditions;
    for (uint256 i = 0; i < items.length; i++) _spokeDynamicReserveConfigAdditions.push(items[i]);
  }

  function setSpokeDynamicReserveConfigUpdates(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory items
  ) external {
    delete _spokeDynamicReserveConfigUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeDynamicReserveConfigUpdates.push(items[i]);
  }

  function setSpokeCollateralFactorAdditions(
    IAaveV4ConfigEngine.CollateralFactorAddition[] memory items
  ) external {
    delete _spokeCollateralFactorAdditions;
    for (uint256 i = 0; i < items.length; i++) _spokeCollateralFactorAdditions.push(items[i]);
  }

  function setSpokeCollateralFactorUpdates(
    IAaveV4ConfigEngine.CollateralFactorUpdate[] memory items
  ) external {
    delete _spokeCollateralFactorUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeCollateralFactorUpdates.push(items[i]);
  }

  function setSpokeMaxLiquidationBonusAdditions(
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] memory items
  ) external {
    delete _spokeMaxLiquidationBonusAdditions;
    for (uint256 i = 0; i < items.length; i++) _spokeMaxLiquidationBonusAdditions.push(items[i]);
  }

  function setSpokeMaxLiquidationBonusUpdates(
    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] memory items
  ) external {
    delete _spokeMaxLiquidationBonusUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeMaxLiquidationBonusUpdates.push(items[i]);
  }

  function setSpokeLiquidationFeeAdditions(
    IAaveV4ConfigEngine.LiquidationFeeAddition[] memory items
  ) external {
    delete _spokeLiquidationFeeAdditions;
    for (uint256 i = 0; i < items.length; i++) _spokeLiquidationFeeAdditions.push(items[i]);
  }

  function setSpokeLiquidationFeeUpdates(
    IAaveV4ConfigEngine.LiquidationFeeUpdate[] memory items
  ) external {
    delete _spokeLiquidationFeeUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokeLiquidationFeeUpdates.push(items[i]);
  }

  function setSpokeAllReservesPauses(IAaveV4ConfigEngine.SpokePause[] memory items) external {
    delete _spokeAllReservesPauses;
    for (uint256 i = 0; i < items.length; i++) _spokeAllReservesPauses.push(items[i]);
  }

  function setSpokeAllReservesFreezes(IAaveV4ConfigEngine.SpokeFreeze[] memory items) external {
    delete _spokeAllReservesFreezes;
    for (uint256 i = 0; i < items.length; i++) _spokeAllReservesFreezes.push(items[i]);
  }

  function setSpokeReservePauses(IAaveV4ConfigEngine.ReservePause[] memory items) external {
    delete _spokeReservePauses;
    for (uint256 i = 0; i < items.length; i++) _spokeReservePauses.push(items[i]);
  }

  function setSpokeReserveFreezes(IAaveV4ConfigEngine.ReserveFreeze[] memory items) external {
    delete _spokeReserveFreezes;
    for (uint256 i = 0; i < items.length; i++) _spokeReserveFreezes.push(items[i]);
  }

  function setSpokePositionManagerUpdates(
    IAaveV4ConfigEngine.PositionManagerUpdate[] memory items
  ) external {
    delete _spokePositionManagerUpdates;
    for (uint256 i = 0; i < items.length; i++) _spokePositionManagerUpdates.push(items[i]);
  }

  // Position manager setters
  function setPositionManagerSpokeRegistrations(
    IAaveV4ConfigEngine.SpokeRegistration[] memory items
  ) external {
    delete _positionManagerSpokeRegistrations;
    for (uint256 i = 0; i < items.length; i++) _positionManagerSpokeRegistrations.push(items[i]);
  }

  function setPositionManagerTokenRescues(IAaveV4ConfigEngine.TokenRescue[] memory items) external {
    delete _positionManagerTokenRescues;
    for (uint256 i = 0; i < items.length; i++) _positionManagerTokenRescues.push(items[i]);
  }

  function setPositionManagerNativeRescues(
    IAaveV4ConfigEngine.NativeRescue[] memory items
  ) external {
    delete _positionManagerNativeRescues;
    for (uint256 i = 0; i < items.length; i++) _positionManagerNativeRescues.push(items[i]);
  }

  function setPositionManagerRoleRenouncements(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory items
  ) external {
    delete _positionManagerRoleRenouncements;
    for (uint256 i = 0; i < items.length; i++) _positionManagerRoleRenouncements.push(items[i]);
  }

  // Access manager setters
  function setAccessManagerRoleGrants(IAaveV4ConfigEngine.RoleGrant[] memory items) external {
    delete _accessManagerRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _accessManagerRoleGrants.push(items[i]);
  }

  function setAccessManagerRoleRevocations(
    IAaveV4ConfigEngine.RoleRevocation[] memory items
  ) external {
    delete _accessManagerRoleRevocations;
    for (uint256 i = 0; i < items.length; i++) _accessManagerRoleRevocations.push(items[i]);
  }

  function setAccessManagerRoleAdminUpdates(
    IAaveV4ConfigEngine.RoleAdminUpdate[] memory items
  ) external {
    delete _accessManagerRoleAdminUpdates;
    for (uint256 i = 0; i < items.length; i++) _accessManagerRoleAdminUpdates.push(items[i]);
  }

  function setAccessManagerRoleGuardianUpdates(
    IAaveV4ConfigEngine.RoleGuardianUpdate[] memory items
  ) external {
    delete _accessManagerRoleGuardianUpdates;
    for (uint256 i = 0; i < items.length; i++) _accessManagerRoleGuardianUpdates.push(items[i]);
  }

  function setAccessManagerTargetFunctionRoleUpdates(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory items
  ) external {
    delete _accessManagerTargetFunctionRoleUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _accessManagerTargetFunctionRoleUpdates.push(items[i]);
    }
  }

  function setAccessManagerTargetClosedUpdates(
    IAaveV4ConfigEngine.TargetClosedUpdate[] memory items
  ) external {
    delete _accessManagerTargetClosedUpdates;
    for (uint256 i = 0; i < items.length; i++) _accessManagerTargetClosedUpdates.push(items[i]);
  }

  function setAccessManagerRoleLabelUpdates(
    IAaveV4ConfigEngine.RoleLabelUpdate[] memory items
  ) external {
    delete _accessManagerRoleLabelUpdates;
    for (uint256 i = 0; i < items.length; i++) _accessManagerRoleLabelUpdates.push(items[i]);
  }

  function setAccessManagerGrantDelayUpdates(
    IAaveV4ConfigEngine.GrantDelayUpdate[] memory items
  ) external {
    delete _accessManagerGrantDelayUpdates;
    for (uint256 i = 0; i < items.length; i++) _accessManagerGrantDelayUpdates.push(items[i]);
  }

  function setAccessManagerTargetAdminDelayUpdates(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory items
  ) external {
    delete _accessManagerTargetAdminDelayUpdates;
    for (uint256 i = 0; i < items.length; i++) {
      _accessManagerTargetAdminDelayUpdates.push(items[i]);
    }
  }

  // Convenience role grant setters
  function setHubConfiguratorFeeUpdaterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorFeeUpdaterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _hubConfiguratorFeeUpdaterRoleGrants.push(items[i]);
  }

  function setHubConfiguratorReinvestmentUpdaterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorReinvestmentUpdaterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _hubConfiguratorReinvestmentUpdaterRoleGrants.push(items[i]);
    }
  }

  function setHubConfiguratorAssetListerRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorAssetListerRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _hubConfiguratorAssetListerRoleGrants.push(items[i]);
    }
  }

  function setHubConfiguratorSpokeAdderRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorSpokeAdderRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _hubConfiguratorSpokeAdderRoleGrants.push(items[i]);
    }
  }

  function setHubConfiguratorInterestRateUpdaterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorInterestRateUpdaterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _hubConfiguratorInterestRateUpdaterRoleGrants.push(items[i]);
    }
  }

  function setHubConfiguratorHalterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorHalterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _hubConfiguratorHalterRoleGrants.push(items[i]);
  }

  function setHubConfiguratorDeactivaterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorDeactivaterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _hubConfiguratorDeactivaterRoleGrants.push(items[i]);
    }
  }

  function setHubConfiguratorCapsUpdaterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorCapsUpdaterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _hubConfiguratorCapsUpdaterRoleGrants.push(items[i]);
    }
  }

  function setHubConfiguratorAllRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _hubConfiguratorAllRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _hubConfiguratorAllRoleGrants.push(items[i]);
  }

  function setSpokeConfiguratorAdminRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _spokeConfiguratorAdminRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _spokeConfiguratorAdminRoleGrants.push(items[i]);
  }

  function setSpokeConfiguratorLiquidationUpdaterRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _spokeConfiguratorLiquidationUpdaterRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeConfiguratorLiquidationUpdaterRoleGrants.push(items[i]);
    }
  }

  function setSpokeConfiguratorReserveAdderRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _spokeConfiguratorReserveAdderRoleGrants;
    for (uint256 i = 0; i < items.length; i++) {
      _spokeConfiguratorReserveAdderRoleGrants.push(items[i]);
    }
  }

  function setSpokeConfiguratorFreezerRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _spokeConfiguratorFreezerRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _spokeConfiguratorFreezerRoleGrants.push(items[i]);
  }

  function setSpokeConfiguratorPauserRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _spokeConfiguratorPauserRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _spokeConfiguratorPauserRoleGrants.push(items[i]);
  }

  function setSpokeConfiguratorAllRoleGrants(
    IAaveV4ConfigEngine.RoleGrantByName[] memory items
  ) external {
    delete _spokeConfiguratorAllRoleGrants;
    for (uint256 i = 0; i < items.length; i++) _spokeConfiguratorAllRoleGrants.push(items[i]);
  }

  function hubAssetListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetListing[] memory)
  {
    return _hubAssetListings;
  }

  function hubFeeConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.FeeConfigUpdate[] memory)
  {
    return _hubFeeConfigUpdates;
  }

  function hubInterestRateUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.InterestRateUpdate[] memory)
  {
    return _hubInterestRateUpdates;
  }

  function hubReinvestmentControllerUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReinvestmentControllerUpdate[] memory)
  {
    return _hubReinvestmentControllerUpdates;
  }

  function hubSpokeAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeAddition[] memory)
  {
    return _hubSpokeAdditions;
  }

  function hubSpokeToAssetsAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory)
  {
    if (_hubSpokeToAssetsAdditionsEncoded.length == 0) {
      return new IAaveV4ConfigEngine.SpokeToAssetsAddition[](0);
    }
    return
      abi.decode(_hubSpokeToAssetsAdditionsEncoded, (IAaveV4ConfigEngine.SpokeToAssetsAddition[]));
  }

  function hubSpokeCapsUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeCapsUpdate[] memory)
  {
    return _hubSpokeCapsUpdates;
  }

  function hubSpokeRiskPremiumThresholdUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[] memory)
  {
    return _hubSpokeRiskPremiumThresholdUpdates;
  }

  function hubSpokeStatusUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeStatusUpdate[] memory)
  {
    return _hubSpokeStatusUpdates;
  }

  function hubAssetHalts() public view override returns (IAaveV4ConfigEngine.AssetHalt[] memory) {
    return _hubAssetHalts;
  }

  function hubAssetDeactivations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetDeactivation[] memory)
  {
    return _hubAssetDeactivations;
  }

  function hubAssetCapsResets()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetCapsReset[] memory)
  {
    return _hubAssetCapsResets;
  }

  function hubSpokeHalts() public view override returns (IAaveV4ConfigEngine.SpokeHalt[] memory) {
    return _hubSpokeHalts;
  }

  function hubSpokeDeactivations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory)
  {
    return _hubSpokeDeactivations;
  }

  function hubSpokeCapsResets()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory)
  {
    return _hubSpokeCapsResets;
  }

  function spokeReserveListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveListing[] memory)
  {
    return _spokeReserveListings;
  }

  function spokeReserveConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory)
  {
    return _spokeReserveConfigUpdates;
  }

  function spokeReservePriceSourceUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReservePriceSourceUpdate[] memory)
  {
    return _spokeReservePriceSourceUpdates;
  }

  function spokeLiquidationConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory)
  {
    return _spokeLiquidationConfigUpdates;
  }

  function spokeDynamicReserveConfigAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory)
  {
    return _spokeDynamicReserveConfigAdditions;
  }

  function spokeDynamicReserveConfigUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory)
  {
    return _spokeDynamicReserveConfigUpdates;
  }

  function spokeCollateralFactorAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.CollateralFactorAddition[] memory)
  {
    return _spokeCollateralFactorAdditions;
  }

  function spokeCollateralFactorUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.CollateralFactorUpdate[] memory)
  {
    return _spokeCollateralFactorUpdates;
  }

  function spokeMaxLiquidationBonusAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] memory)
  {
    return _spokeMaxLiquidationBonusAdditions;
  }

  function spokeMaxLiquidationBonusUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] memory)
  {
    return _spokeMaxLiquidationBonusUpdates;
  }

  function spokeLiquidationFeeAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.LiquidationFeeAddition[] memory)
  {
    return _spokeLiquidationFeeAdditions;
  }

  function spokeLiquidationFeeUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.LiquidationFeeUpdate[] memory)
  {
    return _spokeLiquidationFeeUpdates;
  }

  function spokeAllReservesPauses()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokePause[] memory)
  {
    return _spokeAllReservesPauses;
  }

  function spokeAllReservesFreezes()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeFreeze[] memory)
  {
    return _spokeAllReservesFreezes;
  }

  function spokeReservePauses()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReservePause[] memory)
  {
    return _spokeReservePauses;
  }

  function spokeReserveFreezes()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveFreeze[] memory)
  {
    return _spokeReserveFreezes;
  }

  function spokePositionManagerUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory)
  {
    return _spokePositionManagerUpdates;
  }

  function accessManagerRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrant[] memory)
  {
    return _accessManagerRoleGrants;
  }

  function accessManagerRoleRevocations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleRevocation[] memory)
  {
    return _accessManagerRoleRevocations;
  }

  function accessManagerRoleAdminUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleAdminUpdate[] memory)
  {
    return _accessManagerRoleAdminUpdates;
  }

  function accessManagerRoleGuardianUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGuardianUpdate[] memory)
  {
    return _accessManagerRoleGuardianUpdates;
  }

  function accessManagerTargetFunctionRoleUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory)
  {
    return _accessManagerTargetFunctionRoleUpdates;
  }

  function accessManagerTargetClosedUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetClosedUpdate[] memory)
  {
    return _accessManagerTargetClosedUpdates;
  }

  function accessManagerRoleLabelUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleLabelUpdate[] memory)
  {
    return _accessManagerRoleLabelUpdates;
  }

  function accessManagerGrantDelayUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.GrantDelayUpdate[] memory)
  {
    return _accessManagerGrantDelayUpdates;
  }

  function accessManagerTargetAdminDelayUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory)
  {
    return _accessManagerTargetAdminDelayUpdates;
  }

  function hubConfiguratorFeeUpdaterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorFeeUpdaterRoleGrants;
  }

  function hubConfiguratorReinvestmentUpdaterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorReinvestmentUpdaterRoleGrants;
  }

  function hubConfiguratorAssetListerRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorAssetListerRoleGrants;
  }

  function hubConfiguratorSpokeAdderRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorSpokeAdderRoleGrants;
  }

  function hubConfiguratorInterestRateUpdaterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorInterestRateUpdaterRoleGrants;
  }

  function hubConfiguratorHalterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorHalterRoleGrants;
  }

  function hubConfiguratorDeactivaterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorDeactivaterRoleGrants;
  }

  function hubConfiguratorCapsUpdaterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorCapsUpdaterRoleGrants;
  }

  function hubConfiguratorAllRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _hubConfiguratorAllRoleGrants;
  }

  function spokeConfiguratorAdminRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _spokeConfiguratorAdminRoleGrants;
  }

  function spokeConfiguratorLiquidationUpdaterRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _spokeConfiguratorLiquidationUpdaterRoleGrants;
  }

  function spokeConfiguratorReserveAdderRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _spokeConfiguratorReserveAdderRoleGrants;
  }

  function spokeConfiguratorFreezerRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _spokeConfiguratorFreezerRoleGrants;
  }

  function spokeConfiguratorPauserRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _spokeConfiguratorPauserRoleGrants;
  }

  function spokeConfiguratorAllRoleGrants()
    public
    view
    override
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return _spokeConfiguratorAllRoleGrants;
  }

  function positionManagerSpokeRegistrations()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeRegistration[] memory)
  {
    return _positionManagerSpokeRegistrations;
  }

  function positionManagerTokenRescues()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TokenRescue[] memory)
  {
    return _positionManagerTokenRescues;
  }

  function positionManagerNativeRescues()
    public
    view
    override
    returns (IAaveV4ConfigEngine.NativeRescue[] memory)
  {
    return _positionManagerNativeRescues;
  }

  function positionManagerRoleRenouncements()
    public
    view
    override
    returns (IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory)
  {
    return _positionManagerRoleRenouncements;
  }
}
