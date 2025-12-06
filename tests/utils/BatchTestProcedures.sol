// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IProgressLogger} from 'src/deployments/utils/interfaces/IProgressLogger.sol';
import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {MockLogger} from 'tests/mocks/MockLogger.sol';
import {WETHDeployProcedure} from 'src/deployments/procedures/deploy/WETHDeployProcedure.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

contract BatchTestProcedures is Test, InputUtils, WETHDeployProcedure {
  bytes4[] public spokeAdminRoleSelectors;
  bytes4[] public hubAdminRoleSelectors;
  bytes4[] public userPositionUpdaterRoleSelectors;

  function setUp() public virtual {
    spokeAdminRoleSelectors = new bytes4[](7);
    spokeAdminRoleSelectors[0] = ISpoke.updateLiquidationConfig.selector;
    spokeAdminRoleSelectors[1] = ISpoke.addReserve.selector;
    spokeAdminRoleSelectors[2] = ISpoke.updateReserveConfig.selector;
    spokeAdminRoleSelectors[3] = ISpoke.updateDynamicReserveConfig.selector;
    spokeAdminRoleSelectors[4] = ISpoke.addDynamicReserveConfig.selector;
    spokeAdminRoleSelectors[5] = ISpoke.updatePositionManager.selector;
    spokeAdminRoleSelectors[6] = ISpoke.updateReservePriceSource.selector;

    hubAdminRoleSelectors = new bytes4[](6);
    hubAdminRoleSelectors[0] = IHub.addAsset.selector;
    hubAdminRoleSelectors[1] = IHub.updateAssetConfig.selector;
    hubAdminRoleSelectors[2] = IHub.addSpoke.selector;
    hubAdminRoleSelectors[3] = IHub.updateSpokeConfig.selector;
    hubAdminRoleSelectors[4] = IHub.setInterestRateData.selector;
    hubAdminRoleSelectors[5] = IHub.mintFeeShares.selector;

    userPositionUpdaterRoleSelectors = new bytes4[](2);
    userPositionUpdaterRoleSelectors[0] = ISpoke.updateUserDynamicConfig.selector;
    userPositionUpdaterRoleSelectors[1] = ISpoke.updateUserRiskPremium.selector;
  }

  function deployAaveV4Testnet(
    address deployer,
    IProgressLogger logger,
    FullDeployInputs memory inputs
  ) public returns (OrchestrationReports.FullDeploymentReport memory) {
    vm.startPrank(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(
        logger,
        deployer,
        inputs.admin,
        inputs.nativeWrapperAddress,
        inputs.hubLabels,
        inputs.spokeLabels,
        inputs.setRoles,
        false
      );
    vm.stopPrank();
    return report;
  }

  function _checkFullReport(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal pure {
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
      report.gatewaysBatchReport.nativeGatewayAddress,
      address(0),
      'NativeGatewayAddress'
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

  function _checkRoles(
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(
      report.accessBatchReport.accessManagerAddress
    );
    _checkAccessManagerRoles(accessManager, report, inputs);
    _checkSpokeAdminRoles(accessManager, report, inputs);
    _checkHubAdminRoles(accessManager, report, inputs);
    // _checkUserPositionUpdaterRoles(report, inputs);
  }

  function _checkAccessManagerRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    assertEq(
      accessManager.getRoleMemberCount(Roles.DEFAULT_ADMIN_ROLE),
      1,
      'DefaultAdminRoleCount'
    );
    assertEq(
      accessManager.getRoleMember(Roles.DEFAULT_ADMIN_ROLE, 0),
      inputs.admin,
      'DefaultAdminRoleMember'
    );
    assertEq(accessManager.getRoleMemberCount(Roles.HUB_ADMIN_ROLE), 1, 'HubAdminRoleCount');
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      assertEq(
        accessManager.getRoleMember(Roles.HUB_ADMIN_ROLE, 0),
        report.configuratorBatchReport.hubConfiguratorAddress,
        'HubAdminRoleMember'
      );
    }
    assertEq(accessManager.getRoleMemberCount(Roles.SPOKE_ADMIN_ROLE), 1, 'SpokeAdminRoleCount');
    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      assertEq(
        accessManager.getRoleMember(Roles.SPOKE_ADMIN_ROLE, 0),
        report.configuratorBatchReport.spokeConfiguratorAddress,
        'SpokeAdminRoleMember'
      );
    }
  }

  function _checkSpokeAdminRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    for (uint256 i = 0; i < inputs.spokeLabels.length; i++) {
      (bool allowed, uint32 delay) = accessManager.canCall(
        report.configuratorBatchReport.spokeConfiguratorAddress,
        report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
        spokeAdminRoleSelectors[i]
      );
      assertTrue(allowed, 'SpokeAdminRoleCanCall');
      assertEq(delay, 0, 'SpokeAdminRoleDelay');

      // check target function roles on spoke admin role
      for (uint256 j = 0; j < spokeAdminRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
            spokeAdminRoleSelectors[j]
          ),
          Roles.SPOKE_ADMIN_ROLE,
          'SpokeAdminRoleTargetFunction'
        );
      }

      // check target function roles on user position updater role
      for (uint256 j = 0; j < userPositionUpdaterRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.spokeInstanceBatchReports[i].report.spokeProxyAddress,
            userPositionUpdaterRoleSelectors[j]
          ),
          Roles.USER_POSITION_UPDATER_ROLE,
          'UserPositionUpdaterRoleTargetFunction'
        );
      }
    }
  }

  function _checkHubAdminRoles(
    IAccessManagerEnumerable accessManager,
    OrchestrationReports.FullDeploymentReport memory report,
    FullDeployInputs memory inputs
  ) internal view {
    for (uint256 i = 0; i < inputs.hubLabels.length; i++) {
      (bool allowed, uint32 delay) = accessManager.canCall(
        report.configuratorBatchReport.hubConfiguratorAddress,
        report.hubBatchReports[i].report.hubAddress,
        hubAdminRoleSelectors[i]
      );
      assertTrue(allowed, 'HubAdminRoleCanCall');
      assertEq(delay, 0, 'HubAdminRoleDelay');

      for (uint256 j = 0; j < hubAdminRoleSelectors.length; j++) {
        assertEq(
          accessManager.getTargetFunctionRole(
            report.hubBatchReports[i].report.hubAddress,
            hubAdminRoleSelectors[j]
          ),
          Roles.HUB_ADMIN_ROLE,
          'HubAdminRoleTargetFunction'
        );
      }
    }
  }
}
