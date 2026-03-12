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
    inputs.positionManagerOwner = inputs.positionManagerOwner != address(0)
      ? inputs.positionManagerOwner
      : _deployer;

    // Sync parallel arrays with spokeLabels length
    inputs.hubLabels = _hubLabels;
    inputs.spokeLabels = _spokeLabels;
    inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(_spokeLabels.length);
    inputs.nativeWrapper = _weth9;
    inputs.deployNativeTokenGateway = true;
    inputs.deploySignatureGateway = true;
    inputs.deployPositionManagers = true;

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
    if (inputs.deployPositionManagers) {
      assertNotEq(
        report.positionManagerBatchReport.giverPositionManager,
        address(0),
        'GiverPositionManager'
      );
      assertNotEq(
        report.positionManagerBatchReport.takerPositionManager,
        address(0),
        'TakerPositionManager'
      );
    } else {
      assertEq(
        report.positionManagerBatchReport.giverPositionManager,
        address(0),
        'Zero GiverPositionManager'
      );
      assertEq(
        report.positionManagerBatchReport.takerPositionManager,
        address(0),
        'Zero TakerPositionManager'
      );
    }

    assertNotEq(report.authorityBatchReport.accessManager, address(0), 'AccessManager');
    assertNotEq(report.configuratorBatchReport.spokeConfigurator, address(0), 'SpokeConfigurator');
    assertNotEq(report.configuratorBatchReport.hubConfigurator, address(0), 'HubConfigurator');
    assertNotEq(report.treasurySpokeBatchReport.treasurySpoke, address(0), 'TreasurySpoke');
    for (uint256 i = 0; i < report.hubBatchReports.length; i++) {
      assertNotEq(report.hubBatchReports[i].report.hub, address(0), 'Hub');
      assertNotEq(report.hubBatchReports[i].report.irStrategy, address(0), 'IRStrategy');
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
      IAaveOracle(report.report.aaveOracle).spoke(),
      report.report.spokeProxy,
      string.concat(label, ' spoke on oracle')
    );
    assertEq(
      IAaveOracle(report.report.aaveOracle).decimals(),
      Constants.ORACLE_DECIMALS,
      string.concat(label, ' oracle decimals')
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
    }
    _checkTreasurySpokeDeployment(report);
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
    OrchestrationReports.FullDeploymentReport memory report
  ) internal view {
    assertNotEq(
      report.treasurySpokeBatchReport.treasurySpoke,
      address(0),
      'treasury spoke deployed'
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
    _checkHubSelectorRoles(accessManager, report, inputs);
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
    _checkTreasurySpokeRoles(report.treasurySpokeBatchReport.treasurySpoke, inputs);
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
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
    FullDeployInputs memory inputs
  ) internal view {
    assertEq(Ownable(treasurySpoke).owner(), inputs.treasurySpokeOwner, 'treasury spoke owner');
  }

  function _checkHubSelectorRoles(
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
    address hubConfigurator = report.configuratorBatchReport.hubConfigurator;

    bytes4[][] memory selectorGroups = new bytes4[][](14);
    uint64[] memory expectedRoles = new uint64[](14);
    string[] memory labels = new string[](14);

    selectorGroups[0] = Roles.getHubConfiguratorLiquidityFeeUpdaterRoleSelectors();
    expectedRoles[0] = Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE;
    labels[0] = 'liquidityFeeUpdater';

    selectorGroups[1] = Roles.getHubConfiguratorFeeConfiguratorRoleSelectors();
    expectedRoles[1] = Roles.HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE;
    labels[1] = 'feeConfigurator';

    selectorGroups[2] = Roles.getHubConfiguratorReinvestmentUpdaterRoleSelectors();
    expectedRoles[2] = Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE;
    labels[2] = 'reinvestment';

    selectorGroups[3] = Roles.getHubConfiguratorHalterRoleSelectors();
    expectedRoles[3] = Roles.HUB_CONFIGURATOR_HALTER_ROLE;
    labels[3] = 'halt';

    selectorGroups[4] = Roles.getHubConfiguratorDeactivatorRoleSelectors();
    expectedRoles[4] = Roles.HUB_CONFIGURATOR_DEACTIVATOR_ROLE;
    labels[4] = 'deactivate';

    selectorGroups[5] = Roles.getHubConfiguratorCapsResetterRoleSelectors();
    expectedRoles[5] = Roles.HUB_CONFIGURATOR_CAPS_RESETTER_ROLE;
    labels[5] = 'capsResetter';

    selectorGroups[6] = Roles.getHubConfiguratorCapsUpdaterRoleSelectors();
    expectedRoles[6] = Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE;
    labels[6] = 'capsUpdater';

    selectorGroups[7] = Roles.getHubConfiguratorDrawCapUpdaterRoleSelectors();
    expectedRoles[7] = Roles.HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE;
    labels[7] = 'drawCapUpdater';

    selectorGroups[8] = Roles.getHubConfiguratorAddCapUpdaterRoleSelectors();
    expectedRoles[8] = Roles.HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE;
    labels[8] = 'addCapUpdater';

    selectorGroups[9] = Roles.getHubConfiguratorSpokeRiskAdminRoleSelectors();
    expectedRoles[9] = Roles.HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE;
    labels[9] = 'spokeRiskAdmin';

    selectorGroups[10] = Roles.getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors();
    expectedRoles[10] = Roles.HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE;
    labels[10] = 'irStrategyUpdater';

    selectorGroups[11] = Roles.getHubConfiguratorInterestRateDataUpdaterRoleSelectors();
    expectedRoles[11] = Roles.HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE;
    labels[11] = 'irDataUpdater';

    selectorGroups[12] = Roles.getHubConfiguratorAssetListerRoleSelectors();
    expectedRoles[12] = Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE;
    labels[12] = 'assetLister';

    selectorGroups[13] = Roles.getHubConfiguratorSpokeAdderRoleSelectors();
    expectedRoles[13] = Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE;
    labels[13] = 'spokeAdder';

    for (uint256 group; group < selectorGroups.length; group++) {
      for (uint256 idx; idx < selectorGroups[group].length; idx++) {
        assertEq(
          accessManager.getTargetFunctionRole(hubConfigurator, selectorGroups[group][idx]),
          expectedRoles[group],
          string.concat('HubConfigurator ', labels[group], ' selector role mapping')
        );
      }
    }

    if (inputs.grantRoles && inputs.hubLabels.length > 0) {
      for (uint256 group; group < selectorGroups.length; group++) {
        (bool allowed, ) = accessManager.canCall(
          inputs.hubConfiguratorAdmin,
          hubConfigurator,
          selectorGroups[group][0]
        );
        assertTrue(
          allowed,
          string.concat('HubConfigurator admin canCall ', labels[group], ' selector')
        );
      }
    }
  }

  function _checkSpokeConfiguratorBatchRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    address spokeConfigurator = report.configuratorBatchReport.spokeConfigurator;

    bytes4[][] memory selectorGroups = new bytes4[][](9);
    uint64[] memory expectedRoles = new uint64[](9);
    string[] memory labels = new string[](9);

    selectorGroups[0] = Roles.getSpokeConfiguratorPriceAdminRoleSelectors();
    expectedRoles[0] = Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE;
    labels[0] = 'priceAdmin';

    selectorGroups[1] = Roles.getSpokeConfiguratorReserveAdminRoleSelectors();
    expectedRoles[1] = Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE;
    labels[1] = 'reserveAdmin';

    selectorGroups[2] = Roles.getSpokeConfiguratorDynamicReserveAdminRoleSelectors();
    expectedRoles[2] = Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE;
    labels[2] = 'dynamicReserveAdmin';

    selectorGroups[3] = Roles.getSpokeConfiguratorPositionManagerAdminRoleSelectors();
    expectedRoles[3] = Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE;
    labels[3] = 'positionManagerAdmin';

    selectorGroups[4] = Roles.getSpokeConfiguratorLiquidationUpdaterRoleSelectors();
    expectedRoles[4] = Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE;
    labels[4] = 'liquidationUpdater';

    selectorGroups[5] = Roles.getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors();
    expectedRoles[5] = Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE;
    labels[5] = 'dynamicLiquidationUpdater';

    selectorGroups[6] = Roles.getSpokeConfiguratorReserveAdderRoleSelectors();
    expectedRoles[6] = Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE;
    labels[6] = 'reserveAdder';

    selectorGroups[7] = Roles.getSpokeConfiguratorFreezerRoleSelectors();
    expectedRoles[7] = Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE;
    labels[7] = 'freeze';

    selectorGroups[8] = Roles.getSpokeConfiguratorPauserRoleSelectors();
    expectedRoles[8] = Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE;
    labels[8] = 'pause';

    for (uint256 group; group < selectorGroups.length; group++) {
      for (uint256 idx; idx < selectorGroups[group].length; idx++) {
        assertEq(
          accessManager.getTargetFunctionRole(spokeConfigurator, selectorGroups[group][idx]),
          expectedRoles[group],
          string.concat('SpokeConfigurator ', labels[group], ' selector role mapping')
        );
      }
    }

    if (inputs.grantRoles && inputs.spokeLabels.length > 0) {
      for (uint256 group; group < selectorGroups.length; group++) {
        (bool allowed, ) = accessManager.canCall(
          inputs.spokeConfiguratorAdmin,
          spokeConfigurator,
          selectorGroups[group][0]
        );
        assertTrue(
          allowed,
          string.concat('SpokeConfigurator admin canCall ', labels[group], ' selector')
        );
      }
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
