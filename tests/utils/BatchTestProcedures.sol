// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console2 as console} from 'forge-std/console2.sol';

// dependencies
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';

// orchestration
import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {WETHDeployProcedure} from 'src/deployments/procedures/deploy/WETHDeployProcedure.sol';
import {
  AaveV4SpokeRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {
  AaveV4HubRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Constants} from 'tests/Constants.sol';

import {Roles} from 'src/deployments/procedures/roles/Roles.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';

contract BatchTestProcedures is Test, InputUtils, WETHDeployProcedure {
  bytes4[] public spokePositionUpdaterRoleSelectors;
  bytes4[] public spokeConfiguratorRoleSelectors;
  bytes4[] public hubFeeMinterRoleSelectors;
  bytes4[] public hubConfiguratorRoleSelectors;
  address public deployer;

  function setUp() public virtual {
    spokePositionUpdaterRoleSelectors = AaveV4SpokeRolesProcedure
      .getSpokePositionUpdaterRoleSelectors();
    spokeConfiguratorRoleSelectors = AaveV4SpokeRolesProcedure.getSpokeConfiguratorRoleSelectors();

    hubFeeMinterRoleSelectors = AaveV4HubRolesProcedure.getHubFeeMinterRoleSelectors();
    hubConfiguratorRoleSelectors = AaveV4HubRolesProcedure.getHubConfiguratorRoleSelectors();
  }

  function deployAaveV4Testnet(
    Logger logger,
    FullDeployInputs memory inputs
  ) public returns (OrchestrationReports.FullDeploymentReport memory) {
    vm.startPrank(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(logger, deployer, inputs);
    vm.stopPrank();
    return report;
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
    inputs = _sanitizeInputs(inputs);

    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.accessBatchReport.accessManagerAddress
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
      : deployer;
    inputs.hubAdmin = inputs.hubAdmin != address(0) ? inputs.hubAdmin : deployer;
    inputs.hubConfiguratorOwner = inputs.hubConfiguratorOwner != address(0)
      ? inputs.hubConfiguratorOwner
      : deployer;
    inputs.treasurySpokeOwner = inputs.treasurySpokeOwner != address(0)
      ? inputs.treasurySpokeOwner
      : deployer;
    inputs.spokeAdmin = inputs.spokeAdmin != address(0) ? inputs.spokeAdmin : deployer;
    inputs.spokeProxyAdminOwner = inputs.spokeProxyAdminOwner != address(0)
      ? inputs.spokeProxyAdminOwner
      : deployer;
    inputs.spokeConfiguratorOwner = inputs.spokeConfiguratorOwner != address(0)
      ? inputs.spokeConfiguratorOwner
      : deployer;
    inputs.gatewayOwner = inputs.gatewayOwner != address(0) ? inputs.gatewayOwner : deployer;

    return inputs;
  }

  function _checkFullReport(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal pure {
    if (inputs.nativeWrapperAddress != address(0)) {
      assertNotEq(
        report.gatewaysBatchReport.nativeGatewayAddress,
        address(0),
        'NativeGatewayAddress'
      );
    } else {
      assertEq(
        report.gatewaysBatchReport.nativeGatewayAddress,
        address(0),
        'Zero NativeGatewayAddress'
      );
    }
    assertNotEq(
      report.gatewaysBatchReport.signatureGatewayAddress,
      address(0),
      'SignatureGatewayAddress'
    );

    assertNotEq(report.accessBatchReport.accessManagerAddress, address(0), 'AccessManagerAddress');
    assertNotEq(
      report.configuratorBatchReport.spokeConfiguratorAddress,
      address(0),
      'SpokeConfiguratorAddress'
    );
    assertNotEq(
      report.configuratorBatchReport.hubConfiguratorAddress,
      address(0),
      'HubConfiguratorAddress'
    );
    assertNotEq(
      report.gatewaysBatchReport.signatureGatewayAddress,
      address(0),
      'SignatureGatewayAddress'
    );
    for (uint256 i = 0; i < report.hubBatchReports.length; i++) {
      assertNotEq(report.hubBatchReports[i].report.hubAddress, address(0), 'HubAddress');
      assertNotEq(
        report.hubBatchReports[i].report.irStrategyAddress,
        address(0),
        'IRStrategyAddress'
      );
      assertNotEq(
        report.hubBatchReports[i].report.treasurySpokeAddress,
        address(0),
        'TreasurySpokeAddress'
      );
    }
    for (uint256 i = 0; i < report.spokeInstanceBatchReports.length; i++) {
      assertNotEq(
        report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
        address(0),
        'SpokeProxyAddress'
      );
      assertNotEq(
        report.spokeInstanceBatchReports[i].report.aaveOracleAddress,
        address(0),
        'AaveOracleAddress'
      );
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
      _checkSpokeBatchDeployment(
        report.spokeInstanceBatchReports[i],
        report.accessBatchReport.accessManagerAddress,
        string.concat(globalLabel, ', ', inputs.spokeLabels[i])
      );
    }
  }

  function _checkSpokeBatchDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    address accessManagerAddress,
    string memory label
  ) internal view {
    _checkSpokeDeployment({
      report: report,
      accessManagerAddress: accessManagerAddress,
      label: label
    });
    _checkOracleDeployment({report: report, label: label});
  }

  function _checkSpokeDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    address accessManagerAddress,
    string memory label
  ) internal view {
    assertEq(
      ProxyHelper.getImplementation(report.report.spokeProxyAddress),
      report.report.spokeImplementationAddress,
      string.concat(label, ' implementation')
    );
    assertEq(
      ISpoke(report.report.spokeProxyAddress).ORACLE(),
      report.report.aaveOracleAddress,
      string.concat(label, ' oracle on spoke')
    );
    assertEq(
      IAccessManaged(report.report.spokeProxyAddress).authority(),
      accessManagerAddress,
      string.concat(label, ' spoke authority')
    );
  }

  function _checkOracleDeployment(
    OrchestrationReports.SpokeDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAaveOracle(report.report.aaveOracleAddress).SPOKE(),
      report.report.spokeProxyAddress,
      string.concat(label, ' spoke on oracle')
    );
    assertEq(
      IAaveOracle(report.report.aaveOracleAddress).DECIMALS(),
      Constants.ORACLE_DECIMALS,
      string.concat(label, ' oracle decimals')
    );
    assertEq(
      IAaveOracle(report.report.aaveOracleAddress).DESCRIPTION(),
      string.concat(report.label, Constants.ORACLE_SUFFIX),
      string.concat(label, ' oracle description')
    );
  }

  function _checkHubBatchDeployments(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    string memory label = 'HubDeployment';
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      _checkHubBatchDeployment(
        report.hubBatchReports[i],
        report.accessBatchReport.accessManagerAddress,
        string.concat(label, ', ', inputs.hubLabels[i])
      );
    }
  }

  function _checkHubBatchDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    address accessManagerAddress,
    string memory label
  ) internal view {
    _checkHubDeployment(report, accessManagerAddress, label);
    _checkInterestRateStrategyDeployment(report, label);
    _checkTreasurySpokeDeployment(report, label);
  }

  function _checkHubDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    address accessManagerAddress,
    string memory label
  ) internal view {
    assertEq(
      IAccessManaged(report.report.hubAddress).authority(),
      accessManagerAddress,
      string.concat(label, ' hub authority')
    );
  }

  function _checkInterestRateStrategyDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      IAssetInterestRateStrategy(report.report.irStrategyAddress).HUB(),
      report.report.hubAddress,
      string.concat(label, ' hub on interest rate strategy')
    );
  }

  function _checkTreasurySpokeDeployment(
    OrchestrationReports.HubDeploymentReport memory report,
    string memory label
  ) internal view {
    assertEq(
      address(ITreasurySpoke(report.report.treasurySpokeAddress).HUB()),
      report.report.hubAddress,
      string.concat(label, ' hub on treasury spoke')
    );
  }

  function _checkAccessManagerRoles(
    IAccessManagerEnumerable accessManager,
    FullDeployInputs memory inputs
  ) internal view {
    address expectedAdmin = (inputs.grantRoles && inputs.accessManagerAdmin != address(0))
      ? inputs.accessManagerAdmin
      : deployer;
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
        report.configuratorBatchReport.spokeConfiguratorAddress,
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
      for (uint256 j = 0; j < spokeConfiguratorRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
            spokeConfiguratorRoleSelectors[j]
          ),
          Roles.SPOKE_CONFIGURATOR_ROLE,
          'SpokeConfiguratorRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          report.configuratorBatchReport.spokeConfiguratorAddress,
          report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
          spokeConfiguratorRoleSelectors[j]
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
          report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
          spokeConfiguratorRoleSelectors[j]
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
        ProxyHelper.getProxyAdmin(report.spokeInstanceBatchReports[i].report.spokeProxyAddress)
      ).owner();
      assertEq(
        proxyAdminOwner,
        inputs.spokeProxyAdminOwner,
        string.concat(inputs.spokeLabels[i], ' proxy admin owner')
      );

      for (uint256 j = 0; j < spokePositionUpdaterRoleSelectors.length; j++) {
        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.spokeAdmin,
          report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
          spokePositionUpdaterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'SpokeAdminRole allowed');
        assertEq(delay, 0, 'SpokeAdminRole delay');

        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
            spokePositionUpdaterRoleSelectors[j]
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
        report.hubBatchReports[i].report.treasurySpokeAddress,
        inputs,
        inputs.hubLabels[i]
      );
      for (uint256 j = 0; j < hubFeeMinterRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubBatchReports[i].report.hubAddress,
            hubFeeMinterRoleSelectors[j]
          ),
          Roles.HUB_FEE_MINTER_ROLE,
          'HubAdminRole target function'
        );

        (bool allowed, uint32 delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubBatchReports[i].report.hubAddress,
          hubFeeMinterRoleSelectors[j]
        );
        assertEq(allowed, inputs.grantRoles ? true : false, 'HubAdminRole allowed');
        assertEq(delay, 0, 'HubAdminRole delay');
      }
    }
  }

  function _checkTreasurySpokeRoles(
    address treasurySpokeAddress,
    FullDeployInputs memory inputs,
    string memory label
  ) internal view {
    assertEq(
      Ownable(treasurySpokeAddress).owner(),
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
        report.configuratorBatchReport.hubConfiguratorAddress,
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
      for (uint256 j = 0; j < hubConfiguratorRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubBatchReports[i].report.hubAddress,
            hubConfiguratorRoleSelectors[j]
          ),
          Roles.HUB_CONFIGURATOR_ROLE,
          'HubConfiguratorRole target function'
        );
        bool allowed;
        uint32 delay;

        (allowed, delay) = accessManager.canCall(
          report.configuratorBatchReport.hubConfiguratorAddress,
          report.hubBatchReports[i].report.hubAddress,
          hubConfiguratorRoleSelectors[j]
        );
        assertEq(
          allowed,
          inputs.grantRoles ? true : false,
          'HubConfiguratorRole allowed - configurator'
        );
        assertEq(delay, 0, 'HubConfiguratorRole delay - configurator');

        (allowed, delay) = accessManager.canCall(
          inputs.hubAdmin,
          report.hubBatchReports[i].report.hubAddress,
          hubConfiguratorRoleSelectors[j]
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
      Ownable(report.configuratorBatchReport.hubConfiguratorAddress).owner(),
      inputs.hubConfiguratorOwner,
      'HubConfigurator owner'
    );
    assertEq(
      Ownable(report.configuratorBatchReport.spokeConfiguratorAddress).owner(),
      inputs.spokeConfiguratorOwner,
      'SpokeConfigurator owner'
    );
  }

  function _checkGatewayRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    if (inputs.nativeWrapperAddress != address(0)) {
      assertEq(
        Ownable(report.gatewaysBatchReport.nativeGatewayAddress).owner(),
        inputs.gatewayOwner,
        'NativeGateway owner'
      );
    }
    assertEq(
      Ownable(report.gatewaysBatchReport.signatureGatewayAddress).owner(),
      inputs.gatewayOwner,
      'SignatureGateway owner'
    );
  }
}
