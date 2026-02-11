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
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

import {Logger} from 'src/deployments/utils/Logger.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Constants} from 'tests/Constants.sol';

// libraries
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

// interfaces
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

contract BatchTestProcedures is Test, InputUtils, WETHDeployProcedure {
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
    _spokePositionUpdaterRoleSelectors = AaveV4SpokeRolesProcedure
      .getSpokePositionUpdaterRoleSelectors();
    _spokeConfiguratorRoleSelectors = AaveV4SpokeRolesProcedure.getSpokeConfiguratorRoleSelectors();

    _hubFeeMinterRoleSelectors = AaveV4HubRolesProcedure.getHubFeeMinterRoleSelectors();
    _hubConfiguratorRoleSelectors = AaveV4HubRolesProcedure.getHubConfiguratorRoleSelectors();

    _weth9 = _deployWETH();
    _logger = new Logger('dummy/path');
    _hubLabels = ['hub1', 'hub2', 'hub3'];
    _spokeLabels = ['spoke1', 'spoke2', 'spoke3'];

    _etchCreate2Factory();
  }

  function checkedV4Deployment() public {
    vm.startPrank(_deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(_logger, _deployer, _inputs);
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
      report.accessBatchReport.accessManager
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

    return inputs;
  }

  function _checkFullReport(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal pure {
    if (inputs.nativeWrapper != address(0)) {
      assertNotEq(report.gatewaysBatchReport.nativeGateway, address(0), 'NativeGateway');
      assertNotEq(report.gatewaysBatchReport.signatureGateway, address(0), 'SignatureGateway');
    } else {
      assertEq(report.gatewaysBatchReport.nativeGateway, address(0), 'Zero NativeGateway');
      assertEq(report.gatewaysBatchReport.signatureGateway, address(0), 'Zero SignatureGateway');
    }

    assertNotEq(report.accessBatchReport.accessManager, address(0), 'AccessManager');
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
        accessManager: report.accessBatchReport.accessManager,
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
        accessManager: report.accessBatchReport.accessManager,
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
      accessManager.getRoleMember(Roles.DEFAULT_ADMIN_ROLE, 0),
      expectedAdmin,
      'DefaultAdminRoleMember'
    );
    assertEq(
      accessManager.getRoleMemberCount(Roles.DEFAULT_ADMIN_ROLE),
      1,
      'DefaultAdminRoleCount'
    );

    (bool adminHasRole, ) = accessManager.hasRole(Roles.DEFAULT_ADMIN_ROLE, expectedAdmin);
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
        accessManager.getRoleMemberCount(Roles.SPOKE_POSITION_UPDATER_ROLE),
        1,
        'SpokeAdminRole member count'
      );
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_POSITION_UPDATER_ROLE, 0),
        inputs.spokeAdmin,
        'SpokeAdminRole member - spoke admin'
      );
    } else {
      assertEq(
        accessManager.getRoleMemberCount(Roles.SPOKE_POSITION_UPDATER_ROLE),
        0,
        'HubAdminRoleCount'
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
        assertEq(allowed, inputs.grantRoles ? true : false, 'SpokeAdminRole allowed');
        assertEq(delay, 0, 'SpokeAdminRole delay');

        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxy,
            _spokePositionUpdaterRoleSelectors[j]
          ),
          Roles.SPOKE_POSITION_UPDATER_ROLE,
          'SpokeAdminRole target function'
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
      assertEq(accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE), 1, 'HubAdminRoleCount');
      assertEq(
        accessManager.getRoleMember(Roles.HUB_FEE_MINTER_ROLE, 0),
        inputs.hubAdmin,
        'HubAdminRole member - hub admin'
      );
    } else {
      assertEq(accessManager.getRoleMemberCount(Roles.HUB_FEE_MINTER_ROLE), 0, 'HubAdminRoleCount');
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
          'HubAdminRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubBatchReports[i].report.hub,
          _hubFeeMinterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubAdminRole allowed');
        assertEq(delay, 0, 'HubAdminRole delay');
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
      report.accessBatchReport.accessManager,
      'HubConfigurator authority'
    );
    assertEq(
      IAccessManaged(report.configuratorBatchReport.spokeConfigurator).authority(),
      report.accessBatchReport.accessManager,
      'SpokeConfigurator authority'
    );

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.accessBatchReport.accessManager
    );

    _checkHubConfiguratorBatchRoles(accessManager, report, inputs);
    _checkSpokeConfiguratorBatchRoles(accessManager, report, inputs);
  }

  function _checkHubConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    bytes4[] memory adminSelectors = AaveV4HubConfiguratorRolesProcedure
      .getHubConfiguratorAdminRoleSelectors();
    bytes4[] memory haltSelectors = AaveV4HubConfiguratorRolesProcedure.getHubHaltRoleSelectors();
    bytes4[] memory deactivateSelectors = AaveV4HubConfiguratorRolesProcedure
      .getHubDeactivateRoleSelectors();
    bytes4[] memory capsResetSelectors = AaveV4HubConfiguratorRolesProcedure
      .getHubCapsResetRoleSelectors();

    address hc = report.configuratorBatchReport.hubConfigurator;

    for (uint256 i; i < adminSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, adminSelectors[i]),
        Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
        'HubConfigurator admin selector role mapping'
      );
    }
    for (uint256 i; i < haltSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, haltSelectors[i]),
        Roles.HUB_HALT_ROLE,
        'HubConfigurator halt selector role mapping'
      );
    }
    for (uint256 i; i < deactivateSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, deactivateSelectors[i]),
        Roles.HUB_DEACTIVATE_ROLE,
        'HubConfigurator deactivate selector role mapping'
      );
    }
    for (uint256 i; i < capsResetSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(hc, capsResetSelectors[i]),
        Roles.HUB_CAPS_RESET_ROLE,
        'HubConfigurator capsReset selector role mapping'
      );
    }

    // Verify canCall for hub configurator admin
    if (inputs.grantRoles && inputs.hubLabels.length > 0) {
      (bool allowed, ) = accessManager.canCall(inputs.hubConfiguratorAdmin, hc, adminSelectors[0]);
      assertTrue(allowed, 'HubConfigurator admin canCall admin selector');
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
    bytes4[] memory adminSelectors = AaveV4SpokeConfiguratorRolesProcedure
      .getSpokeConfiguratorAdminRoleSelectors();
    bytes4[] memory freezeSelectors = AaveV4SpokeConfiguratorRolesProcedure
      .getSpokeFreezeRoleSelectors();
    bytes4[] memory pauseSelectors = AaveV4SpokeConfiguratorRolesProcedure
      .getSpokePauseRoleSelectors();

    address sc = report.configuratorBatchReport.spokeConfigurator;

    for (uint256 i; i < adminSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, adminSelectors[i]),
        Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
        'SpokeConfigurator admin selector role mapping'
      );
    }
    for (uint256 i; i < freezeSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, freezeSelectors[i]),
        Roles.SPOKE_FREEZE_ROLE,
        'SpokeConfigurator freeze selector role mapping'
      );
    }
    for (uint256 i; i < pauseSelectors.length; i++) {
      assertEq(
        accessManager.getTargetFunctionRole(sc, pauseSelectors[i]),
        Roles.SPOKE_PAUSE_ROLE,
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
    if (inputs.nativeWrapper != address(0)) {
      assertEq(
        Ownable(report.gatewaysBatchReport.nativeGateway).owner(),
        inputs.gatewayOwner,
        'NativeGateway owner'
      );
      assertEq(
        Ownable(report.gatewaysBatchReport.signatureGateway).owner(),
        inputs.gatewayOwner,
        'SignatureGateway owner'
      );
    }
  }
}
