// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/EngineFlags.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {MockHubConfigurator} from 'tests/mocks/config-engine/MockHubConfigurator.sol';

contract HubEngineTest is BaseConfigEngineTest {
  function test_executeHubAssetListings_decimalsZero() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddAssetCalled(
      HUB,
      UNDERLYING,
      FEE_RECEIVER,
      LIQUIDITY_FEE,
      IR_STRATEGY,
      IR_DATA
    );

    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_decimalsNonZero() public {
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.decimals = 18;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddAssetWithDecimalsCalled(
      HUB,
      UNDERLYING,
      18,
      FEE_RECEIVER,
      LIQUIDITY_FEE,
      IR_STRATEGY,
      IR_DATA
    );

    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function testFuzz_executeHubAssetListings(uint256 decimals) public {
    decimals = bound(decimals, 0, 255);
    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.decimals = decimals;

    if (decimals == 0) {
      vm.expectEmit(address(mockHubConfigurator));
      emit MockHubConfigurator.AddAssetCalled(
        HUB,
        UNDERLYING,
        FEE_RECEIVER,
        LIQUIDITY_FEE,
        IR_STRATEGY,
        IR_DATA
      );
    } else {
      vm.expectEmit(address(mockHubConfigurator));
      emit MockHubConfigurator.AddAssetWithDecimalsCalled(
        HUB,
        UNDERLYING,
        uint8(decimals),
        FEE_RECEIVER,
        LIQUIDITY_FEE,
        IR_STRATEGY,
        IR_DATA
      );
    }

    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addAsset.selector, true);

    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();

    vm.expectRevert(MockHubConfigurator.AddAssetReverted.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubAssetListings_revertWithDecimals() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addAssetWithDecimals.selector, true);

    IAaveV4ConfigEngine.AssetListing memory listing = _defaultAssetListing();
    listing.decimals = 18;

    vm.expectRevert(MockHubConfigurator.AddAssetWithDecimalsReverted.selector);
    engine.executeHubAssetListings(_toAssetListingArray(listing));
  }

  function test_executeHubFeeConfigUpdates_both() public {
    IAaveV4ConfigEngine.FeeConfigUpdate memory update = _defaultFeeConfigUpdate();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(HUB, ASSET_ID, LIQUIDITY_FEE, FEE_RECEIVER);

    engine.executeHubFeeConfigUpdates(_toFeeConfigUpdateArray(update));
  }

  function test_executeHubFeeConfigUpdates_feeOnly() public {
    IAaveV4ConfigEngine.FeeConfigUpdate memory update = _defaultFeeConfigUpdate();
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateLiquidityFeeCalled(HUB, ASSET_ID, LIQUIDITY_FEE);

    engine.executeHubFeeConfigUpdates(_toFeeConfigUpdateArray(update));
  }

  function test_executeHubFeeConfigUpdates_receiverOnly() public {
    IAaveV4ConfigEngine.FeeConfigUpdate memory update = _defaultFeeConfigUpdate();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeReceiverCalled(HUB, ASSET_ID, FEE_RECEIVER);

    engine.executeHubFeeConfigUpdates(_toFeeConfigUpdateArray(update));
  }

  function test_executeHubFeeConfigUpdates_neither() public {
    IAaveV4ConfigEngine.FeeConfigUpdate memory update = _defaultFeeConfigUpdate();
    update.liquidityFee = EngineFlags.KEEP_CURRENT;
    update.feeReceiver = EngineFlags.KEEP_CURRENT_ADDRESS;

    // No event expected; should be a no-op
    vm.recordLogs();
    engine.executeHubFeeConfigUpdates(_toFeeConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubFeeConfigUpdates(uint256 fee, address receiver) public {
    vm.assume(fee != EngineFlags.KEEP_CURRENT);
    vm.assume(receiver != EngineFlags.KEEP_CURRENT_ADDRESS);
    vm.assume(receiver != address(0));

    IAaveV4ConfigEngine.FeeConfigUpdate memory update = _defaultFeeConfigUpdate();
    update.liquidityFee = fee;
    update.feeReceiver = receiver;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(HUB, ASSET_ID, fee, receiver);

    engine.executeHubFeeConfigUpdates(_toFeeConfigUpdateArray(update));
  }

  function test_executeHubFeeConfigUpdates_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateFeeConfig.selector, true);

    IAaveV4ConfigEngine.FeeConfigUpdate memory update = _defaultFeeConfigUpdate();

    vm.expectRevert(MockHubConfigurator.UpdateFeeConfigReverted.selector);
    engine.executeHubFeeConfigUpdates(_toFeeConfigUpdateArray(update));
  }

  function test_executeHubInterestRateUpdates_strategyChange() public {
    IAaveV4ConfigEngine.InterestRateUpdate memory update = _defaultInterestRateUpdate();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(HUB, ASSET_ID, IR_STRATEGY, IR_DATA);

    engine.executeHubInterestRateUpdates(_toInterestRateUpdateArray(update));
  }

  function test_executeHubInterestRateUpdates_dataOnly() public {
    IAaveV4ConfigEngine.InterestRateUpdate memory update = _defaultInterestRateUpdate();
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    // irData is non-empty from default

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateDataCalled(HUB, ASSET_ID, IR_DATA);

    engine.executeHubInterestRateUpdates(_toInterestRateUpdateArray(update));
  }

  function test_executeHubInterestRateUpdates_noOp() public {
    IAaveV4ConfigEngine.InterestRateUpdate memory update = _defaultInterestRateUpdate();
    update.irStrategy = EngineFlags.KEEP_CURRENT_ADDRESS;
    update.irData = '';

    // No event expected; should be a no-op
    vm.recordLogs();
    engine.executeHubInterestRateUpdates(_toInterestRateUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubInterestRateUpdates(address strategy) public {
    vm.assume(strategy != EngineFlags.KEEP_CURRENT_ADDRESS);
    vm.assume(strategy != address(0));

    IAaveV4ConfigEngine.InterestRateUpdate memory update = _defaultInterestRateUpdate();
    update.irStrategy = strategy;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(HUB, ASSET_ID, strategy, IR_DATA);

    engine.executeHubInterestRateUpdates(_toInterestRateUpdateArray(update));
  }

  function test_executeHubInterestRateUpdates_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateInterestRateStrategy.selector, true);

    IAaveV4ConfigEngine.InterestRateUpdate memory update = _defaultInterestRateUpdate();

    vm.expectRevert(MockHubConfigurator.UpdateInterestRateStrategyReverted.selector);
    engine.executeHubInterestRateUpdates(_toInterestRateUpdateArray(update));
  }

  function test_executeHubSpokeCapsUpdates_both() public {
    IAaveV4ConfigEngine.SpokeCapsUpdate memory update = _defaultSpokeCapsUpdate();

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(HUB, ASSET_ID, SPOKE, 1000, 500);

    engine.executeHubSpokeCapsUpdates(_toSpokeCapsUpdateArray(update));
  }

  function test_executeHubSpokeCapsUpdates_addCapOnly() public {
    IAaveV4ConfigEngine.SpokeCapsUpdate memory update = _defaultSpokeCapsUpdate();
    update.drawCap = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeSupplyCapCalled(HUB, ASSET_ID, SPOKE, 1000);

    engine.executeHubSpokeCapsUpdates(_toSpokeCapsUpdateArray(update));
  }

  function test_executeHubSpokeCapsUpdates_drawCapOnly() public {
    IAaveV4ConfigEngine.SpokeCapsUpdate memory update = _defaultSpokeCapsUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeDrawCapCalled(HUB, ASSET_ID, SPOKE, 500);

    engine.executeHubSpokeCapsUpdates(_toSpokeCapsUpdateArray(update));
  }

  function test_executeHubSpokeCapsUpdates_neither() public {
    IAaveV4ConfigEngine.SpokeCapsUpdate memory update = _defaultSpokeCapsUpdate();
    update.addCap = EngineFlags.KEEP_CURRENT;
    update.drawCap = EngineFlags.KEEP_CURRENT;

    vm.recordLogs();
    engine.executeHubSpokeCapsUpdates(_toSpokeCapsUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubSpokeCapsUpdates(uint256 addCap, uint256 drawCap) public {
    vm.assume(addCap != EngineFlags.KEEP_CURRENT);
    vm.assume(drawCap != EngineFlags.KEEP_CURRENT);

    IAaveV4ConfigEngine.SpokeCapsUpdate memory update = _defaultSpokeCapsUpdate();
    update.addCap = addCap;
    update.drawCap = drawCap;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(HUB, ASSET_ID, SPOKE, addCap, drawCap);

    engine.executeHubSpokeCapsUpdates(_toSpokeCapsUpdateArray(update));
  }

  function test_executeHubSpokeCapsUpdates_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateSpokeCaps.selector, true);

    IAaveV4ConfigEngine.SpokeCapsUpdate memory update = _defaultSpokeCapsUpdate();

    vm.expectRevert(MockHubConfigurator.UpdateSpokeCapsReverted.selector);
    engine.executeHubSpokeCapsUpdates(_toSpokeCapsUpdateArray(update));
  }

  function test_executeHubSpokeStatusUpdates_both() public {
    IAaveV4ConfigEngine.SpokeStatusUpdate memory update = _defaultSpokeStatusUpdate();
    // active=ENABLED, halted=DISABLED from default

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(HUB, ASSET_ID, SPOKE, true);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(HUB, ASSET_ID, SPOKE, false);

    engine.executeHubSpokeStatusUpdates(_toSpokeStatusUpdateArray(update));
  }

  function test_executeHubSpokeStatusUpdates_activeOnly() public {
    IAaveV4ConfigEngine.SpokeStatusUpdate memory update = _defaultSpokeStatusUpdate();
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(HUB, ASSET_ID, SPOKE, true);

    vm.recordLogs();
    engine.executeHubSpokeStatusUpdates(_toSpokeStatusUpdateArray(update));

    // Only one event should have been emitted (UpdateSpokeActiveCalled)
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeHubSpokeStatusUpdates_haltedOnly() public {
    IAaveV4ConfigEngine.SpokeStatusUpdate memory update = _defaultSpokeStatusUpdate();
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.ENABLED;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(HUB, ASSET_ID, SPOKE, true);

    vm.recordLogs();
    engine.executeHubSpokeStatusUpdates(_toSpokeStatusUpdateArray(update));

    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeHubSpokeStatusUpdates_neither() public {
    IAaveV4ConfigEngine.SpokeStatusUpdate memory update = _defaultSpokeStatusUpdate();
    update.active = EngineFlags.KEEP_CURRENT;
    update.halted = EngineFlags.KEEP_CURRENT;

    vm.recordLogs();
    engine.executeHubSpokeStatusUpdates(_toSpokeStatusUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeHubSpokeStatusUpdates(uint256 active, uint256 halted) public {
    // Bound to valid flag values (ENABLED or DISABLED only, not KEEP_CURRENT)
    active = bound(active, 0, 1);
    halted = bound(halted, 0, 1);

    IAaveV4ConfigEngine.SpokeStatusUpdate memory update = _defaultSpokeStatusUpdate();
    update.active = active;
    update.halted = halted;

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(
      HUB,
      ASSET_ID,
      SPOKE,
      EngineFlags.toBool(active)
    );

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(
      HUB,
      ASSET_ID,
      SPOKE,
      EngineFlags.toBool(halted)
    );

    engine.executeHubSpokeStatusUpdates(_toSpokeStatusUpdateArray(update));
  }

  function test_executeHubSpokeStatusUpdates_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.updateSpokeActive.selector, true);

    IAaveV4ConfigEngine.SpokeStatusUpdate memory update = _defaultSpokeStatusUpdate();

    vm.expectRevert(MockHubConfigurator.UpdateSpokeActiveReverted.selector);
    engine.executeHubSpokeStatusUpdates(_toSpokeStatusUpdateArray(update));
  }

  function test_executeHubReinvestmentControllerUpdates() public {
    IAaveV4ConfigEngine.ReinvestmentControllerUpdate memory update = IAaveV4ConfigEngine
      .ReinvestmentControllerUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        reinvestmentController: REINVESTMENT_CONTROLLER
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(
      HUB,
      ASSET_ID,
      REINVESTMENT_CONTROLLER
    );

    engine.executeHubReinvestmentControllerUpdates(_toReinvestmentControllerUpdateArray(update));
  }

  function testFuzz_executeHubReinvestmentControllerUpdates(address controller) public {
    vm.assume(controller != address(0));

    IAaveV4ConfigEngine.ReinvestmentControllerUpdate memory update = IAaveV4ConfigEngine
      .ReinvestmentControllerUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        reinvestmentController: controller
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(HUB, ASSET_ID, controller);

    engine.executeHubReinvestmentControllerUpdates(_toReinvestmentControllerUpdateArray(update));
  }

  function test_executeHubReinvestmentControllerUpdates_revert() public {
    mockHubConfigurator.setShouldRevert(
      IHubConfigurator.updateReinvestmentController.selector,
      true
    );

    IAaveV4ConfigEngine.ReinvestmentControllerUpdate memory update = IAaveV4ConfigEngine
      .ReinvestmentControllerUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        reinvestmentController: REINVESTMENT_CONTROLLER
      });

    vm.expectRevert(MockHubConfigurator.UpdateReinvestmentControllerReverted.selector);
    engine.executeHubReinvestmentControllerUpdates(_toReinvestmentControllerUpdateArray(update));
  }

  function test_executeHubSpokeAdditions() public {
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 100,
      active: true,
      halted: false
    });

    IAaveV4ConfigEngine.SpokeAddition memory addition = IAaveV4ConfigEngine.SpokeAddition({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE,
      assetId: ASSET_ID,
      config: config
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeCalled(HUB, SPOKE, ASSET_ID, config);

    engine.executeHubSpokeAdditions(_toSpokeAdditionArray(addition));
  }

  function testFuzz_executeHubSpokeAdditions(
    uint40 addCap,
    uint40 drawCap,
    uint24 riskPremiumThreshold,
    bool active,
    bool halted
  ) public {
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: addCap,
      drawCap: drawCap,
      riskPremiumThreshold: riskPremiumThreshold,
      active: active,
      halted: halted
    });

    IAaveV4ConfigEngine.SpokeAddition memory addition = IAaveV4ConfigEngine.SpokeAddition({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE,
      assetId: ASSET_ID,
      config: config
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeCalled(HUB, SPOKE, ASSET_ID, config);

    engine.executeHubSpokeAdditions(_toSpokeAdditionArray(addition));
  }

  function test_executeHubSpokeAdditions_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addSpoke.selector, true);

    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 100,
      active: true,
      halted: false
    });

    IAaveV4ConfigEngine.SpokeAddition memory addition = IAaveV4ConfigEngine.SpokeAddition({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE,
      assetId: ASSET_ID,
      config: config
    });

    vm.expectRevert(MockHubConfigurator.AddSpokeReverted.selector);
    engine.executeHubSpokeAdditions(_toSpokeAdditionArray(addition));
  }

  function test_executeHubSpokeToAssetsAdditions() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = 1;
    assetIds[1] = 2;

    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](2);
    configs[0] = IHub.SpokeConfig({
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 100,
      active: true,
      halted: false
    });
    configs[1] = IHub.SpokeConfig({
      addCap: 2000,
      drawCap: 1000,
      riskPremiumThreshold: 200,
      active: true,
      halted: false
    });

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        spoke: SPOKE,
        assetIds: assetIds,
        configs: configs
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeToAssetsCalled(HUB, SPOKE, assetIds, configs);

    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function testFuzz_executeHubSpokeToAssetsAdditions(uint40 addCap, uint40 drawCap) public {
    uint256[] memory assetIds = new uint256[](1);
    assetIds[0] = ASSET_ID;

    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](1);
    configs[0] = IHub.SpokeConfig({
      addCap: addCap,
      drawCap: drawCap,
      riskPremiumThreshold: 100,
      active: true,
      halted: false
    });

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        spoke: SPOKE,
        assetIds: assetIds,
        configs: configs
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeToAssetsCalled(HUB, SPOKE, assetIds, configs);

    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function test_executeHubSpokeToAssetsAdditions_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.addSpokeToAssets.selector, true);

    uint256[] memory assetIds = new uint256[](1);
    assetIds[0] = ASSET_ID;

    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](1);
    configs[0] = IHub.SpokeConfig({
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 100,
      active: true,
      halted: false
    });

    IAaveV4ConfigEngine.SpokeToAssetsAddition memory addition = IAaveV4ConfigEngine
      .SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        spoke: SPOKE,
        assetIds: assetIds,
        configs: configs
      });

    vm.expectRevert(MockHubConfigurator.AddSpokeToAssetsReverted.selector);
    engine.executeHubSpokeToAssetsAdditions(_toSpokeToAssetsAdditionArray(addition));
  }

  function test_executeHubSpokeRiskPremiumThresholdUpdates() public {
    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate memory update = IAaveV4ConfigEngine
      .SpokeRiskPremiumThresholdUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        spoke: SPOKE,
        riskPremiumThreshold: 300
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(HUB, ASSET_ID, SPOKE, 300);

    engine.executeHubSpokeRiskPremiumThresholdUpdates(
      _toSpokeRiskPremiumThresholdUpdateArray(update)
    );
  }

  function testFuzz_executeHubSpokeRiskPremiumThresholdUpdates(uint256 threshold) public {
    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate memory update = IAaveV4ConfigEngine
      .SpokeRiskPremiumThresholdUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        spoke: SPOKE,
        riskPremiumThreshold: threshold
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(HUB, ASSET_ID, SPOKE, threshold);

    engine.executeHubSpokeRiskPremiumThresholdUpdates(
      _toSpokeRiskPremiumThresholdUpdateArray(update)
    );
  }

  function test_executeHubSpokeRiskPremiumThresholdUpdates_revert() public {
    mockHubConfigurator.setShouldRevert(
      IHubConfigurator.updateSpokeRiskPremiumThreshold.selector,
      true
    );

    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate memory update = IAaveV4ConfigEngine
      .SpokeRiskPremiumThresholdUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        spoke: SPOKE,
        riskPremiumThreshold: 300
      });

    vm.expectRevert(MockHubConfigurator.UpdateSpokeRiskPremiumThresholdReverted.selector);
    engine.executeHubSpokeRiskPremiumThresholdUpdates(
      _toSpokeRiskPremiumThresholdUpdateArray(update)
    );
  }

  function test_executeHubAssetHalts() public {
    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(HUB, ASSET_ID);

    engine.executeHubAssetHalts(_toAssetHaltArray(halt));
  }

  function testFuzz_executeHubAssetHalts(uint256 assetId) public {
    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: assetId
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(HUB, assetId);

    engine.executeHubAssetHalts(_toAssetHaltArray(halt));
  }

  function test_executeHubAssetHalts_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.haltAsset.selector, true);

    IAaveV4ConfigEngine.AssetHalt memory halt = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });

    vm.expectRevert(MockHubConfigurator.HaltAssetReverted.selector);
    engine.executeHubAssetHalts(_toAssetHaltArray(halt));
  }

  function test_executeHubAssetDeactivations() public {
    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateAssetCalled(HUB, ASSET_ID);

    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));
  }

  function testFuzz_executeHubAssetDeactivations(uint256 assetId) public {
    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: assetId
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateAssetCalled(HUB, assetId);

    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));
  }

  function test_executeHubAssetDeactivations_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.deactivateAsset.selector, true);

    IAaveV4ConfigEngine.AssetDeactivation memory deactivation = IAaveV4ConfigEngine
      .AssetDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID
      });

    vm.expectRevert(MockHubConfigurator.DeactivateAssetReverted.selector);
    engine.executeHubAssetDeactivations(_toAssetDeactivationArray(deactivation));
  }

  function test_executeHubAssetCapsResets() public {
    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetAssetCapsCalled(HUB, ASSET_ID);

    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));
  }

  function testFuzz_executeHubAssetCapsResets(uint256 assetId) public {
    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: assetId
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetAssetCapsCalled(HUB, assetId);

    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));
  }

  function test_executeHubAssetCapsResets_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.resetAssetCaps.selector, true);

    IAaveV4ConfigEngine.AssetCapsReset memory reset = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });

    vm.expectRevert(MockHubConfigurator.ResetAssetCapsReverted.selector);
    engine.executeHubAssetCapsResets(_toAssetCapsResetArray(reset));
  }

  function test_executeHubSpokeHalts() public {
    IAaveV4ConfigEngine.SpokeHalt memory halt = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltSpokeCalled(HUB, SPOKE);

    engine.executeHubSpokeHalts(_toSpokeHaltArray(halt));
  }

  function testFuzz_executeHubSpokeHalts(address spoke) public {
    vm.assume(spoke != address(0));

    IAaveV4ConfigEngine.SpokeHalt memory halt = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: spoke
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltSpokeCalled(HUB, spoke);

    engine.executeHubSpokeHalts(_toSpokeHaltArray(halt));
  }

  function test_executeHubSpokeHalts_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.haltSpoke.selector, true);

    IAaveV4ConfigEngine.SpokeHalt memory halt = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });

    vm.expectRevert(MockHubConfigurator.HaltSpokeReverted.selector);
    engine.executeHubSpokeHalts(_toSpokeHaltArray(halt));
  }

  function test_executeHubSpokeDeactivations() public {
    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        spoke: SPOKE
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateSpokeCalled(HUB, SPOKE);

    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));
  }

  function testFuzz_executeHubSpokeDeactivations(address spoke) public {
    vm.assume(spoke != address(0));

    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        spoke: spoke
      });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateSpokeCalled(HUB, spoke);

    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));
  }

  function test_executeHubSpokeDeactivations_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.deactivateSpoke.selector, true);

    IAaveV4ConfigEngine.SpokeDeactivation memory deactivation = IAaveV4ConfigEngine
      .SpokeDeactivation({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        spoke: SPOKE
      });

    vm.expectRevert(MockHubConfigurator.DeactivateSpokeReverted.selector);
    engine.executeHubSpokeDeactivations(_toSpokeDeactivationArray(deactivation));
  }

  function test_executeHubSpokeCapsResets() public {
    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetSpokeCapsCalled(HUB, SPOKE);

    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));
  }

  function testFuzz_executeHubSpokeCapsResets(address spoke) public {
    vm.assume(spoke != address(0));

    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: spoke
    });

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetSpokeCapsCalled(HUB, spoke);

    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));
  }

  function test_executeHubSpokeCapsResets_revert() public {
    mockHubConfigurator.setShouldRevert(IHubConfigurator.resetSpokeCaps.selector, true);

    IAaveV4ConfigEngine.SpokeCapsReset memory reset = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });

    vm.expectRevert(MockHubConfigurator.ResetSpokeCapsReverted.selector);
    engine.executeHubSpokeCapsResets(_toSpokeCapsResetArray(reset));
  }
}
