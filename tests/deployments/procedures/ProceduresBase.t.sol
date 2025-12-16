// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {stdError} from 'forge-std/Test.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {
  AaveV4HubConfiguratorDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4HubConfiguratorDeployProcedureWrapper.sol';
import {
  AaveV4HubDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4HubDeployProcedureWrapper.sol';
import {
  AaveV4InterestRateStrategyDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4InterestRateStrategyDeployProcedureWrapper.sol';
import {
  AaveV4NativeTokenGatewayDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4NativeTokenGatewayDeployProcedureWrapper.sol';
import {
  AaveV4SignatureGatewayDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4SignatureGatewayDeployProcedureWrapper.sol';
import {
  AaveV4AccessManagerEnumerableDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4AccessManagerEnumerableDeployProcedureWrapper.sol';
import {
  AaveV4AaveOracleDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4AaveOracleDeployProcedureWrapper.sol';
import {
  AaveV4SpokeDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4SpokeDeployProcedureWrapper.sol';
import {
  AaveV4TreasurySpokeDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4TreasurySpokeDeployProcedureWrapper.sol';
import {
  AaveV4SpokeConfiguratorDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4SpokeConfiguratorDeployProcedureWrapper.sol';
import {
  AaveV4AccessManagerRolesProcedureWrapper
} from 'tests/mocks/deployments/AaveV4AccessManagerRolesProcedureWrapper.sol';
import {
  AaveV4SpokeRolesProcedureWrapper
} from 'tests/mocks/deployments/AaveV4SpokeRolesProcedureWrapper.sol';
import {
  AaveV4HubRolesProcedureWrapper
} from 'tests/mocks/deployments/AaveV4HubRolesProcedureWrapper.sol';

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

contract ProceduresBase is Test {
  address public owner;
  address public accessManager;
  address public hub;
  address public nativeWrapper;
  address public accessManagerAdmin;
  uint8 public oracleDecimals;
  string public oracleDescription;
  address public spoke;
  address public aaveOracle;
  address public treasurySpoke;

  function setUp() public virtual {
    owner = makeAddr('owner');
    accessManagerAdmin = makeAddr('accessManagerAdmin');
    accessManager = address(new AccessManagerEnumerable(accessManagerAdmin));
    hub = makeAddr('hub');
    nativeWrapper = makeAddr('nativeWrapper');
    oracleDecimals = 8;
    oracleDescription = 'Oracle Description';
    spoke = makeAddr('spoke');
    aaveOracle = address(new AaveOracle(spoke, oracleDecimals, oracleDescription));
    treasurySpoke = makeAddr('treasurySpoke');
  }
}
