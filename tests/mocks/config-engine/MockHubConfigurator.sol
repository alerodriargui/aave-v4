// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

contract MockHubConfigurator is IHubConfigurator {
  mapping(bytes4 => bool) public shouldRevert;

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

  error AddAssetReverted();
  error AddAssetWithDecimalsReverted();
  error UpdateLiquidityFeeReverted();
  error UpdateFeeReceiverReverted();
  error UpdateFeeConfigReverted();
  error UpdateInterestRateStrategyReverted();
  error UpdateInterestRateDataReverted();
  error UpdateReinvestmentControllerReverted();
  error ResetAssetCapsReverted();
  error DeactivateAssetReverted();
  error HaltAssetReverted();
  error AddSpokeReverted();
  error AddSpokeToAssetsReverted();
  error UpdateSpokeActiveReverted();
  error UpdateSpokeHaltedReverted();
  error UpdateSpokeSupplyCapReverted();
  error UpdateSpokeDrawCapReverted();
  error UpdateSpokeRiskPremiumThresholdReverted();
  error UpdateSpokeCapsReverted();
  error DeactivateSpokeReverted();
  error HaltSpokeReverted();
  error ResetSpokeCapsReverted();

  function setShouldRevert(bytes4 selector, bool revert_) external {
    shouldRevert[selector] = revert_;
  }

  function addAsset(
    address hub,
    address underlying,
    address feeReceiver,
    uint256 liquidityFee,
    address irStrategy,
    bytes calldata irData
  ) external returns (uint256) {
    if (shouldRevert[msg.sig]) revert AddAssetReverted();
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
  ) external returns (uint256) {
    if (shouldRevert[msg.sig]) revert AddAssetWithDecimalsReverted();
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

  function updateLiquidityFee(address hub, uint256 assetId, uint256 liquidityFee) external {
    if (shouldRevert[msg.sig]) revert UpdateLiquidityFeeReverted();
    emit UpdateLiquidityFeeCalled(hub, assetId, liquidityFee);
  }

  function updateFeeReceiver(address hub, uint256 assetId, address feeReceiver) external {
    if (shouldRevert[msg.sig]) revert UpdateFeeReceiverReverted();
    emit UpdateFeeReceiverCalled(hub, assetId, feeReceiver);
  }

  function updateFeeConfig(
    address hub,
    uint256 assetId,
    uint256 liquidityFee,
    address feeReceiver
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateFeeConfigReverted();
    emit UpdateFeeConfigCalled(hub, assetId, liquidityFee, feeReceiver);
  }

  function updateInterestRateStrategy(
    address hub,
    uint256 assetId,
    address irStrategy,
    bytes calldata irData
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateInterestRateStrategyReverted();
    emit UpdateInterestRateStrategyCalled(hub, assetId, irStrategy, irData);
  }

  function updateInterestRateData(address hub, uint256 assetId, bytes calldata irData) external {
    if (shouldRevert[msg.sig]) revert UpdateInterestRateDataReverted();
    emit UpdateInterestRateDataCalled(hub, assetId, irData);
  }

  function updateReinvestmentController(
    address hub,
    uint256 assetId,
    address reinvestmentController
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateReinvestmentControllerReverted();
    emit UpdateReinvestmentControllerCalled(hub, assetId, reinvestmentController);
  }

  function resetAssetCaps(address hub, uint256 assetId) external {
    if (shouldRevert[msg.sig]) revert ResetAssetCapsReverted();
    emit ResetAssetCapsCalled(hub, assetId);
  }

  function deactivateAsset(address hub, uint256 assetId) external {
    if (shouldRevert[msg.sig]) revert DeactivateAssetReverted();
    emit DeactivateAssetCalled(hub, assetId);
  }

  function haltAsset(address hub, uint256 assetId) external {
    if (shouldRevert[msg.sig]) revert HaltAssetReverted();
    emit HaltAssetCalled(hub, assetId);
  }

  function addSpoke(
    address hub,
    address spoke,
    uint256 assetId,
    IHub.SpokeConfig calldata config
  ) external {
    if (shouldRevert[msg.sig]) revert AddSpokeReverted();
    emit AddSpokeCalled(hub, spoke, assetId, config);
  }

  function addSpokeToAssets(
    address hub,
    address spoke,
    uint256[] calldata assetIds,
    IHub.SpokeConfig[] calldata configs
  ) external {
    if (shouldRevert[msg.sig]) revert AddSpokeToAssetsReverted();
    emit AddSpokeToAssetsCalled(hub, spoke, assetIds, configs);
  }

  function updateSpokeActive(address hub, uint256 assetId, address spoke, bool active) external {
    if (shouldRevert[msg.sig]) revert UpdateSpokeActiveReverted();
    emit UpdateSpokeActiveCalled(hub, assetId, spoke, active);
  }

  function updateSpokeHalted(address hub, uint256 assetId, address spoke, bool halted) external {
    if (shouldRevert[msg.sig]) revert UpdateSpokeHaltedReverted();
    emit UpdateSpokeHaltedCalled(hub, assetId, spoke, halted);
  }

  function updateSpokeSupplyCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateSpokeSupplyCapReverted();
    emit UpdateSpokeSupplyCapCalled(hub, assetId, spoke, addCap);
  }

  function updateSpokeDrawCap(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 drawCap
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateSpokeDrawCapReverted();
    emit UpdateSpokeDrawCapCalled(hub, assetId, spoke, drawCap);
  }

  function updateSpokeRiskPremiumThreshold(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 riskPremiumThreshold
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateSpokeRiskPremiumThresholdReverted();
    emit UpdateSpokeRiskPremiumThresholdCalled(hub, assetId, spoke, riskPremiumThreshold);
  }

  function updateSpokeCaps(
    address hub,
    uint256 assetId,
    address spoke,
    uint256 addCap,
    uint256 drawCap
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateSpokeCapsReverted();
    emit UpdateSpokeCapsCalled(hub, assetId, spoke, addCap, drawCap);
  }

  function deactivateSpoke(address hub, address spoke) external {
    if (shouldRevert[msg.sig]) revert DeactivateSpokeReverted();
    emit DeactivateSpokeCalled(hub, spoke);
  }

  function haltSpoke(address hub, address spoke) external {
    if (shouldRevert[msg.sig]) revert HaltSpokeReverted();
    emit HaltSpokeCalled(hub, spoke);
  }

  function resetSpokeCaps(address hub, address spoke) external {
    if (shouldRevert[msg.sig]) revert ResetSpokeCapsReverted();
    emit ResetSpokeCapsCalled(hub, spoke);
  }
}
