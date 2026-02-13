// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/config-engine/AaveV4ConfigEngineBase.t.sol';

/// @title AaveV4HubConfigEngineTest
/// @notice Tests for AaveV4HubConfigEngine — asset listing, spoke registration,
///         tokenization, and all granular hub-side update operations.
///         The engine is stateless: all functions take hub/hubConfigurator as parameters.
contract AaveV4HubConfigEngineTest is AaveV4ConfigEngineBaseTest {
  // ========================
  // Asset Listing
  // ========================

  function test_hubEngine_listAssets() public {
    IAaveV4HubConfigEngine.AssetListing[]
      memory listings = new IAaveV4HubConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(weth),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 10_00,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });

    IAaveV4HubConfigEngine.ListAssetsReport memory report = hubEngine.listAssets(
      hub,
      hubConfigurator,
      listings
    );

    assertEq(report.underlyings.length, 1);
    assertEq(report.underlyings[0], address(weth));
    assertEq(report.assetIds.length, 1);

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    assertEq(assetId, report.assetIds[0]);
  }

  function test_hubEngine_listMultipleAssets() public {
    IAaveV4HubConfigEngine.AssetListing[]
      memory listings = new IAaveV4HubConfigEngine.AssetListing[](2);
    listings[0] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(weth),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 10_00,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });
    listings[1] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(usdc),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 5_00,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });

    IAaveV4HubConfigEngine.ListAssetsReport memory report = hubEngine.listAssets(
      hub,
      hubConfigurator,
      listings
    );

    assertEq(report.underlyings.length, 2);
    assertEq(report.assetIds.length, 2);
    assertEq(IHub(hub).getAssetId(address(weth)), report.assetIds[0]);
    assertEq(IHub(hub).getAssetId(address(usdc)), report.assetIds[1]);
  }

  // ========================
  // Spoke Registration
  // ========================

  function test_hubEngine_addSpokes() public {
    _listWethAsset();

    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = new IAaveV4HubConfigEngine.SpokeListing[](
      1
    );
    spokes[0] = IAaveV4HubConfigEngine.SpokeListing({
      underlying: address(weth),
      spoke: spokeProxy,
      tokenization: IAaveV4HubConfigEngine.TokenizationConfig({
        enabled: false,
        shareName: '',
        shareSymbol: '',
        proxyAdminOwner: address(0)
      }),
      spokeConfig: IHub.SpokeConfig({
        addCap: 10000,
        drawCap: 8000,
        riskPremiumThreshold: 500,
        active: true,
        halted: false
      })
    });

    IAaveV4HubConfigEngine.AddSpokesReport memory report = hubEngine.addSpokes(
      hub,
      hubConfigurator,
      salt,
      spokes
    );

    assertEq(report.spokeAddresses[0], spokeProxy);
    assertEq(report.tokenizationProxies[0], address(0));

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    assertTrue(IHub(hub).isSpokeListed(assetId, spokeProxy));
  }

  function test_hubEngine_addTokenizationSpoke() public {
    _listWethAsset();

    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = new IAaveV4HubConfigEngine.SpokeListing[](
      1
    );
    spokes[0] = IAaveV4HubConfigEngine.SpokeListing({
      underlying: address(weth),
      spoke: address(0),
      tokenization: IAaveV4HubConfigEngine.TokenizationConfig({
        enabled: true,
        shareName: 'Aave V4 WETH Vault',
        shareSymbol: 'av4WETH',
        proxyAdminOwner: admin
      }),
      spokeConfig: IHub.SpokeConfig({
        addCap: 5000,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    });

    IAaveV4HubConfigEngine.AddSpokesReport memory report = hubEngine.addSpokes(
      hub,
      hubConfigurator,
      salt,
      spokes
    );

    assertNotEq(report.spokeAddresses[0], address(0));
    assertNotEq(report.tokenizationProxies[0], address(0));
    assertEq(report.spokeAddresses[0], report.tokenizationProxies[0]);

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    assertTrue(IHub(hub).isSpokeListed(assetId, report.spokeAddresses[0]));
  }

  function test_hubEngine_assetWithTokenizationOnly() public {
    _listWethAsset();

    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = new IAaveV4HubConfigEngine.SpokeListing[](
      1
    );
    spokes[0] = IAaveV4HubConfigEngine.SpokeListing({
      underlying: address(weth),
      spoke: address(0),
      tokenization: IAaveV4HubConfigEngine.TokenizationConfig({
        enabled: true,
        shareName: 'Aave V4 WETH Vault',
        shareSymbol: 'av4WETH',
        proxyAdminOwner: admin
      }),
      spokeConfig: IHub.SpokeConfig({
        addCap: 10000,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    });

    IAaveV4HubConfigEngine.AddSpokesReport memory report = hubEngine.addSpokes(
      hub,
      hubConfigurator,
      salt,
      spokes
    );

    assertNotEq(report.tokenizationProxies[0], address(0));
    uint256 assetId = IHub(hub).getAssetId(address(weth));
    assertTrue(IHub(hub).isSpokeListed(assetId, report.tokenizationProxies[0]));
  }

  // ========================
  // Granular Update: Liquidity Fees
  // ========================

  function test_hubEngine_updateAssetLiquidityFees() public {
    _listWethAsset();

    uint256 assetId = IHub(hub).getAssetId(address(weth));

    IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate[]
      memory updates = new IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.AssetLiquidityFeeUpdate({
      assetId: assetId,
      liquidityFee: 20_00
    });

    hubEngine.updateAssetLiquidityFees(hub, hubConfigurator, updates);

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.liquidityFee, 20_00);
  }

  // ========================
  // Granular Update: IR Data
  // ========================

  function test_hubEngine_updateAssetIRData() public {
    _listWethAsset();

    uint256 assetId = IHub(hub).getAssetId(address(weth));

    bytes memory newIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 80_00,
        baseVariableBorrowRate: 2_00,
        variableRateSlope1: 8_00,
        variableRateSlope2: 10_00
      })
    );

    IAaveV4HubConfigEngine.AssetIRDataUpdate[]
      memory updates = new IAaveV4HubConfigEngine.AssetIRDataUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.AssetIRDataUpdate({assetId: assetId, irData: newIrData});

    hubEngine.updateAssetIRData(hub, hubConfigurator, updates);

    IAssetInterestRateStrategy.InterestRateData memory irData = IAssetInterestRateStrategy(
      irStrategy
    ).getInterestRateData(assetId);
    assertEq(irData.optimalUsageRatio, 80_00);
    assertEq(irData.baseVariableBorrowRate, 2_00);
    assertEq(irData.variableRateSlope1, 8_00);
    assertEq(irData.variableRateSlope2, 10_00);
  }

  // ========================
  // Granular Update: Fee Receivers
  // ========================

  function test_hubEngine_updateAssetFeeReceivers() public {
    _listWethAsset();

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    address newFeeReceiver = makeAddr('newFeeReceiver');

    IAaveV4HubConfigEngine.AssetFeeReceiverUpdate[]
      memory updates = new IAaveV4HubConfigEngine.AssetFeeReceiverUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.AssetFeeReceiverUpdate({
      assetId: assetId,
      feeReceiver: newFeeReceiver
    });

    hubEngine.updateAssetFeeReceivers(hub, hubConfigurator, updates);

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.feeReceiver, newFeeReceiver);
  }

  // ========================
  // Granular Update: Spoke Caps
  // ========================

  function test_hubEngine_updateSpokeCaps() public {
    _listWethAsset();
    _registerSpokeForWeth();

    uint256 assetId = IHub(hub).getAssetId(address(weth));

    IAaveV4HubConfigEngine.SpokeCapUpdate[]
      memory updates = new IAaveV4HubConfigEngine.SpokeCapUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.SpokeCapUpdate({
      assetId: assetId,
      spoke: spokeProxy,
      addCap: 20000,
      drawCap: 15000
    });

    hubEngine.updateSpokeCaps(hub, hubConfigurator, updates);

    IHub.SpokeConfig memory config = IHub(hub).getSpokeConfig(assetId, spokeProxy);
    assertEq(config.addCap, 20000);
    assertEq(config.drawCap, 15000);
  }

  // ========================
  // Granular Update: Spoke Active
  // ========================

  function test_hubEngine_updateSpokeActive() public {
    _listWethAsset();
    _registerSpokeForWeth();

    uint256 assetId = IHub(hub).getAssetId(address(weth));

    IAaveV4HubConfigEngine.SpokeActiveUpdate[]
      memory updates = new IAaveV4HubConfigEngine.SpokeActiveUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.SpokeActiveUpdate({
      assetId: assetId,
      spoke: spokeProxy,
      active: false
    });

    hubEngine.updateSpokeActive(hub, hubConfigurator, updates);

    IHub.SpokeConfig memory config = IHub(hub).getSpokeConfig(assetId, spokeProxy);
    assertFalse(config.active);
  }

  // ========================
  // Granular Update: Spoke Halted
  // ========================

  function test_hubEngine_updateSpokeHalted() public {
    _listWethAsset();
    _registerSpokeForWeth();

    uint256 assetId = IHub(hub).getAssetId(address(weth));

    IAaveV4HubConfigEngine.SpokeHaltedUpdate[]
      memory updates = new IAaveV4HubConfigEngine.SpokeHaltedUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.SpokeHaltedUpdate({
      assetId: assetId,
      spoke: spokeProxy,
      halted: true
    });

    hubEngine.updateSpokeHalted(hub, hubConfigurator, updates);

    IHub.SpokeConfig memory config = IHub(hub).getSpokeConfig(assetId, spokeProxy);
    assertTrue(config.halted);
  }

  // ========================
  // Granular Update: Risk Premium
  // ========================

  function test_hubEngine_updateSpokeRiskPremiumThresholds() public {
    _listWethAsset();
    _registerSpokeForWeth();

    uint256 assetId = IHub(hub).getAssetId(address(weth));

    IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate[]
      memory updates = new IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate[](1);
    updates[0] = IAaveV4HubConfigEngine.SpokeRiskPremiumUpdate({
      assetId: assetId,
      spoke: spokeProxy,
      riskPremiumThreshold: 1000
    });

    hubEngine.updateSpokeRiskPremiumThresholds(hub, hubConfigurator, updates);

    IHub.SpokeConfig memory config = IHub(hub).getSpokeConfig(assetId, spokeProxy);
    assertEq(config.riskPremiumThreshold, 1000);
  }
}
