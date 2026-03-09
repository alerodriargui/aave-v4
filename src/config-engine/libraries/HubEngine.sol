// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

/// @title HubEngine
/// @author Aave Labs
/// @notice Library containing hub configurator logic for AaveV4ConfigEngine.
library HubEngine {
  using SafeCast for uint256;

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
          listings[i].decimals.toUint8(),
          listings[i].feeReceiver,
          listings[i].liquidityFee,
          listings[i].irStrategy,
          listings[i].irData
        );
      }
    }
  }

  /// @notice Updates asset config (fee, interest rate, reinvestment) for assets on hubs.
  /// @dev Dispatches to the appropriate HubConfigurator methods based on sentinel values:
  ///   Fee: both set → updateFeeConfig; only fee → updateLiquidityFee; only receiver → updateFeeReceiver.
  ///   IR: strategy set → updateInterestRateStrategy; strategy kept + irData → updateInterestRateData.
  ///   Reinvestment: address set → updateReinvestmentController.
  /// @param updates The asset config updates to execute.
  function executeHubAssetConfigUpdates(
    IAaveV4ConfigEngine.AssetConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      // Fee dispatch
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

      // Interest rate dispatch
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

      // Reinvestment controller dispatch
      if (updates[i].reinvestmentController != EngineFlags.KEEP_CURRENT_ADDRESS) {
        updates[i].hubConfigurator.updateReinvestmentController(
          updates[i].hub,
          updates[i].assetId,
          updates[i].reinvestmentController
        );
      }
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

  /// @notice Updates spoke config (caps, risk premium threshold, status) on hubs.
  /// @dev Dispatches to the appropriate HubConfigurator methods based on sentinel values:
  ///   Caps: both set → updateSpokeCaps; only add → updateSpokeAddCap; only draw → updateSpokeDrawCap.
  ///   Risk premium threshold: set → updateSpokeRiskPremiumThreshold.
  ///   Status: active set → updateSpokeActive; halted set → updateSpokeHalted.
  /// @param updates The spoke config updates to execute.
  function executeHubSpokeConfigUpdates(
    IAaveV4ConfigEngine.SpokeConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      // Caps dispatch
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
        updates[i].hubConfigurator.updateSpokeAddCap(
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

      // Risk premium threshold dispatch
      if (updates[i].riskPremiumThreshold != EngineFlags.KEEP_CURRENT) {
        updates[i].hubConfigurator.updateSpokeRiskPremiumThreshold(
          updates[i].hub,
          updates[i].assetId,
          updates[i].spoke,
          updates[i].riskPremiumThreshold
        );
      }

      // Status dispatch
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
