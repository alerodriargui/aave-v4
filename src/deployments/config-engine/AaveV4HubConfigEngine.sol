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
/// deploying tokenization spokes, and updating asset/spoke configs.
contract AaveV4HubConfigEngine is IAaveV4HubConfigEngine {
  address public immutable HUB;
  address public immutable HUB_CONFIGURATOR;

  /// @dev Salt prefix for deterministic tokenization spoke deployment.
  bytes32 internal immutable SALT;

  constructor(address hub_, address hubConfigurator_, bytes32 salt_) {
    require(hub_ != address(0), 'invalid hub');
    require(hubConfigurator_ != address(0), 'invalid hub configurator');
    HUB = hub_;
    HUB_CONFIGURATOR = hubConfigurator_;
    SALT = salt_;
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function listAssets(
    AssetListing[] calldata listings
  ) external returns (ListAssetsReport memory report) {
    uint256 len = listings.length;
    report.underlyings = new address[](len);
    report.assetIds = new uint256[](len);

    for (uint256 i; i < len; i++) {
      AssetListing calldata listing = listings[i];

      uint256 assetId = IHubConfigurator(HUB_CONFIGURATOR).addAsset(
        HUB,
        listing.underlying,
        listing.feeReceiver,
        listing.liquidityFee,
        listing.irStrategy,
        listing.irData
      );

      // Set reinvestment controller if specified
      if (listing.reinvestmentController != address(0)) {
        IHubConfigurator(HUB_CONFIGURATOR).updateReinvestmentController(
          HUB,
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
    SpokeListing[] calldata spokes
  ) external returns (AddSpokesReport memory report) {
    uint256 len = spokes.length;
    report.spokeAddresses = new address[](len);
    report.tokenizationProxies = new address[](len);

    for (uint256 i; i < len; i++) {
      SpokeListing calldata entry = spokes[i];

      // Resolve assetId from underlying address
      uint256 assetId = IHub(HUB).getAssetId(entry.underlying);

      address spokeAddr = entry.spoke;

      if (entry.tokenization.enabled) {
        // Deploy TokenizationSpokeInstance implementation
        bytes memory implBytecode = abi.encodePacked(
          type(TokenizationSpokeInstance).creationCode,
          abi.encode(HUB, assetId)
        );
        bytes32 implSalt = keccak256(abi.encodePacked(SALT, 'tokenization-impl', entry.underlying));
        address impl = Create2Utils.create2Deploy(implSalt, implBytecode);

        // Deploy proxy
        bytes32 proxySalt = keccak256(
          abi.encodePacked(SALT, 'tokenization-proxy', entry.underlying)
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
      IHubConfigurator(HUB_CONFIGURATOR).addSpoke(HUB, spokeAddr, assetId, entry.spokeConfig);

      report.spokeAddresses[i] = spokeAddr;
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateAssets(AssetConfigUpdate[] calldata updates) external {
    for (uint256 i; i < updates.length; i++) {
      IHub(HUB).updateAssetConfig(updates[i].assetId, updates[i].config, updates[i].irData);
    }
  }

  /// @inheritdoc IAaveV4HubConfigEngine
  function updateSpokes(SpokeConfigUpdate[] calldata updates) external {
    for (uint256 i; i < updates.length; i++) {
      IHub(HUB).updateSpokeConfig(updates[i].assetId, updates[i].spoke, updates[i].config);
    }
  }
}
