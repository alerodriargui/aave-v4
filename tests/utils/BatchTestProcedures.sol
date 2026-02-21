// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2 as console} from 'forge-std/console2.sol';

// dependencies
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

// orchestration
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {WETHDeployProcedure} from 'tests/deployments/procedures/WETHDeployProcedure.sol';
import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

import {Logger} from 'src/deployments/utils/Logger.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {Create2TestHelper} from 'tests/utils/Create2TestHelper.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Constants} from 'tests/Constants.sol';

// libraries
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

// interfaces
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

contract BatchTestProcedures is Test, InputUtils, Create2TestHelper, WETHDeployProcedure {
  Logger internal _logger;
  FullDeployInputs internal _inputs;
  address internal _weth9;

  string[] internal _hubLabels;
  string[] internal _spokeLabels;
  bytes4[] internal _spokePositionUpdaterRoleSelectors;
  bytes4[] internal _spokeConfiguratorRoleSelectors;
  bytes4[] internal _hubFeeMinterRoleSelectors;
  bytes4[] internal _hubConfiguratorRoleSelectors;
  address internal _deployer = makeAddr('deployer');

  function setUp() public virtual {
    _spokePositionUpdaterRoleSelectors = Roles.getSpokePositionUpdaterRoleSelectors();
    _spokeConfiguratorRoleSelectors = Roles.getSpokeConfiguratorRoleSelectors();

    _hubFeeMinterRoleSelectors = Roles.getHubFeeMinterRoleSelectors();
    _hubConfiguratorRoleSelectors = Roles.getHubConfiguratorRoleSelectors();

    _weth9 = _deployWETH();
    _logger = new Logger('dummy/path');
    _hubLabels = ['hub1', 'hub2', 'hub3'];
    _spokeLabels = ['spoke1', 'spoke2', 'spoke3'];

    _etchCreate2Factory();
  }

  function checkedV4Deployment() public {
    bytes memory hubBytecode = _getHubBytecode();
    bytes memory spokeBytecode = _getSpokeBytecode();

    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs, hubBytecode, spokeBytecode);
    vm.stopPrank();
    _checkDeployment(report, _inputs);
    _checkRoles(report, _inputs);
  }

  function _checkDeployment(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    _checkFullReport(report, inputs);
    _checkSpokeBatchDeployments(report, inputs);
    _checkHubBatchDeployments(report, inputs);
  }

  function _checkRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );
    _checkAccessManagerRoles(accessManager, inputs);
    _checkSpokeRoles(accessManager, report, inputs);
    _checkHubRoles(accessManager, report, inputs);
    _checkConfiguratorBatchRoles(report, inputs);
    _checkGatewayRoles(report, inputs);
  }

  /// @dev Sanitizes the inputs by defaulting to the deployer if the address is zero.
  function _sanitizeInputs(
    FullDeployInputs memory inputs
  ) internal view returns (FullDeployInputs memory) {
    inputs.accessManagerAdmin = inputs.accessManagerAdmin != address(0)
      ? inputs.accessManagerAdmin
      : _deployer;
    inputs.hubAdmin = inputs.hubAdmin != address(0) ? inputs.hubAdmin : _deployer;
    inputs.hubConfiguratorAdmin = inputs.hubConfiguratorAdmin != address(0)
      ? inputs.hubConfiguratorAdmin
      : _deployer;
    inputs.treasurySpokeOwner = inputs.treasurySpokeOwner != address(0)
      ? inputs.treasurySpokeOwner
      : _deployer;
    inputs.spokeAdmin = inputs.spokeAdmin != address(0) ? inputs.spokeAdmin : _deployer;
    inputs.spokeProxyAdminOwner = inputs.spokeProxyAdminOwner != address(0)
      ? inputs.spokeProxyAdminOwner
      : _deployer;
    inputs.spokeConfiguratorAdmin = inputs.spokeConfiguratorAdmin != address(0)
      ? inputs.spokeConfiguratorAdmin
      : _deployer;
    inputs.gatewayOwner = inputs.gatewayOwner != address(0) ? inputs.gatewayOwner : _deployer;

    // Sync parallel arrays with spokeLabels length
    inputs.hubLabels = _hubLabels;
    inputs.spokeLabels = _spokeLabels;
    inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(_spokeLabels.length);
    inputs.spokeOracleDecimals = _defaultSpokeOracleDecimals(_spokeLabels.length);
    inputs.spokeOracleDescriptions = _defaultSpokeOracleDescriptions(_spokeLabels);
    inputs.nativeWrapper = _weth9;
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = true;

    return inputs;
  }

  function _defaultSpokeMaxReservesLimits(
    uint256 count
  ) internal pure returns (uint16[] memory limits) {
    limits = new uint16[](count);
    for (uint256 i; i < count; i++) {
      limits[i] = Constants.MAX_ALLOWED_USER_RESERVES_LIMIT;
    }
  }

  function _defaultSpokeOracleDecimals(
    uint256 count
  ) internal pure returns (uint8[] memory decimals) {
    decimals = new uint8[](count);
    for (uint256 i; i < count; i++) {
      decimals[i] = Constants.ORACLE_DECIMALS;
    }
  }

  function _defaultSpokeOracleDescriptions(
    string[] memory labels
  ) internal pure returns (string[] memory descriptions) {
    descriptions = new string[](labels.length);
    for (uint256 i; i < labels.length; i++) {
      descriptions[i] = string.concat(labels[i], ' (USD)');
    }
  }

  function _checkFullReport(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal pure {
    if (inputs.deployNativeTokenGateway) {
      assertNotEq(report.gatewaysBatchReport.nativeGateway, address(0), 'NativeGateway');
    } else {
      assertEq(report.gatewaysBatchReport.nativeGateway, address(0), 'Zero NativeGateway');
    }
    if (inputs.deploySignatureGateway) {
      assertNotEq(report.gatewaysBatchReport.signatureGateway, address(0), 'SignatureGateway');
    } else {
      assertEq(report.gatewaysBatchReport.signatureGateway, address(0), 'Zero SignatureGateway');
    }

    assertNotEq(report.authorityBatchReport.accessManager, address(0), 'AccessManager');
    assertNotEq(report.configuratorBatchReport.spokeConfigurator, address(0), 'SpokeConfigurator');
    assertNotEq(report.configuratorBatchReport.hubConfigurator, address(0), 'HubConfigurator');
    for (uint256 i = 0; i < report.hubBatchReports.length; i++) {
      assertNotEq(report.hubBatchReports[i].report.hub, address(0), 'Hub');
      assertNotEq(report.hubBatchReports[i].report.irStrategy, address(0), 'IRStrategy');
      assertNotEq(report.hubBatchReports[i].report.treasurySpoke, address(0), 'TreasurySpoke');
    }
    for (uint256 i = 0; i < report.spokeInstanceBatchReports.length; i++) {
      assertNotEq(report.spokeInstanceBatchReports[i].report.spokeProxy, address(0), 'SpokeProxy');
      assertNotEq(report.spokeInstanceBatchReports[i].report.aaveOracle, address(0), 'AaveOracle');
    }
    assertEq(report.hubBatchReports.length, inputs.hubLabels.length, 'HubBatchReportsLength');
    assertEq(
      report.spokeInstanceBatchReports.length,
      inputs.spokeLabels.length,
      'SpokeInstanceBatchReportsLength'
    );
  }

  function _checkSpokeBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    string memory globalLabel = 'SpokeDeployment';
    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      string memory label = string.concat(globalLabel, ', ', inputs.spokeLabels[i]);
      OrchestrationReports.SpokeDeploymentReport memory spokeReport = report
        .spokeInstanceBatchReports[i];
      _checkSpokeDeployment({
        report: spokeReport,
        accessManager: report.authorityBatchReport.accessManager,
        label: label
      });
      _checkOracleDeployment({report: spokeReport, label: label});
    }
  }

  function _checkSpokeDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    address accessManager,
    string memory label
  ) internal view {
    assertEq(
      ProxyHelper.getImplementation(report.report.spokeProxy),
      report.report.spokeImplementation,
      string.concat(label, ' implementation')
    );
    assertEq(
      ISpoke(report.report.spokeProxy).ORACLE(),
      report.report.aaveOracle,
      string.concat(label, ' oracle on spoke')
    );
    assertEq(
      IAccessManaged(report.report.spokeProxy).authority(),
      accessManager,
      string.concat(label, ' spoke authority')
    );
  }

  function _checkOracleDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAaveOracle(report.report.aaveOracle).SPOKE(),
      report.report.spokeProxy,
      string.concat(label, ' spoke on oracle')
    );
    assertEq(
      IAaveOracle(report.report.aaveOracle).DECIMALS(),
      Constants.ORACLE_DECIMALS,
      string.concat(label, ' oracle decimals')
    );
    assertEq(
      IAaveOracle(report.report.aaveOracle).DESCRIPTION(),
      string.concat(report.label, Constants.ORACLE_SUFFIX),
      string.concat(label, ' oracle description')
    );
  }

  function _checkHubBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    string memory globalLabel = 'HubDeployment';
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      string memory label = string.concat(globalLabel, ', ', inputs.hubLabels[i]);
      OrchestrationReports.HubDeploymentReport memory hubReport = report.hubBatchReports[i];

      _checkHubDeployment({
        report: hubReport,
        accessManager: report.authorityBatchReport.accessManager,
        label: label
      });
      _checkInterestRateStrategyDeployment({report: hubReport, label: label});
      _checkTreasurySpokeDeployment({report: hubReport, label: label});
    }
  }

  function _checkHubDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    address accessManager,
    string memory label
  ) internal view {
    assertEq(
      IAccessManaged(report.report.hub).authority(),
      accessManager,
      string.concat(label, ' hub authority')
    );
  }

  function _checkInterestRateStrategyDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAssetInterestRateStrategy(report.report.irStrategy).HUB(),
      report.report.hub,
      string.concat(label, ' hub on interest rate strategy')
    );
  }

  function _checkTreasurySpokeDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      address(ITreasurySpoke(report.report.treasurySpoke).HUB()),
      report.report.hub,
      string.concat(label, ' hub on treasury spoke')
    );
  }

  function _checkAccessManagerRoles(
    IAccessManagerEnumerable accessManager,
    FullDeployInputs memory inputs
  ) internal view {
    address expectedAdmin = (inputs.grantRoles && inputs.accessManagerAdmin != address(0))
      ? inputs.accessManagerAdmin
      : _deployer;
    assertEq(
      accessManager.getRoleMember(Roles.ACCESS_MANAGER_DEFAULT_ADMIN, 0),
      expectedAdmin,
      'DefaultAdminRoleMember'
    );
    assertEq(
      accessManager.getRoleMemberCount(Roles.ACCESS_MANAGER_DEFAULT_ADMIN),
      1,
      'DefaultAdminRoleCount'
    );

    (bool adminHasRole, ) = accessManager.hasRole(
      Roles.ACCESS_MANAGER_DEFAULT_ADMIN,
      expectedAdmin
    );
    assertTrue(adminHasRole, 'access manager admin has default admin role');
  }

  function _checkSpokeRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    _checkSpokeAdminRoles(accessManager, report, inputs);
    _checkSpokeConfiguratorRoles(accessManager, report, inputs);
  }

  function _checkSpokeConfiguratorRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    if (inputs.spokeLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_CONFIGURATOR_ROLE),
        2,
        'SpokeConfiguratorRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_CONFIGURATOR_ROLE, 0),
        inputs.spokeAdmin,
        'SpokeConfiguratorRole member - spoke admin'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_CONFIGURATOR_ROLE, 1),
        report.configuratorBatchReport.spokeConfigurator,
        'SpokeConfiguratorRole member - spoke configurator'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_CONFIGURATOR_ROLE),
        0,
        'SpokeConfiguratorRole member count'
      );
    }

    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      for (uint256 j = 0; j < _spokeConfiguratorRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxy,
            _spokeConfiguratorRoleSelectors[j]
          ),
          Roles.SPOKE_CONFIGURATOR_ROLE,
          'SpokeConfiguratorRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          report.configuratorBatchReport.spokeConfigurator,
          report.spokeInstanceBatchReports[i].report.spokeProxy,
          _spokeConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'SpokeConfiguratorRole allowed - configurator'
        );
        assertEq(delay, 0, 'SpokeConfiguratorRole delay - configurator');

        // spoke admin role encompasses spoke configurator role
        (allowed, delay) = accessManager.canCall(
          inputs.spokeAdmin,
          report.spokeInstanceBatchReports[i].report.spokeProxy,
          _spokeConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'SpokeConfiguratorRole allowed - spoke admin'
        );
        assertEq(delay, 0, 'SpokeConfiguratorRole delay - spoke admin');
      }
    }
  }

  function _checkSpokeAdminRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    if (inputs.spokeLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
        1,
        'SpokePositionUpdaterRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_USER_POSITION_UPDATER_ROLE, 0),
        inputs.spokeAdmin,
        'SpokePositionUpdaterRole member - spoke admin'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_USER_POSITION_UPDATER_ROLE),
        0,
        'SpokePositionUpdaterRoleCount'
      );
    }

    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      address proxyAdminOwner = Ownable(
        ProxyHelper.getProxyAdmin(report.spokeInstanceBatchReports[i].report.spokeProxy)
      ).owner();
      assertEq(
        proxyAdminOwner,
        inputs.spokeProxyAdminOwner,
        string.concat(inputs.spokeLabels[i], ' proxy admin owner')
      );

      for (uint256 j = 0; j < _spokePositionUpdaterRoleSelectors.length; j++) {
        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.spokeAdmin,
          report.spokeInstanceBatchReports[i].report.spokeProxy,
          _spokePositionUpdaterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'SpokePositionUpdaterRole allowed');
        assertEq(delay, 0, 'SpokePositionUpdaterRole delay');

        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxy,
            _spokePositionUpdaterRoleSelectors[j]
          ),
          Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
          'SpokePositionUpdaterRole target function'
        );
      }
    }
  }

  function _checkHubRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    _checkHubBatchRoles(accessManager, report, inputs);
    _checkHubConfiguratorRoles(accessManager, report, inputs);
  }

  function _checkHubBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    if (inputs.hubLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE),
        1,
        'HubFeeMinterRoleCount'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_FEE_MINTER_ROLE, 0),
        inputs.hubAdmin,
        'HubFeeMinterRole member - hub admin'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE),
        0,
        'HubFeeMinterRoleCount'
      );
    }
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      _checkTreasurySpokeRoles(
        report.hubBatchReports[i].report.treasurySpoke,
        inputs,
        inputs.hubLabels[i]
      );
      for (uint256 j = 0; j < _hubFeeMinterRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubBatchReports[i].report.hub,
            _hubFeeMinterRoleSelectors[j]
          ),
          Roles.HUB_FEE_MINTER_ROLE,
          'HubFeeMinterRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubBatchReports[i].report.hub,
          _hubFeeMinterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubFeeMinterRole allowed');
        assertEq(delay, 0, 'HubFeeMinterRole delay');
      }
    }
  }

  function _checkTreasurySpokeRoles(
    address treasurySpoke,
    FullDeployInputs memory inputs,
    string memory label
  ) internal view {
    assertEq(
      Ownable(treasurySpoke).owner(),
      inputs.treasurySpokeOwner,
      string.concat(label, ' treasury spoke owner')
    );
  }

  function _checkHubConfiguratorRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    if (inputs.hubLabels.length > 0 && inputs.grantRoles) {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_CONFIGURATOR_ROLE),
        2,
        'HubConfiguratorRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_CONFIGURATOR_ROLE, 0),
        inputs.hubAdmin,
        'HubConfiguratorRole member - hub admin'
      );
      assertEq(
        accessManager.getRoleMember(Roles.HUB_CONFIGURATOR_ROLE, 1),
        report.configuratorBatchReport.hubConfigurator,
        'HubConfiguratorRole member - hub configurator'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.HUB_CONFIGURATOR_ROLE),
        0,
        'HubConfiguratorRole member count'
      );
    }
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      for (uint256 j = 0; j < _hubConfiguratorRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubBatchReports[i].report.hub,
            _hubConfiguratorRoleSelectors[j]
          ),
          Roles.HUB_CONFIGURATOR_ROLE,
          'HubConfiguratorRole target function'
        );
        bool allowed;
        uint32 delay;

        (allowed, delay) = accessManager.canCall(
          report.configuratorBatchReport.hubConfigurator,
          report.hubBatchReports[i].report.hub,
          _hubConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'HubConfiguratorRole allowed - configurator'
        );
        assertEq(delay, 0, 'HubConfiguratorRole delay - configurator');

        (allowed, delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubBatchReports[i].report.hub,
          _hubConfiguratorRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubConfiguratorRole allowed - admin');
        assertEq(delay, 0, 'HubConfiguratorRole delay - admin');
      }
    }
  }

  function _checkConfiguratorBatchRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    assertEq(
      IAccessManaged(report.configuratorBatchReport.hubConfigurator).authority(),
      report.authorityBatchReport.accessManager,
      'HubConfigurator authority'
    );
    assertEq(
      IAccessManaged(report.configuratorBatchReport.spokeConfigurator).authority(),
      report.authorityBatchReport.accessManager,
      'SpokeConfigurator authority'
    );

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.authorityBatchReport.accessManager
    );

    _checkHubConfiguratorBatchRoles(accessManager, report, inputs);
    _checkSpokeConfiguratorBatchRoles(accessManager, report, inputs);
  }

  function _checkHubConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    bytes4[] memory feeUpdaterSelectors = Roles.getHubConfiguratorFeeUpdaterRoleSelectors();
    bytes4[] memory reinvestmentSelectors = Roles
      .getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    bytes4[] memory assetListerSelectors = Roles.getHubConfiguratorAssetListerRoleSelectors();
    bytes4[] memory spokeAdderSelectors = Roles.getHubConfiguratorSpokeAdderRoleSelectors();
    bytes4[] memory irUpdaterSelectors = Roles.getHubConfiguratorInterestRateUpdaterRoleSelectors();
    bytes4[] memory haltSelectors = Roles.getHubConfiguratorHalterRoleSelectors();
    bytes4[] memory deactivateSelectors = Roles.getHubConfiguratorActivaterRoleSelectors();
    bytes4[] memory capsResetSelectors = Roles.getHubConfiguratorCapSetterRoleSelectors();

    address hc = report.configuratorBatchReport.hubConfigurator;

    for (uint256 i; i < feeUpdaterSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, feeUpdaterSelectors[i]),
        Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
        'HubConfigurator feeUpdater selector role mapping'
      );
    }
    for (uint256 i; i < reinvestmentSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, reinvestmentSelectors[i]),
        Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
        'HubConfigurator reinvestment selector role mapping'
      );
    }
    for (uint256 i; i < assetListerSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, assetListerSelectors[i]),
        Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
        'HubConfigurator assetLister selector role mapping'
      );
    }
    for (uint256 i; i < spokeAdderSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, spokeAdderSelectors[i]),
        Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
        'HubConfigurator spokeAdder selector role mapping'
      );
    }
    for (uint256 i; i < irUpdaterSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, irUpdaterSelectors[i]),
        Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
        'HubConfigurator irUpdater selector role mapping'
      );
    }
    for (uint256 i; i < haltSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, haltSelectors[i]),
        Roles.HUB_CONFIGURATOR_HALTER_ROLE,
        'HubConfigurator halt selector role mapping'
      );
    }
    for (uint256 i; i < deactivateSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, deactivateSelectors[i]),
        Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
        'HubConfigurator deactivate selector role mapping'
      );
    }
    for (uint256 i; i < capsResetSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, capsResetSelectors[i]),
        Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE,
        'HubConfigurator capsReset selector role mapping'
      );
    }

    // Verify canCall for hub configurator admin
    if (inputs.grantRoles && inputs.hubLabels.length > 0) {
      (bool allowed, ) = accessManager.canCall(
        inputs.hubConfiguratorAdmin,
        hc,
        feeUpdaterSelectors[0]
      );
      assertTrue(allowed, 'HubConfigurator admin canCall feeUpdater selector');
      (allowed, ) = accessManager.canCall(
        inputs.hubConfiguratorAdmin,
        hc,
        reinvestmentSelectors[0]
      );
      assertTrue(allowed, 'HubConfigurator admin canCall reinvestment selector');
      (allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, assetListerSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall assetLister selector');
      (allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, spokeAdderSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall spokeAdder selector');
      (allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, irUpdaterSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall irUpdater selector');
      (allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, haltSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall halt selector');
      (allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, deactivateSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall deactivate selector');
      (allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, capsResetSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall capsReset selector');
    }
  }

  function _checkSpokeConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    bytes4[] memory adminSelectors = Roles.getSpokeConfiguratorAdminRoleSelectors();
    bytes4[] memory liqUpdaterSelectors = Roles
      .getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    bytes4[] memory reserveAdderSelectors = Roles.getSpokeConfiguratorReserveAdderRoleSelectors();
    bytes4[] memory freezeSelectors = Roles.getSpokeConfiguratorFreezerRoleSelectors();
    bytes4[] memory pauseSelectors = Roles.getSpokeConfiguratorPauserRoleSelectors();

    address sc = report.configuratorBatchReport.spokeConfigurator;

    for (uint256 i; i < adminSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, adminSelectors[i]),
        Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
        'SpokeConfigurator admin selector role mapping'
      );
    }
    for (uint256 i; i < liqUpdaterSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, liqUpdaterSelectors[i]),
        Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
        'SpokeConfigurator liquidationUpdater selector role mapping'
      );
    }
    for (uint256 i; i < reserveAdderSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, reserveAdderSelectors[i]),
        Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
        'SpokeConfigurator reserveAdder selector role mapping'
      );
    }
    for (uint256 i; i < freezeSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, freezeSelectors[i]),
        Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
        'SpokeConfigurator freeze selector role mapping'
      );
    }
    for (uint256 i; i < pauseSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, pauseSelectors[i]),
        Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
        'SpokeConfigurator pause selector role mapping'
      );
    }

    // Verify canCall for spoke configurator admin
    if (inputs.grantRoles && inputs.spokeLabels.length > 0) {
      (bool allowed, ) = accessManager.canCall(
        inputs.spokeConfiguratorAdmin,
        sc,
        adminSelectors[0]
      );
      assertTrue(allowed, 'SpokeConfigurator admin canCall admin selector');
      (allowed, ) = accessManager.canCall(
        inputs.spokeConfiguratorAdmin,
        sc,
        liqUpdaterSelectors[0]
      );
      assertTrue(allowed, 'SpokeConfigurator admin canCall liquidationUpdater selector');
      (allowed, ) = accessManager.canCall(
        inputs.spokeConfiguratorAdmin,
        sc,
        reserveAdderSelectors[0]
      );
      assertTrue(allowed, 'SpokeConfigurator admin canCall reserveAdder selector');
      (allowed, ) = accessManager.canCall(inputs.spokeConfiguratorAdmin, sc, freezeSelectors[0]);
      assertTrue(allowed, 'SpokeConfigurator admin canCall freeze selector');
      (allowed, ) = accessManager.canCall(inputs.spokeConfiguratorAdmin, sc, pauseSelectors[0]);
      assertTrue(allowed, 'SpokeConfigurator admin canCall pause selector');
    }
  }

  function _checkGatewayRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    if (inputs.deployNativeTokenGateway) {
      assertEq(
        Ownable(report.gatewaysBatchReport.nativeGateway).owner(),
        inputs.gatewayOwner,
        'NativeGateway owner'
      );
    }
    if (inputs.deploySignatureGateway) {
      assertEq(
        Ownable(report.gatewaysBatchReport.signatureGateway).owner(),
        inputs.gatewayOwner,
        'SignatureGateway owner'
      );
    }
  }

  function _etchSetup() internal {
    _etchCreate2Factory();
    _etchLiquidationLogicLibrary();
  }

  /// @dev Workaround for Foundry's `dynamic_test_linking` not deploying the LiquidationLogic
  ///      library at the address it pre-links into consumer bytecodes (SpokeInstance, etc.).
  ///      Hardcode Foundry's pre-linked deterministic address. If it changes
  ///      (e.g. after a Foundry upgrade), find the new one by:
  ///      - Running a failing liquidation test with `forge test -vvvv` and looking for:
  ///        "delegatecall to <ADDRESS> (unlinked library)"
  function _etchLiquidationLogicLibrary() internal {
    address lib = address(0x5e14175873D9038DC68cB2319d00c173Dc09ad03);
    if (lib.code.length == 0) {
      vm.etch(lib, vm.getDeployedCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic'));
    }
  }

  function _getHubBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/Hub.sol:Hub');
  }

  function _getSpokeBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
  }
}
