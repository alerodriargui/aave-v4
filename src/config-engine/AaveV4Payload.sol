// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';

/// @title AaveV4Payload
/// @author Aave Labs
/// @notice Abstract base payload contract for Aave V4 governance proposals.
abstract contract AaveV4Payload {
  using Address for address;

  /// @notice The config engine used to execute payload actions via delegatecall.
  IAaveV4ConfigEngine public immutable CONFIG_ENGINE;

  /// @dev Thrown when the config engine address is zero.
  error InvalidConfigEngine();

  /// @param configEngine The IAaveV4ConfigEngine implementation to delegatecall into.
  constructor(IAaveV4ConfigEngine configEngine) {
    require(address(configEngine) != address(0), InvalidConfigEngine());
    CONFIG_ENGINE = configEngine;
  }

  /// @notice Main execution entry point called by governance. Runs all configured actions.
  /// @dev Expected to be called by a governance executor. No on-chain access control is applied;
  ///   the caller is responsible for authorization. Idempotency is not guaranteed.
  function execute() external {
    _preExecute();
    _executeHubActions();
    _executeSpokeActions();
    _executeAccessManagerActions();
    _postExecute();
  }

  /// @notice Executes all hub-related configuration actions via delegatecall to the engine.
  function _executeHubActions() internal {
    IAaveV4ConfigEngine.AssetListing[] memory listings = hubAssetListings();
    if (listings.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetListings, (listings)));
    }

    IAaveV4ConfigEngine.FeeConfigUpdate[] memory feeUpdates = hubFeeConfigUpdates();
    if (feeUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubFeeConfigUpdates, (feeUpdates))
      );
    }

    IAaveV4ConfigEngine.InterestRateUpdate[] memory irUpdates = hubInterestRateUpdates();
    if (irUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubInterestRateUpdates, (irUpdates))
      );
    }

    IAaveV4ConfigEngine.ReinvestmentControllerUpdate[]
      memory reinvestUpdates = hubReinvestmentControllerUpdates();
    if (reinvestUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeHubReinvestmentControllerUpdates,
          (reinvestUpdates)
        )
      );
    }

    IAaveV4ConfigEngine.SpokeAddition[] memory spokeAdds = hubSpokeAdditions();
    if (spokeAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeAdditions, (spokeAdds))
      );
    }

    IAaveV4ConfigEngine.SpokeToAssetsAddition[]
      memory spokeToAssetsAdds = hubSpokeToAssetsAdditions();
    if (spokeToAssetsAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeToAssetsAdditions, (spokeToAssetsAdds))
      );
    }

    IAaveV4ConfigEngine.SpokeCapsUpdate[] memory capsUpdates = hubSpokeCapsUpdates();
    if (capsUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeCapsUpdates, (capsUpdates))
      );
    }

    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[]
      memory riskUpdates = hubSpokeRiskPremiumThresholdUpdates();
    if (riskUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeHubSpokeRiskPremiumThresholdUpdates,
          (riskUpdates)
        )
      );
    }

    IAaveV4ConfigEngine.SpokeStatusUpdate[] memory statusUpdates = hubSpokeStatusUpdates();
    if (statusUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeStatusUpdates, (statusUpdates))
      );
    }

    IAaveV4ConfigEngine.AssetHalt[] memory assetHalts = hubAssetHalts();
    if (assetHalts.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetHalts, (assetHalts)));
    }

    IAaveV4ConfigEngine.AssetDeactivation[] memory assetDeactivations = hubAssetDeactivations();
    if (assetDeactivations.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetDeactivations, (assetDeactivations))
      );
    }

    IAaveV4ConfigEngine.AssetCapsReset[] memory assetCapsResets = hubAssetCapsResets();
    if (assetCapsResets.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubAssetCapsResets, (assetCapsResets))
      );
    }

    IAaveV4ConfigEngine.SpokeHalt[] memory spokeHalts = hubSpokeHalts();
    if (spokeHalts.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeHalts, (spokeHalts)));
    }

    IAaveV4ConfigEngine.SpokeDeactivation[] memory spokeDeactivations = hubSpokeDeactivations();
    if (spokeDeactivations.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeDeactivations, (spokeDeactivations))
      );
    }

    IAaveV4ConfigEngine.SpokeCapsReset[] memory spokeCapsResets = hubSpokeCapsResets();
    if (spokeCapsResets.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeHubSpokeCapsResets, (spokeCapsResets))
      );
    }
  }

  /// @notice Executes all spoke-related configuration actions via delegatecall to the engine.
  function _executeSpokeActions() internal {
    IAaveV4ConfigEngine.ReserveListing[] memory reserveListings = spokeReserveListings();
    if (reserveListings.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeReserveListings, (reserveListings))
      );
    }

    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory reserveConfigUpdates = spokeReserveConfigUpdates();
    if (reserveConfigUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeReserveConfigUpdates, (reserveConfigUpdates))
      );
    }

    IAaveV4ConfigEngine.ReservePriceSourceUpdate[]
      memory priceSourceUpdates = spokeReservePriceSourceUpdates();
    if (priceSourceUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeSpokeReservePriceSourceUpdates,
          (priceSourceUpdates)
        )
      );
    }

    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory liqConfigUpdates = spokeLiquidationConfigUpdates();
    if (liqConfigUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeLiquidationConfigUpdates, (liqConfigUpdates))
      );
    }

    IAaveV4ConfigEngine.DynamicReserveConfigAddition[]
      memory dynAdds = spokeDynamicReserveConfigAdditions();
    if (dynAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeDynamicReserveConfigAdditions, (dynAdds))
      );
    }

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory dynUpdates = spokeDynamicReserveConfigUpdates();
    if (dynUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeDynamicReserveConfigUpdates, (dynUpdates))
      );
    }

    IAaveV4ConfigEngine.CollateralFactorAddition[] memory cfAdds = spokeCollateralFactorAdditions();
    if (cfAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeCollateralFactorAdditions, (cfAdds))
      );
    }

    IAaveV4ConfigEngine.CollateralFactorUpdate[] memory cfUpdates = spokeCollateralFactorUpdates();
    if (cfUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeCollateralFactorUpdates, (cfUpdates))
      );
    }

    IAaveV4ConfigEngine.MaxLiquidationBonusAddition[]
      memory mlbAdds = spokeMaxLiquidationBonusAdditions();
    if (mlbAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeMaxLiquidationBonusAdditions, (mlbAdds))
      );
    }

    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[]
      memory mlbUpdates = spokeMaxLiquidationBonusUpdates();
    if (mlbUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeMaxLiquidationBonusUpdates, (mlbUpdates))
      );
    }

    IAaveV4ConfigEngine.LiquidationFeeAddition[] memory lfAdds = spokeLiquidationFeeAdditions();
    if (lfAdds.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeLiquidationFeeAdditions, (lfAdds))
      );
    }

    IAaveV4ConfigEngine.LiquidationFeeUpdate[] memory lfUpdates = spokeLiquidationFeeUpdates();
    if (lfUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeLiquidationFeeUpdates, (lfUpdates))
      );
    }

    IAaveV4ConfigEngine.SpokePause[] memory allPauses = spokeAllReservesPauses();
    if (allPauses.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeAllReservesPauses, (allPauses))
      );
    }

    IAaveV4ConfigEngine.SpokeFreeze[] memory allFreezes = spokeAllReservesFreezes();
    if (allFreezes.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeAllReservesFreezes, (allFreezes))
      );
    }

    IAaveV4ConfigEngine.ReservePause[] memory reservePauses = spokeReservePauses();
    if (reservePauses.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeReservePauses, (reservePauses))
      );
    }

    IAaveV4ConfigEngine.ReserveFreeze[] memory reserveFreezes = spokeReserveFreezes();
    if (reserveFreezes.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokeReserveFreezes, (reserveFreezes))
      );
    }

    IAaveV4ConfigEngine.PositionManagerUpdate[] memory pmUpdates = spokePositionManagerUpdates();
    if (pmUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeSpokePositionManagerUpdates, (pmUpdates))
      );
    }
  }

  /// @notice Executes all access manager configuration actions via delegatecall to the engine.
  function _executeAccessManagerActions() internal {
    IAaveV4ConfigEngine.RoleGrant[] memory roleGrants = accessManagerRoleGrants();
    if (roleGrants.length > 0) {
      _delegateCallEngine(abi.encodeCall(IAaveV4ConfigEngine.executeRoleGrants, (roleGrants)));
    }

    IAaveV4ConfigEngine.RoleRevocation[] memory roleRevocations = accessManagerRoleRevocations();
    if (roleRevocations.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeRoleRevocations, (roleRevocations))
      );
    }

    IAaveV4ConfigEngine.RoleAdminUpdate[] memory adminUpdates = accessManagerRoleAdminUpdates();
    if (adminUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeRoleAdminUpdates, (adminUpdates))
      );
    }

    IAaveV4ConfigEngine.RoleGuardianUpdate[]
      memory guardianUpdates = accessManagerRoleGuardianUpdates();
    if (guardianUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeRoleGuardianUpdates, (guardianUpdates))
      );
    }

    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory fnRoleUpdates = accessManagerTargetFunctionRoleUpdates();
    if (fnRoleUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeTargetFunctionRoleUpdates, (fnRoleUpdates))
      );
    }

    IAaveV4ConfigEngine.TargetClosedUpdate[]
      memory closedUpdates = accessManagerTargetClosedUpdates();
    if (closedUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeTargetClosedUpdates, (closedUpdates))
      );
    }

    IAaveV4ConfigEngine.RoleLabelUpdate[] memory labelUpdates = accessManagerRoleLabelUpdates();
    if (labelUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeRoleLabelUpdates, (labelUpdates))
      );
    }

    IAaveV4ConfigEngine.GrantDelayUpdate[]
      memory grantDelayUpdates = accessManagerGrantDelayUpdates();
    if (grantDelayUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeGrantDelayUpdates, (grantDelayUpdates))
      );
    }

    IAaveV4ConfigEngine.TargetAdminDelayUpdate[]
      memory targetDelayUpdates = accessManagerTargetAdminDelayUpdates();
    if (targetDelayUpdates.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeTargetAdminDelayUpdates, (targetDelayUpdates))
      );
    }

    // Convenience role grant methods
    IAaveV4ConfigEngine.RoleGrantByName[]
      memory feeUpdaterGrants = hubConfiguratorFeeUpdaterRoleGrants();
    if (feeUpdaterGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorFeeUpdaterRole,
          (feeUpdaterGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory reinvestGrants = hubConfiguratorReinvestmentUpdaterRoleGrants();
    if (reinvestGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorReinvestmentUpdaterRole,
          (reinvestGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory assetListerGrants = hubConfiguratorAssetListerRoleGrants();
    if (assetListerGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorAssetListerRole,
          (assetListerGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory spokeAdderGrants = hubConfiguratorSpokeAdderRoleGrants();
    if (spokeAdderGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorSpokeAdderRole,
          (spokeAdderGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory irUpdaterGrants = hubConfiguratorInterestRateUpdaterRoleGrants();
    if (irUpdaterGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorInterestRateUpdaterRole,
          (irUpdaterGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[] memory halterGrants = hubConfiguratorHalterRoleGrants();
    if (halterGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeGrantHubConfiguratorHalterRole, (halterGrants))
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory deactivaterGrants = hubConfiguratorDeactivaterRoleGrants();
    if (deactivaterGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorDeactivaterRole,
          (deactivaterGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory capsUpdaterGrants = hubConfiguratorCapsUpdaterRoleGrants();
    if (capsUpdaterGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantHubConfiguratorCapsUpdaterRole,
          (capsUpdaterGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[] memory allHubGrants = hubConfiguratorAllRoleGrants();
    if (allHubGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeGrantHubConfiguratorAllRoles, (allHubGrants))
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory spokeAdminGrants = spokeConfiguratorAdminRoleGrants();
    if (spokeAdminGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantSpokeConfiguratorAdminRole,
          (spokeAdminGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory spokeLiqGrants = spokeConfiguratorLiquidationUpdaterRoleGrants();
    if (spokeLiqGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantSpokeConfiguratorLiquidationUpdaterRole,
          (spokeLiqGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory spokeReserveAdderGrants = spokeConfiguratorReserveAdderRoleGrants();
    if (spokeReserveAdderGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantSpokeConfiguratorReserveAdderRole,
          (spokeReserveAdderGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory spokeFreezerGrants = spokeConfiguratorFreezerRoleGrants();
    if (spokeFreezerGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantSpokeConfiguratorFreezerRole,
          (spokeFreezerGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[]
      memory spokePauserGrants = spokeConfiguratorPauserRoleGrants();
    if (spokePauserGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(
          IAaveV4ConfigEngine.executeGrantSpokeConfiguratorPauserRole,
          (spokePauserGrants)
        )
      );
    }

    IAaveV4ConfigEngine.RoleGrantByName[] memory allSpokeGrants = spokeConfiguratorAllRoleGrants();
    if (allSpokeGrants.length > 0) {
      _delegateCallEngine(
        abi.encodeCall(IAaveV4ConfigEngine.executeGrantSpokeConfiguratorAllRoles, (allSpokeGrants))
      );
    }
  }

  /// @notice Delegatecalls the config engine with the given calldata.
  /// @param data The ABI-encoded function call to forward to CONFIG_ENGINE.
  function _delegateCallEngine(bytes memory data) internal {
    address(CONFIG_ENGINE).functionDelegateCall(data);
  }

  /// @notice Hook called before executing any actions. Override to add pre-execution logic.
  function _preExecute() internal virtual {}
  /// @notice Hook called after executing all actions. Override to add post-execution logic.
  function _postExecute() internal virtual {}

  /// @notice Returns the hub asset listings to execute. Override to provide listings.
  /// @return An array of AssetListing structs (empty by default).
  function hubAssetListings() internal virtual returns (IAaveV4ConfigEngine.AssetListing[] memory) {
    return new IAaveV4ConfigEngine.AssetListing[](0);
  }

  /// @notice Returns the hub fee config updates to execute. Override to provide updates.
  /// @return An array of FeeConfigUpdate structs (empty by default).
  function hubFeeConfigUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.FeeConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.FeeConfigUpdate[](0);
  }

  /// @notice Returns the hub interest rate updates to execute. Override to provide updates.
  /// @return An array of InterestRateUpdate structs (empty by default).
  function hubInterestRateUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.InterestRateUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.InterestRateUpdate[](0);
  }

  /// @notice Returns the hub reinvestment controller updates to execute. Override to provide updates.
  /// @return An array of ReinvestmentControllerUpdate structs (empty by default).
  function hubReinvestmentControllerUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.ReinvestmentControllerUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.ReinvestmentControllerUpdate[](0);
  }

  /// @notice Returns the hub spoke additions to execute. Override to provide additions.
  /// @return An array of SpokeAddition structs (empty by default).
  function hubSpokeAdditions()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeAddition[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeAddition[](0);
  }

  /// @notice Returns the hub spoke-to-assets additions to execute. Override to provide additions.
  /// @return An array of SpokeToAssetsAddition structs (empty by default).
  function hubSpokeToAssetsAdditions()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeToAssetsAddition[](0);
  }

  /// @notice Returns the hub spoke caps updates to execute. Override to provide updates.
  /// @return An array of SpokeCapsUpdate structs (empty by default).
  function hubSpokeCapsUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeCapsUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeCapsUpdate[](0);
  }

  /// @notice Returns the hub spoke risk premium threshold updates to execute. Override to provide updates.
  /// @return An array of SpokeRiskPremiumThresholdUpdate structs (empty by default).
  function hubSpokeRiskPremiumThresholdUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[](0);
  }

  /// @notice Returns the hub spoke status updates to execute. Override to provide updates.
  /// @return An array of SpokeStatusUpdate structs (empty by default).
  function hubSpokeStatusUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeStatusUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeStatusUpdate[](0);
  }

  /// @notice Returns the hub asset halts to execute. Override to provide halts.
  /// @return An array of AssetHalt structs (empty by default).
  function hubAssetHalts() internal virtual returns (IAaveV4ConfigEngine.AssetHalt[] memory) {
    return new IAaveV4ConfigEngine.AssetHalt[](0);
  }

  /// @notice Returns the hub asset deactivations to execute. Override to provide deactivations.
  /// @return An array of AssetDeactivation structs (empty by default).
  function hubAssetDeactivations()
    internal
    virtual
    returns (IAaveV4ConfigEngine.AssetDeactivation[] memory)
  {
    return new IAaveV4ConfigEngine.AssetDeactivation[](0);
  }

  /// @notice Returns the hub asset caps resets to execute. Override to provide resets.
  /// @return An array of AssetCapsReset structs (empty by default).
  function hubAssetCapsResets()
    internal
    virtual
    returns (IAaveV4ConfigEngine.AssetCapsReset[] memory)
  {
    return new IAaveV4ConfigEngine.AssetCapsReset[](0);
  }

  /// @notice Returns the hub spoke halts to execute. Override to provide halts.
  /// @return An array of SpokeHalt structs (empty by default).
  function hubSpokeHalts() internal virtual returns (IAaveV4ConfigEngine.SpokeHalt[] memory) {
    return new IAaveV4ConfigEngine.SpokeHalt[](0);
  }

  /// @notice Returns the hub spoke deactivations to execute. Override to provide deactivations.
  /// @return An array of SpokeDeactivation structs (empty by default).
  function hubSpokeDeactivations()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeDeactivation[](0);
  }

  /// @notice Returns the hub spoke caps resets to execute. Override to provide resets.
  /// @return An array of SpokeCapsReset structs (empty by default).
  function hubSpokeCapsResets()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeCapsReset[](0);
  }

  /// @notice Returns the spoke reserve listings to execute. Override to provide listings.
  /// @return An array of ReserveListing structs (empty by default).
  function spokeReserveListings()
    internal
    virtual
    returns (IAaveV4ConfigEngine.ReserveListing[] memory)
  {
    return new IAaveV4ConfigEngine.ReserveListing[](0);
  }

  /// @notice Returns the spoke reserve config updates to execute. Override to provide updates.
  /// @return An array of ReserveConfigUpdate structs (empty by default).
  function spokeReserveConfigUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.ReserveConfigUpdate[](0);
  }

  /// @notice Returns the spoke reserve price source updates to execute. Override to provide updates.
  /// @return An array of ReservePriceSourceUpdate structs (empty by default).
  function spokeReservePriceSourceUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.ReservePriceSourceUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.ReservePriceSourceUpdate[](0);
  }

  /// @notice Returns the spoke liquidation config updates to execute. Override to provide updates.
  /// @return An array of LiquidationConfigUpdate structs (empty by default).
  function spokeLiquidationConfigUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.LiquidationConfigUpdate[](0);
  }

  /// @notice Returns the spoke dynamic reserve config additions to execute. Override to provide additions.
  /// @return An array of DynamicReserveConfigAddition structs (empty by default).
  function spokeDynamicReserveConfigAdditions()
    internal
    virtual
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory)
  {
    return new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](0);
  }

  /// @notice Returns the spoke dynamic reserve config updates to execute. Override to provide updates.
  /// @return An array of DynamicReserveConfigUpdate structs (empty by default).
  function spokeDynamicReserveConfigUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](0);
  }

  /// @notice Returns the spoke collateral factor additions to execute. Override to provide additions.
  /// @return An array of CollateralFactorAddition structs (empty by default).
  function spokeCollateralFactorAdditions()
    internal
    virtual
    returns (IAaveV4ConfigEngine.CollateralFactorAddition[] memory)
  {
    return new IAaveV4ConfigEngine.CollateralFactorAddition[](0);
  }

  /// @notice Returns the spoke collateral factor updates to execute. Override to provide updates.
  /// @return An array of CollateralFactorUpdate structs (empty by default).
  function spokeCollateralFactorUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.CollateralFactorUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.CollateralFactorUpdate[](0);
  }

  /// @notice Returns the spoke max liquidation bonus additions to execute. Override to provide additions.
  /// @return An array of MaxLiquidationBonusAddition structs (empty by default).
  function spokeMaxLiquidationBonusAdditions()
    internal
    virtual
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] memory)
  {
    return new IAaveV4ConfigEngine.MaxLiquidationBonusAddition[](0);
  }

  /// @notice Returns the spoke max liquidation bonus updates to execute. Override to provide updates.
  /// @return An array of MaxLiquidationBonusUpdate structs (empty by default).
  function spokeMaxLiquidationBonusUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[](0);
  }

  /// @notice Returns the spoke liquidation fee additions to execute. Override to provide additions.
  /// @return An array of LiquidationFeeAddition structs (empty by default).
  function spokeLiquidationFeeAdditions()
    internal
    virtual
    returns (IAaveV4ConfigEngine.LiquidationFeeAddition[] memory)
  {
    return new IAaveV4ConfigEngine.LiquidationFeeAddition[](0);
  }

  /// @notice Returns the spoke liquidation fee updates to execute. Override to provide updates.
  /// @return An array of LiquidationFeeUpdate structs (empty by default).
  function spokeLiquidationFeeUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.LiquidationFeeUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.LiquidationFeeUpdate[](0);
  }

  /// @notice Returns the spoke all-reserves pauses to execute. Override to provide pauses.
  /// @return An array of SpokePause structs (empty by default).
  function spokeAllReservesPauses()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokePause[] memory)
  {
    return new IAaveV4ConfigEngine.SpokePause[](0);
  }

  /// @notice Returns the spoke all-reserves freezes to execute. Override to provide freezes.
  /// @return An array of SpokeFreeze structs (empty by default).
  function spokeAllReservesFreezes()
    internal
    virtual
    returns (IAaveV4ConfigEngine.SpokeFreeze[] memory)
  {
    return new IAaveV4ConfigEngine.SpokeFreeze[](0);
  }

  /// @notice Returns the spoke reserve pauses to execute. Override to provide pauses.
  /// @return An array of ReservePause structs (empty by default).
  function spokeReservePauses()
    internal
    virtual
    returns (IAaveV4ConfigEngine.ReservePause[] memory)
  {
    return new IAaveV4ConfigEngine.ReservePause[](0);
  }

  /// @notice Returns the spoke reserve freezes to execute. Override to provide freezes.
  /// @return An array of ReserveFreeze structs (empty by default).
  function spokeReserveFreezes()
    internal
    virtual
    returns (IAaveV4ConfigEngine.ReserveFreeze[] memory)
  {
    return new IAaveV4ConfigEngine.ReserveFreeze[](0);
  }

  /// @notice Returns the spoke position manager updates to execute. Override to provide updates.
  /// @return An array of PositionManagerUpdate structs (empty by default).
  function spokePositionManagerUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.PositionManagerUpdate[](0);
  }

  /// @notice Returns the access manager role grants to execute. Override to provide grants.
  /// @return An array of RoleGrant structs (empty by default).
  function accessManagerRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrant[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrant[](0);
  }

  /// @notice Returns the access manager role revocations to execute. Override to provide revocations.
  /// @return An array of RoleRevocation structs (empty by default).
  function accessManagerRoleRevocations()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleRevocation[] memory)
  {
    return new IAaveV4ConfigEngine.RoleRevocation[](0);
  }

  /// @notice Returns the access manager role admin updates to execute. Override to provide updates.
  /// @return An array of RoleAdminUpdate structs (empty by default).
  function accessManagerRoleAdminUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleAdminUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.RoleAdminUpdate[](0);
  }

  /// @notice Returns the access manager role guardian updates to execute. Override to provide updates.
  /// @return An array of RoleGuardianUpdate structs (empty by default).
  function accessManagerRoleGuardianUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGuardianUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGuardianUpdate[](0);
  }

  /// @notice Returns the access manager target function role updates to execute. Override to provide updates.
  /// @return An array of TargetFunctionRoleUpdate structs (empty by default).
  function accessManagerTargetFunctionRoleUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](0);
  }

  /// @notice Returns the access manager target closed updates to execute. Override to provide updates.
  /// @return An array of TargetClosedUpdate structs (empty by default).
  function accessManagerTargetClosedUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.TargetClosedUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.TargetClosedUpdate[](0);
  }

  /// @notice Returns the access manager role label updates to execute. Override to provide updates.
  /// @return An array of RoleLabelUpdate structs (empty by default).
  function accessManagerRoleLabelUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleLabelUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.RoleLabelUpdate[](0);
  }

  /// @notice Returns the access manager grant delay updates to execute. Override to provide updates.
  /// @return An array of GrantDelayUpdate structs (empty by default).
  function accessManagerGrantDelayUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.GrantDelayUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.GrantDelayUpdate[](0);
  }

  /// @notice Returns the access manager target admin delay updates to execute. Override to provide updates.
  /// @return An array of TargetAdminDelayUpdate structs (empty by default).
  function accessManagerTargetAdminDelayUpdates()
    internal
    virtual
    returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory)
  {
    return new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](0);
  }

  /// @notice Returns the HubConfigurator fee updater role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorFeeUpdaterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator reinvestment updater role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorReinvestmentUpdaterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator asset lister role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorAssetListerRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator spoke adder role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorSpokeAdderRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator interest rate updater role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorInterestRateUpdaterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator halter role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorHalterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator deactivater role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorDeactivaterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator caps updater role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorCapsUpdaterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the HubConfigurator all-roles grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function hubConfiguratorAllRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the SpokeConfigurator admin role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function spokeConfiguratorAdminRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the SpokeConfigurator liquidation updater role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function spokeConfiguratorLiquidationUpdaterRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the SpokeConfigurator reserve adder role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function spokeConfiguratorReserveAdderRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the SpokeConfigurator freezer role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function spokeConfiguratorFreezerRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the SpokeConfigurator pauser role grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function spokeConfiguratorPauserRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }

  /// @notice Returns the SpokeConfigurator all-roles grants to execute. Override to provide grants.
  /// @return An array of RoleGrantByName structs (empty by default).
  function spokeConfiguratorAllRoleGrants()
    internal
    virtual
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    return new IAaveV4ConfigEngine.RoleGrantByName[](0);
  }
}
