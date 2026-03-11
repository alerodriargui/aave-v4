// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

import {AaveV4HubConfigProcedures} from 'src/deployments/procedures/config/AaveV4HubConfigProcedures.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

contract AaveV4HubConfigProceduresTest is BatchBaseTest {
  address public hub;
  address public irStrategy;
  address public hubConfigurator;
  address public underlying;
  address public reinvestmentController = makeAddr('reinvestmentController');

  function setUp() public override {
    super.setUp();

    // Deploy Hub
    AaveV4HubBatch hubBatch = new AaveV4HubBatch({
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    BatchReports.HubBatchReport memory hubReport = hubBatch.getReport();
    hub = hubReport.hub;
    irStrategy = hubReport.irStrategy;

    // Deploy HubConfigurator
    AaveV4ConfiguratorBatch configuratorBatch = new AaveV4ConfiguratorBatch({
      hubConfiguratorAuthority_: accessManager,
      spokeConfiguratorAuthority_: accessManager,
      salt_: salt
    });
    hubConfigurator = configuratorBatch.getReport().hubConfigurator;

    // Setup roles: Hub selector→role mappings + HubConfigurator selector→role mappings
    vm.startPrank(admin);
    AaveV4HubRolesProcedure.setupHubAllRoles(accessManager, hub);
    IAccessManager(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, hubConfigurator, 0);
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles(
      accessManager,
      hubConfigurator
    );

    // Grant this test contract the asset lister and reinvestment updater roles
    IAccessManager(accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      address(this),
      0
    );
    IAccessManager(accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      address(this),
      0
    );
    vm.stopPrank();

    // Deploy test token
    underlying = address(new TestnetERC20('Test DAI', 'tDAI', 18));
  }

  function test_addAssetViaConfigurator_withReinvestmentController() public {
    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 5_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 5_00
      })
    );

    ConfigData.AddAssetParams memory params = ConfigData.AddAssetParams({
      hub: hub,
      underlying: underlying,
      decimals: 18,
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: irStrategy,
      reinvestmentController: reinvestmentController,
      irData: irData
    });

    uint256 assetId = AaveV4HubConfigProcedures.addAssetViaConfigurator(hubConfigurator, params);

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.reinvestmentController, reinvestmentController);
  }

  function test_addAssetViaConfigurator_fuzz(address reinvestmentController_) public {
    // Each call to addAsset needs a unique underlying
    address fuzzUnderlying = address(new TestnetERC20('Fuzz Token', 'FUZZ', 18));

    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 5_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 5_00
      })
    );

    ConfigData.AddAssetParams memory params = ConfigData.AddAssetParams({
      hub: hub,
      underlying: fuzzUnderlying,
      decimals: 18,
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: irStrategy,
      reinvestmentController: reinvestmentController_,
      irData: irData
    });

    uint256 assetId = AaveV4HubConfigProcedures.addAssetViaConfigurator(hubConfigurator, params);

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.reinvestmentController, reinvestmentController_);
  }

  function test_addAssetViaConfigurator_withoutReinvestmentController() public {
    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 5_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 5_00
      })
    );

    ConfigData.AddAssetParams memory params = ConfigData.AddAssetParams({
      hub: hub,
      underlying: underlying,
      decimals: 18,
      feeReceiver: feeReceiver,
      liquidityFee: 0,
      irStrategy: irStrategy,
      reinvestmentController: address(0),
      irData: irData
    });

    uint256 assetId = AaveV4HubConfigProcedures.addAssetViaConfigurator(hubConfigurator, params);

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.reinvestmentController, address(0));
  }
}
