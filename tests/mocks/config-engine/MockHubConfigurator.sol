// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

contract MockHubConfigurator is IHubConfigurator {
  // Per-function revert toggle
  mapping(bytes4 => bool) public shouldRevert;

  string public constant REVERT_MSG = 'MOCK_REVERT';

  function setShouldRevert(bytes4 selector, bool revert_) external {
    shouldRevert[selector] = revert_;
  }

  modifier maybeRevert() {
    if (shouldRevert[msg.sig]) revert(REVERT_MSG);
    _;
  }

  // Events
  event AddAssetCalled(
    address hub,
    address underlying,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes irData
  );

  event AddAssetWithDecimalsCalled(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes irData
  );

  event UpdateLiquidityFeeCalled(address hub, uint256 assetId, uint256 liquidityFee);

  event UpdateFeeReceiverCalled(address hub, uint256 assetId, address feeReceiver);

  event UpdateFeeConfigCalled(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  );

  event UpdateInterestRateStrategyCalled(
    address hub,
    uint256 assetId,
    address irStrategy,
    bytes irData
  );

  event UpdateInterestRateDataCalled(address hub, uint256 assetId, bytes irData);

  event UpdateReinvestmentControllerCalled(
    address hub,
    uint256 assetId,
    address reinvestmentController
  );

  event ResetAssetCapsCalled(address hub, uint256 assetId);

  event DeactivateAssetCalled(address hub, uint256 assetId);

  event HaltAssetCalled(address hub, uint256 assetId);

  event AddSpokeCalled(address hub, address spoke, uint256 assetId, IHub.SpokeConfig config);

  event AddSpokeToAssetsCalled(
    address hub,
    address spoke,
    uint256[] assetIds,
    IHub.SpokeConfig[] configs
  );

  event UpdateSpokeActiveCalled(address hub, uint256 assetId, address spoke, bool active);

  event UpdateSpokeHaltedCalled(address hub, uint256 assetId, address spoke, bool halted);

  event UpdateSpokeSupplyCapCalled(address hub, uint256 assetId, address spoke, uint256 addCap);

  event UpdateSpokeDrawCapCalled(address hub, uint256 assetId, address spoke, uint256 drawCap);

  event UpdateSpokeRiskPremiumThresholdCalled(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 riskPremiumThreshold
  );

  event UpdateSpokeCapsCalled(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  );

  event DeactivateSpokeCalled(address hub, address spoke);

  event HaltSpokeCalled(address hub, address spoke);

  event ResetSpokeCapsCalled(address hub, address spoke);

  // Implementations

  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external maybeRevert returns (uint256) {
    emit AddAssetCalled(hub, underlying, feeReceiver, liquidityFee, irStrategy, irData);
    return 0;
  }

  function addAssetWithDecimals(
    address hub,
    address underlying,
    uint8 decimals,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external maybeRevert returns (uint256) {
    emit AddAssetWithDecimalsCalled(
      hub,
      underlying,
      decimals,
      feeReceiver,
      liquidityFee,
      irStrategy,
      irData
    );
    return 0;
  }

  function updateLiquidityFee(
    address hub,
    uint256 assetId,
    uint256 liquidityFee
  ) external maybeRevert {
    emit UpdateLiquidityFeeCalled(hub, assetId, liquidityFee);
  }

  function updateFeeReceiver(
    address hub,
    uint256 assetId,
    address feeReceiver
  ) external maybeRevert {
    emit UpdateFeeReceiverCalled(hub, assetId, feeReceiver);
  }

  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external maybeRevert {
    emit UpdateFeeConfigCalled(hub, assetId, liquidityFee, feeReceiver);
  }

  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy,
    bytes calldata irData
  ) external maybeRevert {
    emit UpdateInterestRateStrategyCalled(hub, assetId, irStrategy, irData);
  }

  function updateInterestRateData(
    address hub,
    uint256 assetId,
    bytes calldata irData
  ) external maybeRevert {
    emit UpdateInterestRateDataCalled(hub, assetId, irData);
  }

  function updateReinvestmentController(
    address hub,
    uint256 assetId,
    address reinvestmentController
  ) external maybeRevert {
    emit UpdateReinvestmentControllerCalled(hub, assetId, reinvestmentController);
  }

  function resetAssetCaps(address hub, uint256 assetId) external maybeRevert {
    emit ResetAssetCapsCalled(hub, assetId);
  }

  function deactivateAsset(address hub, uint256 assetId) external maybeRevert {
    emit DeactivateAssetCalled(hub, assetId);
  }

  function haltAsset(address hub, uint256 assetId) external maybeRevert {
    emit HaltAssetCalled(hub, assetId);
  }

  function addSpoke(
    address hub,
    address spoke,
    uint256 assetId,
    IHub.SpokeConfig calldata config
  ) external maybeRevert {
    emit AddSpokeCalled(hub, spoke, assetId, config);
  }

  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    IHub.SpokeConfig[] calldata configs
  ) external maybeRevert {
    emit AddSpokeToAssetsCalled(hub, spoke, assetIds, configs);
  }

  function updateSpokeActive(
    address hub,
    uint256 assetId,
    address spoke,
    bool active
  ) external maybeRevert {
    emit UpdateSpokeActiveCalled(hub, assetId, spoke, active);
  }

  function updateSpokeHalted(
    address hub,
    uint256 assetId,
    address spoke,
    bool halted
  ) external maybeRevert {
    emit UpdateSpokeHaltedCalled(hub, assetId, spoke, halted);
  }

  function updateSpokeSupplyCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap
  ) external maybeRevert {
    emit UpdateSpokeSupplyCapCalled(hub, assetId, spoke, addCap);
  }

  function updateSpokeDrawCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 drawCap
  ) external maybeRevert {
    emit UpdateSpokeDrawCapCalled(hub, assetId, spoke, drawCap);
  }

  function updateSpokeRiskPremiumThreshold(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 riskPremiumThreshold
  ) external maybeRevert {
    emit UpdateSpokeRiskPremiumThresholdCalled(hub, assetId, spoke, riskPremiumThreshold);
  }

  function updateSpokeCaps(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external maybeRevert {
    emit UpdateSpokeCapsCalled(hub, assetId, spoke, addCap, drawCap);
  }

  function deactivateSpoke(address hub, address spoke) external maybeRevert {
    emit DeactivateSpokeCalled(hub, spoke);
  }

  function haltSpoke(address hub, address spoke) external maybeRevert {
    emit HaltSpokeCalled(hub, spoke);
  }

  function resetSpokeCaps(address hub, address spoke) external maybeRevert {
    emit ResetSpokeCapsCalled(hub, spoke);
  }
}
