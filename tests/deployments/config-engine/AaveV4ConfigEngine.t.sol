// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

// Batches
import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

// Role procedures
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

// Config engines
import {AaveV4HubConfigEngine} from 'src/deployments/config-engine/AaveV4HubConfigEngine.sol';
import {AaveV4SpokeConfigEngine} from 'src/deployments/config-engine/AaveV4SpokeConfigEngine.sol';
import {IAaveV4HubConfigEngine} from 'src/deployments/config-engine/IAaveV4HubConfigEngine.sol';
import {IAaveV4SpokeConfigEngine} from 'src/deployments/config-engine/IAaveV4SpokeConfigEngine.sol';

contract AaveV4ConfigEngineTest is Test, InputUtils {
  address public admin = makeAddr('admin');
  bytes32 public salt;

  // Protocol contracts
  address public accessManager;
  address public hub;
  address public irStrategy;
  address public treasurySpoke;
  address public spokeProxy;
  address public hubConfigurator;
  address public spokeConfigurator;

  // Config engines
  AaveV4HubConfigEngine public hubEngine;
  AaveV4SpokeConfigEngine public spokeEngine;

  // Test tokens
  TestnetERC20 public weth;
  TestnetERC20 public usdc;

  // Price feeds
  MockPriceFeed public wethPriceFeed;
  MockPriceFeed public usdcPriceFeed;

  function setUp() public {
    salt = keccak256('configEngineSalt');
    _etchCreate2Factory();

    // Deploy AccessManager
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin, salt);
    accessManager = accessBatch.getReport().accessManager;

    // Deploy Hub + IR Strategy + TreasurySpoke
    AaveV4HubBatch hubBatch = new AaveV4HubBatch(
      admin,
      accessManager,
      keccak256(abi.encode(salt, 'hub'))
    );
    BatchReports.HubBatchReport memory hubReport = hubBatch.getReport();
    hub = hubReport.hub;
    irStrategy = hubReport.irStrategy;
    treasurySpoke = hubReport.treasurySpoke;

    // Deploy Spoke (proxy + impl) + Oracle
    AaveV4SpokeInstanceBatch spokeBatch = new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      8,
      'Test Oracle',
      128,
      keccak256(abi.encode(salt, 'spoke'))
    );
    spokeProxy = spokeBatch.getReport().spokeProxy;

    // Deploy Configurators
    AaveV4ConfiguratorBatch cfgBatch = new AaveV4ConfiguratorBatch(
      accessManager,
      accessManager,
      keccak256(abi.encode(salt, 'config'))
    );
    hubConfigurator = cfgBatch.getReport().hubConfigurator;
    spokeConfigurator = cfgBatch.getReport().spokeConfigurator;

    // Setup roles (as admin who has DEFAULT_ADMIN_ROLE)
    vm.startPrank(admin);

    // Setup Hub roles
    AaveV4HubRolesProcedure.setupHubRoles(accessManager, hub);

    // Setup HubConfigurator roles
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRoles(accessManager, hubConfigurator);

    // Grant HUB_CONFIGURATOR_ROLE to HubConfigurator
    IAccessManager(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, hubConfigurator, 0);

    // Setup Spoke roles
    AaveV4SpokeRolesProcedure.setupSpokeRoles(accessManager, spokeProxy);

    // Setup SpokeConfigurator roles
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      accessManager,
      spokeConfigurator
    );

    // Grant SPOKE_CONFIGURATOR_ROLE to SpokeConfigurator
    IAccessManager(accessManager).grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, spokeConfigurator, 0);

    vm.stopPrank();

    // Deploy config engines
    hubEngine = new AaveV4HubConfigEngine(hub, hubConfigurator, salt);
    spokeEngine = new AaveV4SpokeConfigEngine(spokeProxy, spokeConfigurator, hub);

    // Grant config engine roles and set max reserves
    vm.startPrank(admin);
    IAccessManager(accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
      address(hubEngine),
      0
    );
    IAccessManager(accessManager).grantRole(
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      address(spokeEngine),
      0
    );
    // Grant admin the SPOKE_CONFIGURATOR_ADMIN_ROLE so we can set max reserves
    IAccessManager(accessManager).grantRole(Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE, admin, 0);
    ISpokeConfigurator(spokeConfigurator).updateMaxReserves(spokeProxy, 128);
    vm.stopPrank();

    // Deploy test tokens
    weth = new TestnetERC20('Wrapped Ether', 'WETH', 18);
    usdc = new TestnetERC20('USD Coin', 'USDC', 6);

    // Deploy mock price feeds
    wethPriceFeed = new MockPriceFeed(8, 'ETH/USD', 2000e8); // $2000
    usdcPriceFeed = new MockPriceFeed(8, 'USDC/USD', 1e8); // $1
  }

  function test_hubEngine_listAssets() public {
    IAaveV4HubConfigEngine.AssetListing[]
      memory listings = new IAaveV4HubConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(weth),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 1000,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });

    IAaveV4HubConfigEngine.ListAssetsReport memory report = hubEngine.listAssets(listings);

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
      liquidityFee: 1000,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });
    listings[1] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(usdc),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 500,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });

    IAaveV4HubConfigEngine.ListAssetsReport memory report = hubEngine.listAssets(listings);

    assertEq(report.underlyings.length, 2);
    assertEq(report.assetIds.length, 2);
    assertEq(IHub(hub).getAssetId(address(weth)), report.assetIds[0]);
    assertEq(IHub(hub).getAssetId(address(usdc)), report.assetIds[1]);
  }

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

    IAaveV4HubConfigEngine.AddSpokesReport memory report = hubEngine.addSpokes(spokes);

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

    IAaveV4HubConfigEngine.AddSpokesReport memory report = hubEngine.addSpokes(spokes);

    assertNotEq(report.spokeAddresses[0], address(0));
    assertNotEq(report.tokenizationProxies[0], address(0));
    assertEq(report.spokeAddresses[0], report.tokenizationProxies[0]);

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    assertTrue(IHub(hub).isSpokeListed(assetId, report.spokeAddresses[0]));
  }

  function test_spokeEngine_listReserves() public {
    _listWethAsset();
    _registerSpokeForWeth();

    IAaveV4SpokeConfigEngine.ReserveListing[]
      memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](1);
    reserves[0] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(weth),
      priceFeed: address(wethPriceFeed),
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
        liquidationFee: 100
      })
    });

    uint256[] memory reserveIds = spokeEngine.listReserves(reserves);

    assertEq(reserveIds.length, 1);
  }

  function test_spokeEngine_listMultipleReserves() public {
    _listWethAsset();
    _listUsdcAsset();
    _registerSpokeForWeth();
    _registerSpokeForUsdc();

    IAaveV4SpokeConfigEngine.ReserveListing[]
      memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](2);
    reserves[0] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(weth),
      priceFeed: address(wethPriceFeed),
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
        liquidationFee: 100
      })
    });
    reserves[1] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(usdc),
      priceFeed: address(usdcPriceFeed),
      config: ISpoke.ReserveConfig({
        collateralRisk: 3000,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 8500,
        maxLiquidationBonus: 10400,
        liquidationFee: 100
      })
    });

    uint256[] memory reserveIds = spokeEngine.listReserves(reserves);

    assertEq(reserveIds.length, 2);
  }

  function test_spokeEngine_updateLiquidationConfig() public {
    _listWethAsset();
    _registerSpokeForWeth();
    _listWethReserve();

    IAaveV4SpokeConfigEngine.LiquidationConfigInput memory input = IAaveV4SpokeConfigEngine
      .LiquidationConfigInput({
        config: ISpoke.LiquidationConfig({
          targetHealthFactor: 1.1e18,
          healthFactorForMaxBonus: 0.95e18,
          liquidationBonusFactor: 10000
        })
      });

    spokeEngine.updateLiquidationConfig(input);
  }

  // ========================
  // Constructor Tests
  // ========================

  function test_revert_hubEngine_zeroHub() public {
    vm.expectRevert('invalid hub');
    new AaveV4HubConfigEngine(address(0), hubConfigurator, salt);
  }

  function test_revert_hubEngine_zeroConfigurator() public {
    vm.expectRevert('invalid hub configurator');
    new AaveV4HubConfigEngine(hub, address(0), salt);
  }

  function test_revert_spokeEngine_zeroSpoke() public {
    vm.expectRevert('invalid spoke');
    new AaveV4SpokeConfigEngine(address(0), spokeConfigurator, hub);
  }

  function test_revert_spokeEngine_zeroConfigurator() public {
    vm.expectRevert('invalid spoke configurator');
    new AaveV4SpokeConfigEngine(spokeProxy, address(0), hub);
  }

  function test_revert_spokeEngine_zeroHub() public {
    vm.expectRevert('invalid hub');
    new AaveV4SpokeConfigEngine(spokeProxy, spokeConfigurator, address(0));
  }

  // Scenario 8: Asset + Tokenization only, no lending
  function test_scenario8_assetWithTokenizationOnly() public {
    _listWethAsset();

    // Deploy tokenization spoke — no regular spoke needed
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

    IAaveV4HubConfigEngine.AddSpokesReport memory report = hubEngine.addSpokes(spokes);

    // Tokenization spoke deployed and registered
    assertNotEq(report.tokenizationProxies[0], address(0));
    uint256 assetId = IHub(hub).getAssetId(address(weth));
    assertTrue(IHub(hub).isSpokeListed(assetId, report.tokenizationProxies[0]));
  }

  function _defaultIrData() internal pure returns (bytes memory) {
    return
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: 5_00,
          variableRateSlope1: 5_00,
          variableRateSlope2: 5_00
        })
      );
  }

  function _listWethAsset() internal {
    IAaveV4HubConfigEngine.AssetListing[]
      memory listings = new IAaveV4HubConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(weth),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 1000,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });
    hubEngine.listAssets(listings);
  }

  function _listUsdcAsset() internal {
    IAaveV4HubConfigEngine.AssetListing[]
      memory listings = new IAaveV4HubConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(usdc),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 500,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });
    hubEngine.listAssets(listings);
  }

  function _registerSpokeForWeth() internal {
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
    hubEngine.addSpokes(spokes);
  }

  function _registerSpokeForUsdc() internal {
    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = new IAaveV4HubConfigEngine.SpokeListing[](
      1
    );
    spokes[0] = IAaveV4HubConfigEngine.SpokeListing({
      underlying: address(usdc),
      spoke: spokeProxy,
      tokenization: IAaveV4HubConfigEngine.TokenizationConfig({
        enabled: false,
        shareName: '',
        shareSymbol: '',
        proxyAdminOwner: address(0)
      }),
      spokeConfig: IHub.SpokeConfig({
        addCap: 50000,
        drawCap: 40000,
        riskPremiumThreshold: 300,
        active: true,
        halted: false
      })
    });
    hubEngine.addSpokes(spokes);
  }

  function _listWethReserve() internal {
    IAaveV4SpokeConfigEngine.ReserveListing[]
      memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](1);
    reserves[0] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(weth),
      priceFeed: address(wethPriceFeed),
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
        liquidationFee: 100
      })
    });
    spokeEngine.listReserves(reserves);
  }
}
