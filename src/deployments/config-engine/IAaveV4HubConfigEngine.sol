// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title IAaveV4HubConfigEngine
/// @author Aave Labs
/// @notice Interface for the Hub configuration engine.
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

  /// @notice Parameters for updating an existing asset configuration.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param config The new asset configuration.
  /// @param irData The interest rate data. Must be empty if irStrategy is not being changed.
  struct AssetConfigUpdate {
    uint256 assetId;
    IHub.AssetConfig config;
    bytes irData;
  }

  /// @notice Parameters for updating an existing spoke configuration.
  /// @param assetId The identifier of the asset on the Hub.
  /// @param spoke The address of the spoke.
  /// @param config The new spoke configuration.
  struct SpokeConfigUpdate {
    uint256 assetId;
    address spoke;
    IHub.SpokeConfig config;
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

  /// @notice Lists new assets on the Hub via the HubConfigurator.
  /// @param listings The array of asset listing parameters.
  /// @return report A report with the underlying addresses and their newly assigned asset IDs.
  function listAssets(
    AssetListing[] calldata listings
  ) external returns (ListAssetsReport memory report);

  /// @notice Registers spokes for assets on the Hub. Optionally deploys TokenizationSpoke instances.
  /// @dev Resolves assetId via hub.getAssetId(underlying) for each spoke entry.
  /// @param spokes The array of spoke listing parameters.
  /// @return report A report with the spoke and tokenization proxy addresses.
  function addSpokes(
    SpokeListing[] calldata spokes
  ) external returns (AddSpokesReport memory report);

  /// @notice Updates existing asset configurations on the Hub.
  /// @param updates The array of asset configuration updates.
  function updateAssets(AssetConfigUpdate[] calldata updates) external;

  /// @notice Updates existing spoke configurations on the Hub.
  /// @param updates The array of spoke configuration updates.
  function updateSpokes(SpokeConfigUpdate[] calldata updates) external;
}
