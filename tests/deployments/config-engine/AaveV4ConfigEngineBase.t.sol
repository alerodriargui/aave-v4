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

/// @title AaveV4ConfigEngineBaseTest
/// @notice Shared test base for hub and spoke config engine tests.
///         Deploys the full protocol stack (AccessManager, Hub, Spoke, Configurators),
///         sets up all roles, deploys stateless config engines, and provides test tokens + price feeds.
///         Child tests import this file (wildcard) to get everything in scope.
abstract contract AaveV4ConfigEngineBaseTest is Test, InputUtils {
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

  // Stateless config engines (deployed once, reused for all calls)
  AaveV4HubConfigEngine public hubEngine;
  AaveV4SpokeConfigEngine public spokeEngine;

  // Test tokens
  TestnetERC20 public weth;
  TestnetERC20 public usdc;

  // Price feeds
  MockPriceFeed public wethPriceFeed;
  MockPriceFeed public usdcPriceFeed;

  function setUp() public virtual {
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

    AaveV4HubRolesProcedure.setupHubRoles(accessManager, hub);
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRoles(accessManager, hubConfigurator);
    IAccessManager(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, hubConfigurator, 0);

    AaveV4SpokeRolesProcedure.setupSpokeRoles(accessManager, spokeProxy);
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      accessManager,
      spokeConfigurator
    );
    IAccessManager(accessManager).grantRole(Roles.SPOKE_CONFIGURATOR_ROLE, spokeConfigurator, 0);

    vm.stopPrank();

    // Deploy stateless config engines (no constructor args — they are singletons)
    hubEngine = new AaveV4HubConfigEngine();
    spokeEngine = new AaveV4SpokeConfigEngine();

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
    IAccessManager(accessManager).grantRole(Roles.SPOKE_FREEZE_ROLE, address(spokeEngine), 0);
    IAccessManager(accessManager).grantRole(Roles.SPOKE_PAUSE_ROLE, address(spokeEngine), 0);
    IAccessManager(accessManager).grantRole(Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE, admin, 0);
    ISpokeConfigurator(spokeConfigurator).updateMaxReserves(spokeProxy, 128);
    vm.stopPrank();

    // Deploy test tokens
    weth = new TestnetERC20('Wrapped Ether', 'WETH', 18);
    usdc = new TestnetERC20('USD Coin', 'USDC', 6);

    // Deploy mock price feeds
    wethPriceFeed = new MockPriceFeed(8, 'ETH/USD', 2000e8);
    usdcPriceFeed = new MockPriceFeed(8, 'USDC/USD', 1e8);
  }

  // ==================== Shared Helpers ====================

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
      liquidityFee: 10_00,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });
    hubEngine.listAssets(hub, hubConfigurator, listings);
  }

  function _listUsdcAsset() internal {
    IAaveV4HubConfigEngine.AssetListing[]
      memory listings = new IAaveV4HubConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4HubConfigEngine.AssetListing({
      underlying: address(usdc),
      irStrategy: irStrategy,
      irData: _defaultIrData(),
      liquidityFee: 5_00,
      feeReceiver: treasurySpoke,
      reinvestmentController: address(0)
    });
    hubEngine.listAssets(hub, hubConfigurator, listings);
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
    hubEngine.addSpokes(hub, hubConfigurator, salt, spokes);
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
    hubEngine.addSpokes(hub, hubConfigurator, salt, spokes);
  }

  function _listWethReserve() internal {
    IAaveV4SpokeConfigEngine.ReserveListing[]
      memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](1);
    reserves[0] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(weth),
      priceFeed: address(wethPriceFeed),
      config: ISpoke.ReserveConfig({
        collateralRisk: 50_00,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 100
      })
    });
    spokeEngine.listReserves(spokeProxy, spokeConfigurator, hub, reserves);
  }
}
