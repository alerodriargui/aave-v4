// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4PayloadBase} from 'src/deployments/config-engine/AaveV4PayloadBase.sol';
import {IAaveV4HubConfigEngine} from 'src/deployments/config-engine/IAaveV4HubConfigEngine.sol';

/// @title AaveV4HubPayload
/// @author Aave Labs
/// @notice Abstract payload for Hub-only operations (listing assets, registering spokes, updates).
/// @dev Uses DELEGATECALL to the stateless HUB_CONFIG_ENGINE so that the governance executor's
///      address (which holds the AccessManager roles) is preserved as msg.sender.
///      Override the virtual functions to provide listing/update data.
abstract contract AaveV4HubPayload is AaveV4PayloadBase {
  IAaveV4HubConfigEngine public immutable HUB_CONFIG_ENGINE;
  address public immutable HUB;
  address public immutable HUB_CONFIGURATOR;
  bytes32 public immutable SALT;

  constructor(address hubConfigEngine_, address hub_, address hubConfigurator_, bytes32 salt_) {
    HUB_CONFIG_ENGINE = IAaveV4HubConfigEngine(hubConfigEngine_);
    HUB = hub_;
    HUB_CONFIGURATOR = hubConfigurator_;
    SALT = salt_;
  }

  /// @inheritdoc AaveV4PayloadBase
  function _executePayload() internal override {
    // Listings
    IAaveV4HubConfigEngine.AssetListing[] memory assets = newAssetListings();
    if (assets.length > 0) {
      _delegateToEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.listAssets, (HUB, HUB_CONFIGURATOR, assets))
      );
    }

    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = newSpokeListings();
    if (spokes.length > 0) {
      _delegateToEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.addSpokes, (HUB, HUB_CONFIGURATOR, SALT, spokes))
      );
    }

    // Granular asset updates
    IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate[] memory feeUpdates = assetLiquidityFeeUpdates();
    if (feeUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateAssetLiquidityFees,
          (HUB, HUB_CONFIGURATOR, feeUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.AssetIRDataUpdate[] memory irUpdates = assetIRDataUpdates();
    if (irUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.updateAssetIRData, (HUB, HUB_CONFIGURATOR, irUpdates))
      );
    }

    IAaveV4HubConfigEngine.AssetIRStrategyUpdate[] memory irStratUpdates = assetIRStrategyUpdates();
    if (irStratUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateAssetIRStrategies,
          (HUB, HUB_CONFIGURATOR, irStratUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.AssetFeeReceiverUpdate[]
      memory feeReceiverUpdates = assetFeeReceiverUpdates();
    if (feeReceiverUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateAssetFeeReceivers,
          (HUB, HUB_CONFIGURATOR, feeReceiverUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.ReinvestmentControllerUpdate[]
      memory reinvestUpdates = reinvestmentControllerUpdates();
    if (reinvestUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateReinvestmentControllers,
          (HUB, HUB_CONFIGURATOR, reinvestUpdates)
        )
      );
    }

    // Granular spoke updates
    IAaveV4HubConfigEngine.SpokeCapUpdate[] memory capUpdates = spokeCapUpdates();
    if (capUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.updateSpokeCaps, (HUB, HUB_CONFIGURATOR, capUpdates))
      );
    }

    IAaveV4HubConfigEngine.SpokeActiveUpdate[] memory activeUpdates = spokeActiveUpdates();
    if (activeUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateSpokeActive,
          (HUB, HUB_CONFIGURATOR, activeUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.SpokeHaltedUpdate[] memory haltedUpdates = spokeHaltedUpdates();
    if (haltedUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateSpokeHalted,
          (HUB, HUB_CONFIGURATOR, haltedUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate[] memory riskUpdates = spokeRiskPremiumUpdates();
    if (riskUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateSpokeRiskPremiumThresholds,
          (HUB, HUB_CONFIGURATOR, riskUpdates)
        )
      );
    }
  }

  // ==================== Listing Hooks ====================

  function newAssetListings()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.AssetListing[] memory)
  {
    return new IAaveV4HubConfigEngine.AssetListing[](0);
  }

  function newSpokeListings()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.SpokeListing[] memory)
  {
    return new IAaveV4HubConfigEngine.SpokeListing[](0);
  }

  // ==================== Asset Update Hooks ====================

  function assetLiquidityFeeUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate[](0);
  }

  function assetIRDataUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.AssetIRDataUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.AssetIRDataUpdate[](0);
  }

  function assetIRStrategyUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.AssetIRStrategyUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.AssetIRStrategyUpdate[](0);
  }

  function assetFeeReceiverUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.AssetFeeReceiverUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.AssetFeeReceiverUpdate[](0);
  }

  function reinvestmentControllerUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.ReinvestmentControllerUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.ReinvestmentControllerUpdate[](0);
  }

  // ==================== Spoke Update Hooks ====================

  function spokeCapUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.SpokeCapUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.SpokeCapUpdate[](0);
  }

  function spokeActiveUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.SpokeActiveUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.SpokeActiveUpdate[](0);
  }

  function spokeHaltedUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.SpokeHaltedUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.SpokeHaltedUpdate[](0);
  }

  function spokeRiskPremiumUpdates()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate[] memory)
  {
    return new IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate[](0);
  }

  // ==================== Internal ====================

  /// @dev DELEGATECALLs to the stateless config engine, preserving msg.sender context.
  function _delegateToEngine(bytes memory data) internal {
    (bool success, bytes memory returnData) = address(HUB_CONFIG_ENGINE).delegatecall(data);
    if (!success) {
      assembly {
        revert(add(returnData, 32), mload(returnData))
      }
    }
  }
}
