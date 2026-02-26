// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/EngineFlags.sol';

/// @title HubEngine
/// @author Aave Labs
/// @notice Library containing hub configurator logic for AaveV4ConfigEngine.
library HubEngine {
  /// @notice Lists new assets on hubs via the HubConfigurator.
  /// @param listings The asset listings to execute.
  function executeHubAssetListings(IAaveV4ConfigEngine.AssetListing[] calldata listings) external {
    uint256 length = listings.length;
    for (uint256 i; i < length; ++i) {
      if (listings[i].decimals == 0) {
        listings[i].hubConfigurator.addAsset(
          listings[i].hub,
          listings[i].underlying,
          listings[i].feeReceiver,
          listings[i].liquidityFee,
          listings[i].irStrategy,
          listings[i].irData
        );
      } else {
        listings[i].hubConfigurator.addAssetWithDecimals(
          listings[i].hub,
          listings[i].underlying,
          uint8(listings[i].decimals),
          listings[i].feeReceiver,
          listings[i].liquidityFee,
          listings[i].irStrategy,
          listings[i].irData
        );
      }
    }
  }

  /// @notice Updates fee config for assets on hubs.
  /// @dev If both liquidityFee and feeReceiver are set, calls updateFeeConfig.
  ///   If only liquidityFee is set, calls updateLiquidityFee.
  ///   If only feeReceiver is set, calls updateFeeReceiver.
  ///   If neither is set, the update is skipped.
  /// @param updates The fee config updates to execute.
  function executeHubFeeConfigUpdates(
    IAaveV4ConfigEngine.FeeConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      bool updateFee = updates[i].liquidityFee != EngineFlags.KEEP_CURRENT;
      bool updateReceiver = updates[i].feeReceiver != EngineFlags.KEEP_CURRENT_ADDRESS;

      if (updateFee && updateReceiver) {
        updates[i].hubConfigurator.updateFeeConfig(
          updates[i].hub,
          updates[i].assetId,
          updates[i].liquidityFee,
          updates[i].feeReceiver
        );
      } else if (updateFee) {
        updates[i].hubConfigurator.updateLiquidityFee(
          updates[i].hub,
          updates[i].assetId,
          updates[i].liquidityFee
        );
      } else if (updateReceiver) {
        updates[i].hubConfigurator.updateFeeReceiver(
          updates[i].hub,
          updates[i].assetId,
          updates[i].feeReceiver
        );
      }
    }
  }

  /// @notice Updates interest rate config for assets on hubs.
  /// @dev If irStrategy differs from KEEP_CURRENT_ADDRESS, calls updateInterestRateStrategy
  ///   (which also sets new irData). If irStrategy is kept but irData is provided,
  ///   calls updateInterestRateData to update data only. If neither applies, the update is skipped.
  /// @param updates The interest rate updates to execute.
  function executeHubInterestRateUpdates(
    IAaveV4ConfigEngine.InterestRateUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      if (updates[i].irStrategy != EngineFlags.KEEP_CURRENT_ADDRESS) {
        updates[i].hubConfigurator.updateInterestRateStrategy(
          updates[i].hub,
          updates[i].assetId,
          updates[i].irStrategy,
          updates[i].irData
        );
      } else if (updates[i].irData.length > 0) {
        updates[i].hubConfigurator.updateInterestRateData(
          updates[i].hub,
          updates[i].assetId,
          updates[i].irData
        );
      }
    }
  }

  /// @notice Updates reinvestment controllers for assets on hubs.
  /// @param updates The reinvestment controller updates to execute.
  function executeHubReinvestmentControllerUpdates(
    IAaveV4ConfigEngine.ReinvestmentControllerUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].hubConfigurator.updateReinvestmentController(
        updates[i].hub,
        updates[i].assetId,
        updates[i].reinvestmentController
      );
    }
  }

  /// @notice Adds spokes to hubs for specific assets.
  /// @param additions The spoke additions to execute.
  function executeHubSpokeAdditions(
    IAaveV4ConfigEngine.SpokeAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].hubConfigurator.addSpoke(
        additions[i].hub,
        additions[i].spoke,
        additions[i].assetId,
        additions[i].config
      );
    }
  }

  /// @notice Registers spokes for multiple assets on hubs.
  /// @param additions The spoke-to-assets additions to execute.
  function executeHubSpokeToAssetsAdditions(
    IAaveV4ConfigEngine.SpokeToAssetsAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].hubConfigurator.addSpokeToAssets(
        additions[i].hub,
        additions[i].spoke,
        additions[i].assetIds,
        additions[i].configs
      );
    }
  }

  /// @notice Updates spoke caps on hubs.
  /// @dev If both addCap and drawCap are set, calls updateSpokeCaps.
  ///   If only addCap is set, calls updateSpokeSupplyCap.
  ///   If only drawCap is set, calls updateSpokeDrawCap.
  ///   If neither is set, the update is skipped.
  /// @param updates The spoke caps updates to execute.
  function executeHubSpokeCapsUpdates(
    IAaveV4ConfigEngine.SpokeCapsUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      bool updateAdd = updates[i].addCap != EngineFlags.KEEP_CURRENT;
      bool updateDraw = updates[i].drawCap != EngineFlags.KEEP_CURRENT;

      if (updateAdd && updateDraw) {
        updates[i].hubConfigurator.updateSpokeCaps(
          updates[i].hub,
          updates[i].assetId,
          updates[i].spoke,
          updates[i].addCap,
          updates[i].drawCap
        );
      } else if (updateAdd) {
        updates[i].hubConfigurator.updateSpokeSupplyCap(
          updates[i].hub,
          updates[i].assetId,
          updates[i].spoke,
          updates[i].addCap
        );
      } else if (updateDraw) {
        updates[i].hubConfigurator.updateSpokeDrawCap(
          updates[i].hub,
          updates[i].assetId,
          updates[i].spoke,
          updates[i].drawCap
        );
      }
    }
  }

  /// @notice Updates spoke risk premium thresholds on hubs.
  /// @param updates The spoke risk premium threshold updates to execute.
  function executeHubSpokeRiskPremiumThresholdUpdates(
    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].hubConfigurator.updateSpokeRiskPremiumThreshold(
        updates[i].hub,
        updates[i].assetId,
        updates[i].spoke,
        updates[i].riskPremiumThreshold
      );
    }
  }

  /// @notice Updates spoke status (active/halted) on hubs.
  /// @param updates The spoke status updates to execute.
  function executeHubSpokeStatusUpdates(
    IAaveV4ConfigEngine.SpokeStatusUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      if (updates[i].active != EngineFlags.KEEP_CURRENT) {
        updates[i].hubConfigurator.updateSpokeActive(
          updates[i].hub,
          updates[i].assetId,
          updates[i].spoke,
          EngineFlags.toBool(updates[i].active)
        );
      }
      if (updates[i].halted != EngineFlags.KEEP_CURRENT) {
        updates[i].hubConfigurator.updateSpokeHalted(
          updates[i].hub,
          updates[i].assetId,
          updates[i].spoke,
          EngineFlags.toBool(updates[i].halted)
        );
      }
    }
  }

  /// @notice Halts assets on hubs.
  /// @param halts The asset halts to execute.
  function executeHubAssetHalts(IAaveV4ConfigEngine.AssetHalt[] calldata halts) external {
    uint256 length = halts.length;
    for (uint256 i; i < length; ++i) {
      halts[i].hubConfigurator.haltAsset(halts[i].hub, halts[i].assetId);
    }
  }

  /// @notice Deactivates assets on hubs.
  /// @param deactivations The asset deactivations to execute.
  function executeHubAssetDeactivations(
    IAaveV4ConfigEngine.AssetDeactivation[] calldata deactivations
  ) external {
    uint256 length = deactivations.length;
    for (uint256 i; i < length; ++i) {
      deactivations[i].hubConfigurator.deactivateAsset(
        deactivations[i].hub,
        deactivations[i].assetId
      );
    }
  }

  /// @notice Resets asset caps on hubs.
  /// @param resets The asset caps resets to execute.
  function executeHubAssetCapsResets(
    IAaveV4ConfigEngine.AssetCapsReset[] calldata resets
  ) external {
    uint256 length = resets.length;
    for (uint256 i; i < length; ++i) {
      resets[i].hubConfigurator.resetAssetCaps(resets[i].hub, resets[i].assetId);
    }
  }

  /// @notice Halts spokes on hubs.
  /// @param halts The spoke halts to execute.
  function executeHubSpokeHalts(IAaveV4ConfigEngine.SpokeHalt[] calldata halts) external {
    uint256 length = halts.length;
    for (uint256 i; i < length; ++i) {
      halts[i].hubConfigurator.haltSpoke(halts[i].hub, halts[i].spoke);
    }
  }

  /// @notice Deactivates spokes on hubs.
  /// @param deactivations The spoke deactivations to execute.
  function executeHubSpokeDeactivations(
    IAaveV4ConfigEngine.SpokeDeactivation[] calldata deactivations
  ) external {
    uint256 length = deactivations.length;
    for (uint256 i; i < length; ++i) {
      deactivations[i].hubConfigurator.deactivateSpoke(
        deactivations[i].hub,
        deactivations[i].spoke
      );
    }
  }

  /// @notice Resets spoke caps on hubs.
  /// @param resets The spoke caps resets to execute.
  function executeHubSpokeCapsResets(
    IAaveV4ConfigEngine.SpokeCapsReset[] calldata resets
  ) external {
    uint256 length = resets.length;
    for (uint256 i; i < length; ++i) {
      resets[i].hubConfigurator.resetSpokeCaps(resets[i].hub, resets[i].spoke);
    }
  }
}
