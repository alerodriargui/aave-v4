// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';

import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';

import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

import {AaveV4HubConfigProceduresWrapper} from 'tests/mocks/deployments/procedures/AaveV4HubConfigProceduresWrapper.sol';
import {AaveV4SpokeConfigProceduresWrapper} from 'tests/mocks/deployments/procedures/AaveV4SpokeConfigProceduresWrapper.sol';

import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';

contract ConfigProceduresBase is Test, InputUtils {
  address public admin = makeAddr('admin');
  address public treasuryAdmin = makeAddr('treasuryAdmin');
  bytes32 public salt;

  address public accessManager;
  address public hub;
  address public irStrategy;
  address public treasurySpoke;
  address public spokeProxy;
  address public aaveOracle;
  address public hubConfigurator;
  address public spokeConfigurator;

  TestnetERC20 public underlying;

  AaveV4HubConfigProceduresWrapper public hubConfigWrapper;
  AaveV4SpokeConfigProceduresWrapper public spokeConfigWrapper;

  IAssetInterestRateStrategy.InterestRateData internal _defaultIrData =
    IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 90_00,
      baseVariableBorrowRate: 5_00,
      variableRateSlope1: 5_00,
      variableRateSlope2: 5_00
    });

  function setUp() public virtual {
    _etchCreate2Factory();
    salt = keccak256('configProcTestSalt');

    // Deploy infrastructure
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin, salt);
    accessManager = accessBatch.getReport().accessManager;

    AaveV4HubBatch hubBatch = new AaveV4HubBatch(treasuryAdmin, accessManager, salt);
    hub = hubBatch.getReport().hub;
    irStrategy = hubBatch.getReport().irStrategy;
    treasurySpoke = hubBatch.getReport().treasurySpoke;

    AaveV4SpokeInstanceBatch spokeBatch = new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      8,
      'Test (USD)',
      128,
      salt
    );
    spokeProxy = spokeBatch.getReport().spokeProxy;
    aaveOracle = spokeBatch.getReport().aaveOracle;

    AaveV4ConfiguratorBatch cfgBatch = new AaveV4ConfiguratorBatch(
      accessManager,
      accessManager,
      salt
    );
    hubConfigurator = cfgBatch.getReport().hubConfigurator;
    spokeConfigurator = cfgBatch.getReport().spokeConfigurator;

    // Setup roles (selector → role mappings on targets)
    vm.startPrank(admin);
    IAccessManager(accessManager).grantRole(Roles.DEFAULT_ADMIN_ROLE, address(this), 0);
    vm.stopPrank();

    AaveV4HubRolesProcedure.setupHubRoles(accessManager, hub);
    AaveV4SpokeRolesProcedure.setupSpokeRoles(accessManager, spokeProxy);
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRoles(accessManager, hubConfigurator);
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      accessManager,
      spokeConfigurator
    );

    // Deploy wrappers
    hubConfigWrapper = new AaveV4HubConfigProceduresWrapper();
    spokeConfigWrapper = new AaveV4SpokeConfigProceduresWrapper();

    // Grant roles to wrappers
    IAccessManager(accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_ROLE,
      address(hubConfigWrapper),
      0
    );
    IAccessManager(accessManager).grantRole(
      Roles.SPOKE_CONFIGURATOR_ROLE,
      address(spokeConfigWrapper),
      0
    );

    // Grant roles to configurator contracts
    AaveV4HubRolesProcedure.grantHubConfiguratorRole(accessManager, hubConfigurator);
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole(accessManager, spokeConfigurator);

    // Grant configurator granular roles to wrappers
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(
      accessManager,
      address(hubConfigWrapper)
    );
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      accessManager,
      address(spokeConfigWrapper)
    );

    // Set maxReserves on SpokeConfigurator
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      accessManager,
      address(this)
    );
    ISpokeConfigurator(spokeConfigurator).updateMaxReserves(spokeProxy, 128);
    IAccessManager(accessManager).renounceRole(Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE, address(this));

    // Deploy test token
    underlying = new TestnetERC20('Test Token', 'TST', 18);

    IAccessManager(accessManager).renounceRole(Roles.DEFAULT_ADMIN_ROLE, address(this));
  }

  function _defaultIrDataEncoded() internal view returns (bytes memory) {
    return abi.encode(_defaultIrData);
  }

  function _deployMockPriceFeed(uint256 price) internal returns (address) {
    IAaveOracle oracle = IAaveOracle(aaveOracle);
    return address(new MockPriceFeed(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
  }
}
