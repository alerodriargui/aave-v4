// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {VmSafe} from 'forge-std/Vm.sol';
import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';
import {AaveV4PayloadWrapper} from 'tests/mocks/config-engine/AaveV4PayloadWrapper.sol';
import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {EngineFlags} from 'src/config-engine/EngineFlags.sol';
import {Roles} from 'src/utils/libraries/Roles.sol';
import {MockHubConfigurator} from 'tests/mocks/config-engine/MockHubConfigurator.sol';
import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';
import {MockAccessManagerForEngine} from 'tests/mocks/config-engine/MockAccessManagerForEngine.sol';

contract AaveV4PayloadTest is BaseConfigEngineTest {
  AaveV4PayloadWrapper public payload;

  function setUp() public override {
    super.setUp();
    payload = new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(engine)));
  }

  function test_execute_emptyPayload_noReverts() public {
    payload.execute();
    assertTrue(payload.preExecuteCalled());
    assertTrue(payload.postExecuteCalled());
  }

  function test_execute_hookOrdering() public {
    payload.execute();
    assertTrue(payload.preExecuteCalled());
    assertTrue(payload.postExecuteCalled());
    assertLt(payload.preExecuteOrder(), payload.postExecuteOrder());
  }

  function test_execute_hubAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    payload.setHubAssetHalts(halts);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(HUB, ASSET_ID);

    payload.execute();
  }

  function test_execute_spokeAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.SpokePause[] memory pauses = new IAaveV4ConfigEngine.SpokePause[](1);
    pauses[0] = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE
    });
    payload.setSpokeAllReservesPauses(pauses);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(SPOKE);

    payload.execute();
  }

  function test_execute_accessManagerAction_delegatesCorrectly() public {
    IAaveV4ConfigEngine.RoleGrant[] memory grants = new IAaveV4ConfigEngine.RoleGrant[](1);
    grants[0] = IAaveV4ConfigEngine.RoleGrant({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      account: ACCOUNT,
      executionDelay: 100
    });
    payload.setAccessManagerRoleGrants(grants);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      ACCOUNT,
      100
    );

    payload.execute();
  }

  function test_execute_multipleActions_allExecuted() public {
    // Hub action
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    payload.setHubAssetHalts(halts);

    // Spoke action
    IAaveV4ConfigEngine.SpokePause[] memory pauses = new IAaveV4ConfigEngine.SpokePause[](1);
    pauses[0] = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE
    });
    payload.setSpokeAllReservesPauses(pauses);

    // Access manager action
    IAaveV4ConfigEngine.RoleGrant[] memory grants = new IAaveV4ConfigEngine.RoleGrant[](1);
    grants[0] = IAaveV4ConfigEngine.RoleGrant({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      account: ACCOUNT,
      executionDelay: 0
    });
    payload.setAccessManagerRoleGrants(grants);

    // Expect all 3 events
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(HUB, ASSET_ID);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(SPOKE);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      ACCOUNT,
      0
    );

    payload.execute();
  }

  function test_execute_emptyArraysSkipped() public {
    // Configure only 1 action, all others empty
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    payload.setHubAssetHalts(halts);

    // Record all emitted logs
    vm.recordLogs();
    payload.execute();

    // Only the configured action should have emitted an event (plus 2 hook tracking writes).
    // Verify the single HaltAssetCalled event was emitted by the mock.
    VmSafe.Log[] memory logs = vm.getRecordedLogs();
    bytes32 haltTopic = MockHubConfigurator.HaltAssetCalled.selector;
    uint256 haltCount;
    for (uint256 i; i < logs.length; ++i) {
      if (logs[i].topics.length > 0 && logs[i].topics[0] == haltTopic) {
        ++haltCount;
      }
    }
    assertEq(haltCount, 1);
  }

  function test_execute_revert_propagatesFromEngine() public {
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](1);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    payload.setHubAssetHalts(halts);

    mockHubConfigurator.setShouldRevert(IHubConfigurator.haltAsset.selector, true);

    vm.expectRevert(MockHubConfigurator.HaltAssetReverted.selector);
    payload.execute();
  }

  function test_configEngine_immutable() public view {
    assertEq(address(payload.CONFIG_ENGINE()), address(engine));
  }

  function test_execute_convenienceRoleGrant_viaPayload() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = new IAaveV4ConfigEngine.RoleGrantByName[](
      1
    );
    grants[0] = IAaveV4ConfigEngine.RoleGrantByName({
      authority: address(mockAccessManager),
      account: ACCOUNT
    });
    payload.setHubConfiguratorFeeUpdaterRoleGrants(grants);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      ACCOUNT,
      0
    );

    payload.execute();
  }

  function test_execute_hubAssetListings() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    payload.setHubAssetListings(listings);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddAssetCalled(
      HUB,
      UNDERLYING,
      FEE_RECEIVER,
      LIQUIDITY_FEE,
      IR_STRATEGY,
      IR_DATA
    );

    payload.execute();
  }

  function test_execute_hubFeeConfigUpdates() public {
    IAaveV4ConfigEngine.FeeConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.FeeConfigUpdate[](1);
    updates[0] = _defaultFeeConfigUpdate();
    payload.setHubFeeConfigUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateFeeConfigCalled(HUB, ASSET_ID, LIQUIDITY_FEE, FEE_RECEIVER);

    payload.execute();
  }

  function test_execute_hubInterestRateUpdates() public {
    IAaveV4ConfigEngine.InterestRateUpdate[]
      memory updates = new IAaveV4ConfigEngine.InterestRateUpdate[](1);
    updates[0] = _defaultInterestRateUpdate();
    payload.setHubInterestRateUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateInterestRateStrategyCalled(HUB, ASSET_ID, IR_STRATEGY, IR_DATA);

    payload.execute();
  }

  function test_execute_hubReinvestmentControllerUpdates() public {
    IAaveV4ConfigEngine.ReinvestmentControllerUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReinvestmentControllerUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.ReinvestmentControllerUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID,
      reinvestmentController: REINVESTMENT_CONTROLLER
    });
    payload.setHubReinvestmentControllerUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateReinvestmentControllerCalled(
      HUB,
      ASSET_ID,
      REINVESTMENT_CONTROLLER
    );

    payload.execute();
  }

  function test_execute_hubSpokeAdditions() public {
    IAaveV4ConfigEngine.SpokeAddition[] memory additions = new IAaveV4ConfigEngine.SpokeAddition[](
      1
    );
    IHub.SpokeConfig memory config = IHub.SpokeConfig({
      addCap: 1000,
      drawCap: 500,
      riskPremiumThreshold: 100,
      active: true,
      halted: false
    });
    additions[0] = IAaveV4ConfigEngine.SpokeAddition({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE,
      assetId: ASSET_ID,
      config: config
    });
    payload.setHubSpokeAdditions(additions);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeCalled(HUB, SPOKE, ASSET_ID, config);

    payload.execute();
  }

  function test_execute_hubSpokeToAssetsAdditions() public {
    IAaveV4ConfigEngine.SpokeToAssetsAddition[]
      memory additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](1);
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
    additions[0] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE,
      assetIds: assetIds,
      configs: configs
    });
    payload.setHubSpokeToAssetsAdditions(additions);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.AddSpokeToAssetsCalled(HUB, SPOKE, assetIds, configs);

    payload.execute();
  }

  function test_execute_hubSpokeCapsUpdates() public {
    IAaveV4ConfigEngine.SpokeCapsUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeCapsUpdate[](1);
    updates[0] = _defaultSpokeCapsUpdate();
    payload.setHubSpokeCapsUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeCapsCalled(HUB, ASSET_ID, SPOKE, 1000, 500);

    payload.execute();
  }

  function test_execute_hubSpokeRiskPremiumThresholdUpdates() public {
    IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.SpokeRiskPremiumThresholdUpdate({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID,
      spoke: SPOKE,
      riskPremiumThreshold: 200
    });
    payload.setHubSpokeRiskPremiumThresholdUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeRiskPremiumThresholdCalled(HUB, ASSET_ID, SPOKE, 200);

    payload.execute();
  }

  function test_execute_hubSpokeStatusUpdates() public {
    IAaveV4ConfigEngine.SpokeStatusUpdate[]
      memory updates = new IAaveV4ConfigEngine.SpokeStatusUpdate[](1);
    updates[0] = _defaultSpokeStatusUpdate();
    payload.setHubSpokeStatusUpdates(updates);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeActiveCalled(HUB, ASSET_ID, SPOKE, true);
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.UpdateSpokeHaltedCalled(HUB, ASSET_ID, SPOKE, false);

    payload.execute();
  }

  function test_execute_hubAssetDeactivations() public {
    IAaveV4ConfigEngine.AssetDeactivation[]
      memory deactivations = new IAaveV4ConfigEngine.AssetDeactivation[](1);
    deactivations[0] = IAaveV4ConfigEngine.AssetDeactivation({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    payload.setHubAssetDeactivations(deactivations);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateAssetCalled(HUB, ASSET_ID);

    payload.execute();
  }

  function test_execute_hubAssetCapsResets() public {
    IAaveV4ConfigEngine.AssetCapsReset[] memory resets = new IAaveV4ConfigEngine.AssetCapsReset[](
      1
    );
    resets[0] = IAaveV4ConfigEngine.AssetCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    payload.setHubAssetCapsResets(resets);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetAssetCapsCalled(HUB, ASSET_ID);

    payload.execute();
  }

  function test_execute_hubSpokeHalts() public {
    IAaveV4ConfigEngine.SpokeHalt[] memory halts = new IAaveV4ConfigEngine.SpokeHalt[](1);
    halts[0] = IAaveV4ConfigEngine.SpokeHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });
    payload.setHubSpokeHalts(halts);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltSpokeCalled(HUB, SPOKE);

    payload.execute();
  }

  function test_execute_hubSpokeDeactivations() public {
    IAaveV4ConfigEngine.SpokeDeactivation[]
      memory deactivations = new IAaveV4ConfigEngine.SpokeDeactivation[](1);
    deactivations[0] = IAaveV4ConfigEngine.SpokeDeactivation({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });
    payload.setHubSpokeDeactivations(deactivations);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.DeactivateSpokeCalled(HUB, SPOKE);

    payload.execute();
  }

  function test_execute_hubSpokeCapsResets() public {
    IAaveV4ConfigEngine.SpokeCapsReset[] memory resets = new IAaveV4ConfigEngine.SpokeCapsReset[](
      1
    );
    resets[0] = IAaveV4ConfigEngine.SpokeCapsReset({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      spoke: SPOKE
    });
    payload.setHubSpokeCapsResets(resets);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.ResetSpokeCapsCalled(HUB, SPOKE);

    payload.execute();
  }

  function test_execute_spokeReserveListings() public {
    IAaveV4ConfigEngine.ReserveListing[] memory listings = new IAaveV4ConfigEngine.ReserveListing[](
      1
    );
    listings[0] = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      hub: HUB,
      assetId: ASSET_ID,
      priceSource: PRICE_SOURCE,
      config: ISpoke.ReserveConfig({
        collateralRisk: 5000,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 8000,
        maxLiquidationBonus: 10500,
        liquidationFee: 1000
      })
    });
    payload.setSpokeReserveListings(listings);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddReserveCalled(
      SPOKE,
      HUB,
      ASSET_ID,
      PRICE_SOURCE,
      5000,
      false,
      false,
      true,
      true,
      8000,
      10500,
      1000
    );

    payload.execute();
  }

  function test_execute_spokeReserveConfigUpdates() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = _defaultReserveConfigUpdate();
    payload.setSpokeReserveConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, 5000);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePausedCalled(SPOKE, RESERVE_ID, false);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateFrozenCalled(SPOKE, RESERVE_ID, false);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateBorrowableCalled(SPOKE, RESERVE_ID, true);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReceiveSharesEnabledCalled(SPOKE, RESERVE_ID, true);

    payload.execute();
  }

  function test_execute_spokeReservePriceSourceUpdates() public {
    IAaveV4ConfigEngine.ReservePriceSourceUpdate[]
      memory updates = new IAaveV4ConfigEngine.ReservePriceSourceUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.ReservePriceSourceUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      priceSource: PRICE_SOURCE
    });
    payload.setSpokeReservePriceSourceUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(SPOKE, RESERVE_ID, PRICE_SOURCE);

    payload.execute();
  }

  function test_execute_spokeLiquidationConfigUpdates() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    updates[0] = _defaultLiquidationConfigUpdate();
    payload.setSpokeLiquidationConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(1.05e18),
      uint64(0.95e18),
      uint16(10000)
    );

    payload.execute();
  }

  function test_execute_spokeDynamicReserveConfigAdditions() public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[]
      memory additions = new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](1);
    additions[0] = IAaveV4ConfigEngine.DynamicReserveConfigAddition({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 8000,
        maxLiquidationBonus: 10500,
        liquidationFee: 1000
      })
    });
    payload.setSpokeDynamicReserveConfigAdditions(additions);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddDynamicReserveConfigCalled(SPOKE, RESERVE_ID, 8000, 10500, 1000);

    payload.execute();
  }

  function test_execute_spokeDynamicReserveConfigUpdates() public {
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[]
      memory updates = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    updates[0] = _defaultDynamicReserveConfigUpdate();
    payload.setSpokeDynamicReserveConfigUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      8000,
      10500,
      1000
    );

    payload.execute();
  }

  function test_execute_spokeCollateralFactorAdditions() public {
    IAaveV4ConfigEngine.CollateralFactorAddition[]
      memory additions = new IAaveV4ConfigEngine.CollateralFactorAddition[](1);
    additions[0] = IAaveV4ConfigEngine.CollateralFactorAddition({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      collateralFactor: 8000
    });
    payload.setSpokeCollateralFactorAdditions(additions);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddCollateralFactorCalled(SPOKE, RESERVE_ID, 8000);

    payload.execute();
  }

  function test_execute_spokeCollateralFactorUpdates() public {
    IAaveV4ConfigEngine.CollateralFactorUpdate[]
      memory updates = new IAaveV4ConfigEngine.CollateralFactorUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.CollateralFactorUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      dynamicConfigKey: DYNAMIC_CONFIG_KEY,
      collateralFactor: 8000
    });
    payload.setSpokeCollateralFactorUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralFactorCalled(
      SPOKE,
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      8000
    );

    payload.execute();
  }

  function test_execute_spokeMaxLiquidationBonusAdditions() public {
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition[]
      memory additions = new IAaveV4ConfigEngine.MaxLiquidationBonusAddition[](1);
    additions[0] = IAaveV4ConfigEngine.MaxLiquidationBonusAddition({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      maxLiquidationBonus: 10500
    });
    payload.setSpokeMaxLiquidationBonusAdditions(additions);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddMaxLiquidationBonusCalled(SPOKE, RESERVE_ID, 10500);

    payload.execute();
  }

  function test_execute_spokeMaxLiquidationBonusUpdates() public {
    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[]
      memory updates = new IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.MaxLiquidationBonusUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      dynamicConfigKey: DYNAMIC_CONFIG_KEY,
      maxLiquidationBonus: 10500
    });
    payload.setSpokeMaxLiquidationBonusUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateMaxLiquidationBonusCalled(
      SPOKE,
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      10500
    );

    payload.execute();
  }

  function test_execute_spokeLiquidationFeeAdditions() public {
    IAaveV4ConfigEngine.LiquidationFeeAddition[]
      memory additions = new IAaveV4ConfigEngine.LiquidationFeeAddition[](1);
    additions[0] = IAaveV4ConfigEngine.LiquidationFeeAddition({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      liquidationFee: 1000
    });
    payload.setSpokeLiquidationFeeAdditions(additions);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddLiquidationFeeCalled(SPOKE, RESERVE_ID, 1000);

    payload.execute();
  }

  function test_execute_spokeLiquidationFeeUpdates() public {
    IAaveV4ConfigEngine.LiquidationFeeUpdate[]
      memory updates = new IAaveV4ConfigEngine.LiquidationFeeUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.LiquidationFeeUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID,
      dynamicConfigKey: DYNAMIC_CONFIG_KEY,
      liquidationFee: 1000
    });
    payload.setSpokeLiquidationFeeUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationFeeCalled(
      SPOKE,
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      1000
    );

    payload.execute();
  }

  function test_execute_spokeAllReservesFreezes() public {
    IAaveV4ConfigEngine.SpokeFreeze[] memory freezes = new IAaveV4ConfigEngine.SpokeFreeze[](1);
    freezes[0] = IAaveV4ConfigEngine.SpokeFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE
    });
    payload.setSpokeAllReservesFreezes(freezes);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeAllReservesCalled(SPOKE);

    payload.execute();
  }

  function test_execute_spokeReservePauses() public {
    IAaveV4ConfigEngine.ReservePause[] memory pauses = new IAaveV4ConfigEngine.ReservePause[](1);
    pauses[0] = IAaveV4ConfigEngine.ReservePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID
    });
    payload.setSpokeReservePauses(pauses);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseReserveCalled(SPOKE, RESERVE_ID);

    payload.execute();
  }

  function test_execute_spokeReserveFreezes() public {
    IAaveV4ConfigEngine.ReserveFreeze[] memory freezes = new IAaveV4ConfigEngine.ReserveFreeze[](1);
    freezes[0] = IAaveV4ConfigEngine.ReserveFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID
    });
    payload.setSpokeReserveFreezes(freezes);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeReserveCalled(SPOKE, RESERVE_ID);

    payload.execute();
  }

  function test_execute_spokePositionManagerUpdates() public {
    IAaveV4ConfigEngine.PositionManagerUpdate[]
      memory updates = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      positionManager: POSITION_MANAGER,
      active: true
    });
    payload.setSpokePositionManagerUpdates(updates);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePositionManagerCalled(SPOKE, POSITION_MANAGER, true);

    payload.execute();
  }

  function test_execute_accessManagerRoleRevocations() public {
    IAaveV4ConfigEngine.RoleRevocation[]
      memory revocations = new IAaveV4ConfigEngine.RoleRevocation[](1);
    revocations[0] = IAaveV4ConfigEngine.RoleRevocation({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      account: ACCOUNT
    });
    payload.setAccessManagerRoleRevocations(revocations);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.RevokeRoleCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      ACCOUNT
    );

    payload.execute();
  }

  function test_execute_accessManagerRoleAdminUpdates() public {
    IAaveV4ConfigEngine.RoleAdminUpdate[]
      memory updates = new IAaveV4ConfigEngine.RoleAdminUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.RoleAdminUpdate({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      admin: Roles.HUB_CONFIGURATOR_ROLE
    });
    payload.setAccessManagerRoleAdminUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetRoleAdminCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      Roles.HUB_CONFIGURATOR_ROLE
    );

    payload.execute();
  }

  function test_execute_accessManagerRoleGuardianUpdates() public {
    IAaveV4ConfigEngine.RoleGuardianUpdate[]
      memory updates = new IAaveV4ConfigEngine.RoleGuardianUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.RoleGuardianUpdate({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      guardian: Roles.HUB_FEE_MINTER_ROLE
    });
    payload.setAccessManagerRoleGuardianUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetRoleGuardianCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      Roles.HUB_FEE_MINTER_ROLE
    );

    payload.execute();
  }

  function test_execute_accessManagerTargetFunctionRoleUpdates() public {
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](1);
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(0xdeadbeef);
    updates[0] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
      authority: address(mockAccessManager),
      target: TARGET,
      selectors: selectors,
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE
    });
    payload.setAccessManagerTargetFunctionRoleUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetTargetFunctionRoleCalled(
      TARGET,
      selectors,
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE
    );

    payload.execute();
  }

  function test_execute_accessManagerTargetClosedUpdates() public {
    IAaveV4ConfigEngine.TargetClosedUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetClosedUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.TargetClosedUpdate({
      authority: address(mockAccessManager),
      target: TARGET,
      closed: true
    });
    payload.setAccessManagerTargetClosedUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetTargetClosedCalled(TARGET, true);

    payload.execute();
  }

  function test_execute_accessManagerRoleLabelUpdates() public {
    IAaveV4ConfigEngine.RoleLabelUpdate[]
      memory updates = new IAaveV4ConfigEngine.RoleLabelUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.RoleLabelUpdate({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      label: 'FEE_UPDATER'
    });
    payload.setAccessManagerRoleLabelUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.LabelRoleCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      'FEE_UPDATER'
    );

    payload.execute();
  }

  function test_execute_accessManagerGrantDelayUpdates() public {
    IAaveV4ConfigEngine.GrantDelayUpdate[]
      memory updates = new IAaveV4ConfigEngine.GrantDelayUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.GrantDelayUpdate({
      authority: address(mockAccessManager),
      roleId: Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      newDelay: 3600
    });
    payload.setAccessManagerGrantDelayUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetGrantDelayCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      3600
    );

    payload.execute();
  }

  function test_execute_accessManagerTargetAdminDelayUpdates() public {
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[]
      memory updates = new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](1);
    updates[0] = IAaveV4ConfigEngine.TargetAdminDelayUpdate({
      authority: address(mockAccessManager),
      target: TARGET,
      newDelay: 7200
    });
    payload.setAccessManagerTargetAdminDelayUpdates(updates);

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetTargetAdminDelayCalled(TARGET, 7200);

    payload.execute();
  }

  function _makeRoleGrantByName()
    internal
    view
    returns (IAaveV4ConfigEngine.RoleGrantByName[] memory)
  {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = new IAaveV4ConfigEngine.RoleGrantByName[](
      1
    );
    grants[0] = IAaveV4ConfigEngine.RoleGrantByName({
      authority: address(mockAccessManager),
      account: ACCOUNT
    });
    return grants;
  }

  function test_execute_hubConfiguratorReinvestmentUpdaterRoleGrants() public {
    payload.setHubConfiguratorReinvestmentUpdaterRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_hubConfiguratorAssetListerRoleGrants() public {
    payload.setHubConfiguratorAssetListerRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_hubConfiguratorSpokeAdderRoleGrants() public {
    payload.setHubConfiguratorSpokeAdderRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_hubConfiguratorInterestRateUpdaterRoleGrants() public {
    payload.setHubConfiguratorInterestRateUpdaterRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_hubConfiguratorHalterRoleGrants() public {
    payload.setHubConfiguratorHalterRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(Roles.HUB_CONFIGURATOR_HALTER_ROLE, ACCOUNT, 0);
    payload.execute();
  }

  function test_execute_hubConfiguratorDeactivaterRoleGrants() public {
    payload.setHubConfiguratorDeactivaterRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_hubConfiguratorCapsUpdaterRoleGrants() public {
    payload.setHubConfiguratorCapsUpdaterRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_hubConfiguratorAllRoleGrants() public {
    payload.setHubConfiguratorAllRoleGrants(_makeRoleGrantByName());
    // AllRoles grants 8 roles in order: FEE_UPDATER, REINVESTMENT, ASSET_LISTER, SPOKE_ADDER,
    //   INTEREST_RATE, HALTER, DEACTIVATER, CAPS_UPDATER
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(Roles.HUB_CONFIGURATOR_HALTER_ROLE, ACCOUNT, 0);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_spokeConfiguratorAdminRoleGrants() public {
    payload.setSpokeConfiguratorAdminRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_spokeConfiguratorLiquidationUpdaterRoleGrants() public {
    payload.setSpokeConfiguratorLiquidationUpdaterRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_spokeConfiguratorReserveAdderRoleGrants() public {
    payload.setSpokeConfiguratorReserveAdderRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_spokeConfiguratorFreezerRoleGrants() public {
    payload.setSpokeConfiguratorFreezerRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_spokeConfiguratorPauserRoleGrants() public {
    payload.setSpokeConfiguratorPauserRoleGrants(_makeRoleGrantByName());
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_execute_spokeConfiguratorAllRoleGrants() public {
    payload.setSpokeConfiguratorAllRoleGrants(_makeRoleGrantByName());
    // AllRoles grants 5 roles in order: ADMIN, LIQUIDATION_UPDATER, RESERVE_ADDER, FREEZER, PAUSER
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
      ACCOUNT,
      0
    );
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(
      Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
      ACCOUNT,
      0
    );
    payload.execute();
  }

  function test_constructor_revertsOnZeroAddress() public {
    vm.expectRevert(AaveV4Payload.InvalidConfigEngine.selector);
    new AaveV4PayloadWrapper(IAaveV4ConfigEngine(address(0)));
  }

  function test_execute_hubAssetListings_withDecimals() public {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = _defaultAssetListing();
    listings[0].decimals = 18;
    payload.setHubAssetListings(listings);

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

    payload.execute();
  }

  function test_execute_hubAssetHalts_multiElement() public {
    address hub2 = address(0x1002);
    IAaveV4ConfigEngine.AssetHalt[] memory halts = new IAaveV4ConfigEngine.AssetHalt[](2);
    halts[0] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: HUB,
      assetId: ASSET_ID
    });
    halts[1] = IAaveV4ConfigEngine.AssetHalt({
      hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
      hub: hub2,
      assetId: ASSET_ID + 1
    });
    payload.setHubAssetHalts(halts);

    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(HUB, ASSET_ID);
    vm.expectEmit(address(mockHubConfigurator));
    emit MockHubConfigurator.HaltAssetCalled(hub2, ASSET_ID + 1);

    payload.execute();
  }

  function test_execute_spokeReservePauses_multiElement() public {
    IAaveV4ConfigEngine.ReservePause[] memory pauses = new IAaveV4ConfigEngine.ReservePause[](2);
    pauses[0] = IAaveV4ConfigEngine.ReservePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID
    });
    pauses[1] = IAaveV4ConfigEngine.ReservePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: RESERVE_ID + 1
    });
    payload.setSpokeReservePauses(pauses);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseReserveCalled(SPOKE, RESERVE_ID);
    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseReserveCalled(SPOKE, RESERVE_ID + 1);

    payload.execute();
  }
}
