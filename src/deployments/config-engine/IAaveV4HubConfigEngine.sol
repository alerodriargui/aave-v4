// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title IAaveV4HubConfigEngine
/// @author Aave Labs
/// @notice Interface for the Hub configuration engine.
/// @dev This engine is STATELESS and designed to be used via DELEGATECALL.
///      All functions receive hub and hubConfigurator addresses as parameters.
///      When called via DELEGATECALL, the caller's context is used — so the
///      caller (payload or executor) must hold the appropriate AccessManager roles.
interface IAaveV4HubConfigEngine {
  /// @notice Parameters for listing a new asset on the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param irStrategy The address of the interest rate strategy contract.
  /// @param irData The interest rate data, encoded in bytes.
  /// @param liquidityFee The protocol fee on liquidity growth, in BPS.
  /// @param feeReceiver The address of the fee receiver spoke.
  /// @param reinvestmentController The address of the reinvestment controller (address(0) if none).
  struct AssetListing {
    address underlying;
    address irStrategy;
    bytes irData;
    uint16 liquidityFee;
    address feeReceiver;
    address reinvestmentController;
  }

  /// @notice Configuration for deploying a TokenizationSpoke.
  /// @param enabled True to deploy a TokenizationSpoke instead of using a pre-deployed spoke address.
  /// @param shareName The ERC20 name of the tokenization vault share token.
  /// @param shareSymbol The ERC20 symbol of the tokenization vault share token.
  /// @param proxyAdminOwner The owner of the proxy admin for the tokenization spoke proxy.
  struct TokenizationConfig {
    bool enabled;
    string shareName;
    string shareSymbol;
    address proxyAdminOwner;
  }

  /// @notice Parameters for registering a spoke for an asset on the Hub.
  /// @param underlying The underlying asset address used to resolve the assetId on the Hub.
  /// @param spoke The pre-deployed spoke address. Must be address(0) if tokenization.enabled is true.
  /// @param tokenization Configuration for deploying a TokenizationSpoke.
  /// @param spokeConfig The spoke configuration (caps, risk premium threshold, active/halted flags).
  struct SpokeListing {
    address underlying;
    address spoke;
    TokenizationConfig tokenization;
    IHub.SpokeConfig spokeConfig;
  }

  // ==================== Granular Asset Update Structs ====================

  /// @notice Parameters for updating an asset's liquidity fee.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param liquidityFee The new liquidity fee in BPS.
  struct AssetLiquidityFeeUpdate {
    uint256 assetId;
    uint256 liquidityFee;
  }

  /// @notice Parameters for updating an asset's interest rate data.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param irData The new interest rate data, encoded in bytes.
  struct AssetIRDataUpdate {
    uint256 assetId;
    bytes irData;
  }

  /// @notice Parameters for updating an asset's interest rate strategy and data.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param irStrategy The new interest rate strategy contract.
  /// @param irData The interest rate data to apply, encoded in bytes.
  struct AssetIRStrategyUpdate {
    uint256 assetId;
    address irStrategy;
    bytes irData;
  }

  /// @notice Parameters for updating an asset's fee receiver.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param feeReceiver The new fee receiver address.
  struct AssetFeeReceiverUpdate {
    uint256 assetId;
    address feeReceiver;
  }

  /// @notice Parameters for updating an asset's reinvestment controller.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param reinvestmentController The new reinvestment controller address.
  struct ReinvestmentControllerUpdate {
    uint256 assetId;
    address reinvestmentController;
  }

  // ==================== Granular Spoke Update Structs ====================

  /// @notice Parameters for updating a spoke's caps.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param spoke The address of the spoke.
  /// @param addCap The new supply cap.
  /// @param drawCap The new draw cap.
  struct SpokeCapUpdate {
    uint256 assetId;
    address spoke;
    uint256 addCap;
    uint256 drawCap;
  }

  /// @notice Parameters for updating a spoke's active flag.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param spoke The address of the spoke.
  /// @param active The new active flag.
  struct SpokeActiveUpdate {
    uint256 assetId;
    address spoke;
    bool active;
  }

  /// @notice Parameters for updating a spoke's halted flag.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param spoke The address of the spoke.
  /// @param halted The new halted flag.
  struct SpokeHaltedUpdate {
    uint256 assetId;
    address spoke;
    bool halted;
  }

