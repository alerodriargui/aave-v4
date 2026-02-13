// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IAaveV4HubConfigEngine} from 'src/deployments/config-engine/IAaveV4HubConfigEngine.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

/// @title AaveV4HubConfigEngine
/// @author Aave Labs
/// @notice Stateless engine for Hub-side configuration: listing assets, registering spokes,
///         deploying tokenization spokes, and updating asset/spoke configs.
/// @dev This contract is STATELESS and designed to be called via DELEGATECALL.
///      When used via DELEGATECALL, the calling contract's context (address, roles) is used.
///      The caller must hold the appropriate AccessManager roles (e.g., HUB_CONFIGURATOR_ADMIN_ROLE).
contract AaveV4HubConfigEngine is IAaveV4HubConfigEngine {
  /// @inheritdoc IAaveV4HubConfigEngine
  function listAssets(
    address hub,
    address hubConfigurator,
    AssetListing[] calldata listings
  ) external returns (ListAssetsReport memory report) {
    uint256 len = listings.length;
    report.underlyings = new address[](len);
    report.assetIds = new uint256[](len);

    for (uint256 i; i < len; i++) {
      AssetListing calldata listing = listings[i];

      uint256 assetId = IHubConfigurator(hubConfigurator).addAsset(
        hub,
        listing.underlying,
        listing.feeReceiver,
        listing.liquidityFee,
        listing.irStrategy,
        listing.irData
      );

      // Set reinvestment controller if specified
      if (listing.reinvestmentController != address(0)) {
        IHubConfigurator(hubConfigurator).updateReinvestmentController(
          hub,
          assetId,
          listing.reinvestmentController
        );
      }

      report.underlyings[i] = listing.underlying;
      report.assetIds[i] = assetId;
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function addSpokes(
    address hub,
    address hubConfigurator,
    bytes32 salt,
    SpokeListing[] calldata spokes
  ) external returns (AddSpokesReport memory report) {
    uint256 len = spokes.length;
    report.spokeAddresses = new address[](len);
    report.tokenizationProxies = new address[](len);

    for (uint256 i; i < len; i++) {
      SpokeListing calldata entry = spokes[i];

      // Resolve assetId from underlying address
      uint256 assetId = IHub(hub).getAssetId(entry.underlying);

      address spokeAddr = entry.spoke;

      if (entry.tokenization.enabled) {
        // Deploy TokenizationSpokeInstance implementation
        bytes memory implBytecode = abi.encodePacked(
          type(TokenizationSpokeInstance).creationCode,
          abi.encode(hub, assetId)
        );
        bytes32 implSalt = keccak256(abi.encodePacked(salt, 'tokenization-impl', entry.underlying));
        address impl = Create2Utils.create2Deploy(implSalt, implBytecode);

        // Deploy proxy
        bytes32 proxySalt = keccak256(
          abi.encodePacked(salt, 'tokenization-proxy', entry.underlying)
        );
        spokeAddr = Create2Utils.proxify(
          proxySalt,
          impl,
          entry.tokenization.proxyAdminOwner,
          abi.encodeCall(
            TokenizationSpokeInstance.initialize,
            (entry.tokenization.shareName, entry.tokenization.shareSymbol)
          )
        );

        report.tokenizationProxies[i] = spokeAddr;
      }

      // Register spoke on Hub
      IHubConfigurator(hubConfigurator).addSpoke(hub, spokeAddr, assetId, entry.spokeConfig);

      report.spokeAddresses[i] = spokeAddr;
    }
  }

  // ==================== Granular Asset Updates ====================

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateAssetLiquidityFees(
    address hub,
    address hubConfigurator,
    AssetLiquidityFeeUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateLiquidityFee(
        hub,
        updates[i].assetId,
        updates[i].liquidityFee
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateAssetIRData(
    address hub,
    address hubConfigurator,
    AssetIRDataUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateInterestRateData(
        hub,
        updates[i].assetId,
        updates[i].irData
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateAssetIRStrategies(
    address hub,
    address hubConfigurator,
    AssetIRStrategyUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateInterestRateStrategy(
        hub,
        updates[i].assetId,
        updates[i].irStrategy,
        updates[i].irData
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateAssetFeeReceivers(
    address hub,
    address hubConfigurator,
    AssetFeeReceiverUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateFeeReceiver(
        hub,
        updates[i].assetId,
        updates[i].feeReceiver
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateReinvestmentControllers(
    address hub,
    address hubConfigurator,
    ReinvestmentControllerUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateReinvestmentController(
        hub,
        updates[i].assetId,
        updates[i].reinvestmentController
      );
    }
  }

  // ==================== Granular Spoke Updates ====================

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateSpokeCaps(
    address hub,
    address hubConfigurator,
    SpokeCapUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateSpokeCaps(
        hub,
        updates[i].assetId,
        updates[i].spoke,
        updates[i].addCap,
        updates[i].drawCap
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateSpokeActive(
    address hub,
    address hubConfigurator,
    SpokeActiveUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateSpokeActive(
        hub,
        updates[i].assetId,
        updates[i].spoke,
        updates[i].active
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateSpokeHalted(
    address hub,
    address hubConfigurator,
    SpokeHaltedUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateSpokeHalted(
        hub,
        updates[i].assetId,
        updates[i].spoke,
        updates[i].halted
      );
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateSpokeRiskPremiumThresholds(
    address hub,
    address hubConfigurator,
    SpokeRiskPremiumUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      IHubConfigurator(hubConfigurator).updateSpokeRiskPremiumThreshold(
        hub,
        updates[i].assetId,
        updates[i].spoke,
        updates[i].riskPremiumThreshold
      );
    }
  }
}
