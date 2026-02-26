// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/EngineFlags.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {MockHubConfigurator} from 'tests/mocks/config-engine/MockHubConfigurator.sol';
import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';
import {MockAccessManagerForEngine} from 'tests/mocks/config-engine/MockAccessManagerForEngine.sol';
import {MockSpokeReader} from 'tests/mocks/config-engine/MockSpokeReader.sol';

abstract contract BaseConfigEngineTest is Test {
  AaveV4ConfigEngine public engine;
  MockHubConfigurator public mockHubConfigurator;
  MockSpokeConfigurator public mockSpokeConfigurator;
  MockAccessManagerForEngine public mockAccessManager;
  MockSpokeReader public mockSpokeReader;

  // Common addresses
  address constant HUB = address(0x1001);
  address constant SPOKE = address(0x2001);
  address constant UNDERLYING = address(0x3001);
  address constant FEE_RECEIVER = address(0x4001);
  address constant IR_STRATEGY = address(0x5001);
  address constant PRICE_SOURCE = address(0x6001);
  address constant ACCOUNT = address(0x7001);
  address constant TARGET = address(0x8001);
  address constant POSITION_MANAGER = address(0x9001);
  address constant REINVESTMENT_CONTROLLER = address(0xA001);

  // Common values
  uint256 constant ASSET_ID = 1;
  uint256 constant RESERVE_ID = 2;
  uint256 constant LIQUIDITY_FEE = 500;
  uint256 constant DYNAMIC_CONFIG_KEY = 3;
  bytes constant IR_DATA = hex'deadbeef';

  function setUp() public virtual {
    engine = new AaveV4ConfigEngine();
    mockHubConfigurator = new MockHubConfigurator();
    mockSpokeConfigurator = new MockSpokeConfigurator();
    mockAccessManager = new MockAccessManagerForEngine();
    mockSpokeReader = new MockSpokeReader();
  }

  // Helper: default AssetListing (decimals=0 -> addAsset branch)
  function _defaultAssetListing() internal view returns (IAaveV4ConfigEngine.AssetListing memory) {
    return
      IAaveV4ConfigEngine.AssetListing({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        underlying: UNDERLYING,
        decimals: 0,
        feeReceiver: FEE_RECEIVER,
        liquidityFee: LIQUIDITY_FEE,
        irStrategy: IR_STRATEGY,
        irData: IR_DATA
      });
  }

  // Helper: default FeeConfigUpdate (both fields set)
  function _defaultFeeConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.FeeConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.FeeConfigUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        liquidityFee: LIQUIDITY_FEE,
        feeReceiver: FEE_RECEIVER
      });
  }

  // Helper: default InterestRateUpdate (strategy change)
  function _defaultInterestRateUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.InterestRateUpdate memory)
  {
    return
      IAaveV4ConfigEngine.InterestRateUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        irStrategy: IR_STRATEGY,
        irData: IR_DATA
      });
  }

  // Helper: default SpokeCapsUpdate (both caps set)
  function _defaultSpokeCapsUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.SpokeCapsUpdate memory)
  {
    return
      IAaveV4ConfigEngine.SpokeCapsUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        spoke: SPOKE,
        addCap: 1000,
        drawCap: 500
      });
  }

  // Helper: default SpokeStatusUpdate (both set)
  function _defaultSpokeStatusUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.SpokeStatusUpdate memory)
  {
    return
      IAaveV4ConfigEngine.SpokeStatusUpdate({
        hubConfigurator: IHubConfigurator(address(mockHubConfigurator)),
        hub: HUB,
        assetId: ASSET_ID,
        spoke: SPOKE,
        active: EngineFlags.ENABLED,
        halted: EngineFlags.DISABLED
      });
  }

  // Helper: default ReserveConfigUpdate (all fields set)
  function _defaultReserveConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        collateralRisk: 5000,
        paused: EngineFlags.DISABLED,
        frozen: EngineFlags.DISABLED,
        borrowable: EngineFlags.ENABLED,
        receiveSharesEnabled: EngineFlags.ENABLED
      });
  }

  // Helper: default LiquidationConfigUpdate (all fields set)
  function _defaultLiquidationConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: 10000
      });
  }

  // Helper: default DynamicReserveConfigUpdate (all fields set)
  function _defaultDynamicReserveConfigUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory)
  {
    return
      IAaveV4ConfigEngine.DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        reserveId: RESERVE_ID,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 8000,
        maxLiquidationBonus: 10500,
        liquidationFee: 1000
      });
  }

  // Helper: wrap single item in array for engine calls
  function _toArray(
    IAaveV4ConfigEngine.AssetListing memory item
  ) internal pure returns (IAaveV4ConfigEngine.AssetListing[] memory arr) {
    arr = new IAaveV4ConfigEngine.AssetListing[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.FeeConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.FeeConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.FeeConfigUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.InterestRateUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.InterestRateUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.InterestRateUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.SpokeCapsUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeCapsUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeCapsUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.SpokeStatusUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeStatusUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeStatusUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.ReserveConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReserveConfigUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.DynamicReserveConfigUpdate[](1);
    arr[0] = item;
  }
}
