// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Address} from 'src/dependencies/openzeppelin/Address.sol';

import {AaveV4PayloadBase} from 'src/deployments/config-engine/AaveV4PayloadBase.sol';
import {IAaveV4HubConfigEngine} from 'src/deployments/config-engine/IAaveV4HubConfigEngine.sol';
import {IAaveV4SpokeConfigEngine} from 'src/deployments/config-engine/IAaveV4SpokeConfigEngine.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4Payload
/// @author Aave Labs
/// @notice Unified payload for Hub and Spoke operations in a single governance proposal.
/// @dev Uses DELEGATECALL to stateless config engines so that the governance executor's
///      address (which holds the AccessManager roles) is preserved as msg.sender.
///      Override the virtual hook functions to provide listing/update data.
///      Hub operations execute first, then spoke operations.
abstract contract AaveV4Payload is AaveV4PayloadBase {
  IAaveV4HubConfigEngine public immutable HUB_CONFIG_ENGINE;
  IAaveV4SpokeConfigEngine public immutable SPOKE_CONFIG_ENGINE;
  address public immutable HUB;
  address public immutable HUB_CONFIGURATOR;
  address public immutable SPOKE;
  address public immutable SPOKE_CONFIGURATOR;
  bytes32 public immutable SALT;

  constructor(
    address hubConfigEngine_,
    address spokeConfigEngine_,
    address hub_,
    address hubConfigurator_,
    address spoke_,
    address spokeConfigurator_,
    bytes32 salt_
  ) {
    HUB_CONFIG_ENGINE = IAaveV4HubConfigEngine(hubConfigEngine_);
    SPOKE_CONFIG_ENGINE = IAaveV4SpokeConfigEngine(spokeConfigEngine_);
    HUB = hub_;
    HUB_CONFIGURATOR = hubConfigurator_;
    SPOKE = spoke_;
    SPOKE_CONFIGURATOR = spokeConfigurator_;
    SALT = salt_;
  }

  /// @inheritdoc AaveV4PayloadBase
  function _executePayload() internal override {
    _executeHubPayload();
    _executeSpokePayload();
  }

  // ==================== Hub Execution ====================

  function _executeHubPayload() internal {
    IAaveV4HubConfigEngine.AssetListing[] memory assets = newAssetListings();
    if (assets.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.listAssets, (HUB, HUB_CONFIGURATOR, assets))
      );
    }

    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = newSpokeListings();
    if (spokes.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.addSpokes, (HUB, HUB_CONFIGURATOR, SALT, spokes))
      );
    }

    IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate[] memory feeUpdates = assetLiquidityFeeUpdates();
    if (feeUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateAssetLiquidityFees,
          (HUB, HUB_CONFIGURATOR, feeUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.AssetIRDataUpdate[] memory irUpdates = assetIRDataUpdates();
    if (irUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.updateAssetIRData, (HUB, HUB_CONFIGURATOR, irUpdates))
      );
    }

    IAaveV4HubConfigEngine.AssetIRStrategyUpdate[] memory irStratUpdates = assetIRStrategyUpdates();
    if (irStratUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateAssetIRStrategies,
          (HUB, HUB_CONFIGURATOR, irStratUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.AssetFeeReceiverUpdate[]
      memory feeReceiverUpdates = assetFeeReceiverUpdates();
    if (feeReceiverUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateAssetFeeReceivers,
          (HUB, HUB_CONFIGURATOR, feeReceiverUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.ReinvestmentControllerUpdate[]
      memory reinvestUpdates = reinvestmentControllerUpdates();
    if (reinvestUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateReinvestmentControllers,
          (HUB, HUB_CONFIGURATOR, reinvestUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.SpokeCapUpdate[] memory capUpdates = spokeCapUpdates();
    if (capUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(IAaveV4HubConfigEngine.updateSpokeCaps, (HUB, HUB_CONFIGURATOR, capUpdates))
      );
    }

    IAaveV4HubConfigEngine.SpokeActiveUpdate[] memory activeUpdates = spokeActiveUpdates();
    if (activeUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateSpokeActive,
          (HUB, HUB_CONFIGURATOR, activeUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.SpokeHaltedUpdate[] memory haltedUpdates = spokeHaltedUpdates();
    if (haltedUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateSpokeHalted,
          (HUB, HUB_CONFIGURATOR, haltedUpdates)
        )
      );
    }

    IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate[] memory riskUpdates = spokeRiskPremiumUpdates();
    if (riskUpdates.length > 0) {
      _delegateToHubEngine(
        abi.encodeCall(
          IAaveV4HubConfigEngine.updateSpokeRiskPremiumThresholds,
          (HUB, HUB_CONFIGURATOR, riskUpdates)
        )
      );
    }
  }

  // ==================== Spoke Execution ====================

  function _executeSpokePayload() internal {
    IAaveV4SpokeConfigEngine.ReserveListing[] memory reserves = newReserveListings();
    if (reserves.length > 0) {
      _delegateToSpokeEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.listReserves,
          (SPOKE, SPOKE_CONFIGURATOR, HUB, reserves)
        )
      );
    }

    IAaveV4SpokeConfigEngine.LiquidationConfigInput memory liqConfig = liquidationConfig();
    if (liqConfig.config.targetHealthFactor > 0) {
      _delegateToSpokeEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.updateLiquidationConfig,
          (SPOKE, SPOKE_CONFIGURATOR, liqConfig)
        )
      );
    }

    IAaveV4SpokeConfigEngine.ReserveConfigUpdate[] memory reserveUpdates = reserveConfigUpdates();
    if (reserveUpdates.length > 0) {
      _delegateToSpokeEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.updateReserves,
          (SPOKE, SPOKE_CONFIGURATOR, reserveUpdates)
        )
      );
    }

    IAaveV4SpokeConfigEngine.DynamicConfigUpdate[] memory dynamicUpdates = dynamicConfigUpdates();
    if (dynamicUpdates.length > 0) {
      _delegateToSpokeEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.updateDynamicConfigs,
          (SPOKE, SPOKE_CONFIGURATOR, dynamicUpdates)
        )
      );
    }
  }

  // ==================== Hub Listing Hooks ====================

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

  // ==================== Hub Asset Update Hooks ====================

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

  // ==================== Hub Spoke Update Hooks ====================

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

  // ==================== Spoke Listing Hooks ====================

  function newReserveListings()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.ReserveListing[] memory)
  {
    return new IAaveV4SpokeConfigEngine.ReserveListing[](0);
  }

  function liquidationConfig()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.LiquidationConfigInput memory)
  {
    return
      IAaveV4SpokeConfigEngine.LiquidationConfigInput({config: ISpoke.LiquidationConfig(0, 0, 0)});
  }

  // ==================== Spoke Update Hooks ====================

  function reserveConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.ReserveConfigUpdate[] memory)
  {
    return new IAaveV4SpokeConfigEngine.ReserveConfigUpdate[](0);
  }

  function dynamicConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.DynamicConfigUpdate[] memory)
  {
    return new IAaveV4SpokeConfigEngine.DynamicConfigUpdate[](0);
  }

  // ==================== Internal ====================

  /// @dev DELEGATECALLs to the hub config engine, preserving msg.sender context.
  function _delegateToHubEngine(bytes memory data) internal {
    Address.functionDelegateCall(address(HUB_CONFIG_ENGINE), data);
  }

  /// @dev DELEGATECALLs to the spoke config engine, preserving msg.sender context.
  function _delegateToSpokeEngine(bytes memory data) internal {
    Address.functionDelegateCall(address(SPOKE_CONFIG_ENGINE), data);
  }
}