  /// @notice Parameters for updating a spoke's risk premium threshold.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param spoke The address of the spoke.
  /// @param riskPremiumThreshold The new risk premium threshold.
  struct SpokeRiskPremiumUpdate {
    uint256 assetId;
    address spoke;
    uint256 riskPremiumThreshold;
  }

  /// @notice Report returned by listAssets with the newly created asset IDs.
  /// @param underlyings The underlying asset addresses.
  /// @param assetIds The corresponding Hub asset IDs.
  struct ListAssetsReport {
    address[] underlyings;
    uint256[] assetIds;
  }

  /// @notice Report returned by addSpokes with the registered spoke addresses.
  /// @param spokeAddresses The spoke addresses registered on the Hub (filled in for tokenization deploys).
  /// @param tokenizationProxies The deployed tokenization spoke proxies (address(0) if not tokenization).
  struct AddSpokesReport {
    address[] spokeAddresses;
    address[] tokenizationProxies;
  }

  // ==================== Listing Functions ====================

  /// @notice Lists new assets on the Hub via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param listings The array of asset listing parameters.
  /// @return report A report with the underlying addresses and their newly assigned asset IDs.
  function listAssets(
    address hub,
    address hubConfigurator,
    AssetListing[] calldata listings
  ) external returns (ListAssetsReport memory report);

  /// @notice Registers spokes for assets on the Hub. Optionally deploys TokenizationSpoke instances.
  /// @dev Resolves assetId via hub.getAssetId(underlying) for each spoke entry.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param salt The salt prefix for deterministic tokenization spoke deployment.
  /// @param spokes The array of spoke listing parameters.
  /// @return report A report with the spoke and tokenization proxy addresses.
  function addSpokes(
    address hub,
    address hubConfigurator,
    bytes32 salt,
    SpokeListing[] calldata spokes
  ) external returns (AddSpokesReport memory report);

  // ==================== Granular Asset Update Functions ====================

  /// @notice Updates liquidity fees for assets via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of liquidity fee updates.
  function updateAssetLiquidityFees(
    address hub,
    address hubConfigurator,
    AssetLiquidityFeeUpdate[] calldata updates
  ) external;

  /// @notice Updates interest rate data for assets via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of IR data updates.
  function updateAssetIRData(
    address hub,
    address hubConfigurator,
    AssetIRDataUpdate[] calldata updates
  ) external;

  /// @notice Updates interest rate strategies for assets via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of IR strategy updates.
  function updateAssetIRStrategies(
    address hub,
    address hubConfigurator,
    AssetIRStrategyUpdate[] calldata updates
  ) external;

  /// @notice Updates fee receivers for assets via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of fee receiver updates.
  function updateAssetFeeReceivers(
    address hub,
    address hubConfigurator,
    AssetFeeReceiverUpdate[] calldata updates
  ) external;

  /// @notice Updates reinvestment controllers for assets via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of reinvestment controller updates.
  function updateReinvestmentControllers(
    address hub,
    address hubConfigurator,
    ReinvestmentControllerUpdate[] calldata updates
  ) external;

  // ==================== Granular Spoke Update Functions ====================

  /// @notice Updates caps for spokes via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of spoke cap updates.
  function updateSpokeCaps(
    address hub,
    address hubConfigurator,
    SpokeCapUpdate[] calldata updates
  ) external;

  /// @notice Updates active flags for spokes via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of spoke active updates.
  function updateSpokeActive(
    address hub,
    address hubConfigurator,
    SpokeActiveUpdate[] calldata updates
  ) external;

  /// @notice Updates halted flags for spokes via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of spoke halted updates.
  function updateSpokeHalted(
    address hub,
    address hubConfigurator,
    SpokeHaltedUpdate[] calldata updates
  ) external;

  /// @notice Updates risk premium thresholds for spokes via the HubConfigurator.
  /// @param hub The Hub contract address.
  /// @param hubConfigurator The HubConfigurator contract address.
  /// @param updates The array of risk premium threshold updates.
  function updateSpokeRiskPremiumThresholds(
    address hub,
    address hubConfigurator,
    SpokeRiskPremiumUpdate[] calldata updates
  ) external;
}
