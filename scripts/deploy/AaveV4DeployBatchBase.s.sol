// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

import {Script} from 'forge-std/Script.sol';

// solhint-disable quotes
abstract contract AaveV4DeployBatchBaseScript is Script, InputUtils {
  struct Lines {
    string[] s;
  }

  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal _outputFileName;
  Lines internal _promptLines;
  Lines internal _summaryLines;

  constructor(string memory outputFileName_) {
    _outputFileName = outputFileName_;
  }

  function run() external virtual {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);

    (, address deployer, ) = vm.readCallers();

    FullDeployInputs memory inputs = _getDeployInputs();
    inputs = _loadWarningsAndSanitizeInputs(inputs, deployer);

    logger.log('CHAIN ID', block.chainid);
    logger.logHeader1('Starting Aave V4 Batch Deployment');
    vm.startBroadcast(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(logger, deployer, inputs, _getHubBytecode(), _getSpokeBytecode());
    vm.stopBroadcast();
    logger.writeJsonReportMarket(report);
    _logDeploySummary(logger);
    logger.logHeader1('Batch Deployment Completed');
    logger.logHeader1('Saving Logs');
    logger.save({fileName: _outputFileName, withTimestamp: true});
  }

  /// @dev Override to provide deployment inputs from any source.
  function _getDeployInputs() internal virtual returns (FullDeployInputs memory);

  function _loadWarningsAndSanitizeInputs(
    FullDeployInputs memory inputs,
    address deployer
  ) internal virtual returns (FullDeployInputs memory) {
    string memory message = ' is zero address';
    string memory outcome = '; defaulting to deployer';

    FullDeployInputs memory sanitizedInputs = inputs;

    // Validate label uniqueness (duplicate labels produce identical CREATE2 salts)
    _validateUniqueLabels(inputs.hubLabels, 'hub');
    _validateUniqueLabels(inputs.spokeLabels, 'spoke');

    _appendSummary('========== DEPLOYMENT SUMMARY ==========');
    // Hubs
    if (inputs.hubLabels.length > 0) {
      _appendSummary(string.concat('Hubs to deploy: ', vm.toString(inputs.hubLabels.length)));
      for (uint256 i; i < inputs.hubLabels.length; i++) {
        _appendSummary(string.concat('  - ', inputs.hubLabels[i]));
      }
    } else {
      _logWarning('No hubs will be deployed');
    }

    // Spokes
    if (inputs.spokeLabels.length > 0) {
      _appendSummary(string.concat('Spokes to deploy: ', vm.toString(inputs.spokeLabels.length)));
      for (uint256 i; i < inputs.spokeLabels.length; i++) {
        _appendSummary(string.concat('  - ', inputs.spokeLabels[i]));
      }
    } else {
      _logWarning('No spokes will be deployed');
    }

    // NativeTokenGateway
    if (inputs.deployNativeTokenGateway) {
      if (inputs.nativeWrapper == address(0)) {
        _logWarning('deployNativeTokenGateway is true but nativeWrapper is zero address');
      } else {
        _appendSummary('NativeTokenGateway will be deployed');
      }
    } else {
      _appendSummary('NativeTokenGateway: skipped (deployNativeTokenGateway is false)');
    }

    // SignatureGateway
    if (inputs.deploySignatureGateway) {
      _appendSummary('SignatureGateway will be deployed');
    } else {
      _appendSummary('SignatureGateway: skipped (deploySignatureGateway is false)');
    }

    // PositionManagers
    if (inputs.deployPositionManagers) {
      _appendSummary('PositionManagers (Giver/Taker) will be deployed');
    } else {
      _appendSummary('PositionManagers: skipped (deployPositionManagers is false)');
    }

    // Roles
    if (inputs.grantRoles) {
      _appendSummary('Roles: will be granted during deployment');
    } else {
      _appendSummary('Roles: deferred (not granted during deployment)');
    }

    _appendSummary('--------------------------------------------------');

    // Sanitize zero addresses
    if (inputs.grantRoles) {
      if (inputs.accessManagerAdmin == address(0)) {
        _logWarning(string.concat('Access Manager Admin', message, outcome));
        sanitizedInputs.accessManagerAdmin = deployer;
      }
      if (inputs.hubConfiguratorAdmin == address(0)) {
        _logWarning(string.concat('Hub Configurator Admin', message, outcome));
        sanitizedInputs.hubConfiguratorAdmin = deployer;
      }
      if (inputs.spokeConfiguratorAdmin == address(0)) {
        _logWarning(string.concat('Spoke Configurator Admin', message, outcome));
        sanitizedInputs.spokeConfiguratorAdmin = deployer;
      }
      if (inputs.spokeProxyAdminOwner == address(0)) {
        _logWarning(string.concat('Spoke Proxy Admin Owner', message, outcome));
        sanitizedInputs.spokeProxyAdminOwner = deployer;
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        _logWarning(string.concat('Treasury Spoke Owner', message, outcome));
        sanitizedInputs.treasurySpokeOwner = deployer;
      }
      if (inputs.spokeAdmin == address(0)) {
        _logWarning(string.concat('Spoke Admin', message, outcome));
        sanitizedInputs.spokeAdmin = deployer;
      }
      if (inputs.hubAdmin == address(0)) {
        _logWarning(string.concat('Hub Admin', message, outcome));
        sanitizedInputs.hubAdmin = deployer;
      }
    } else {
      _logWarning('Roles: deferred (not granted during deployment)');
      sanitizedInputs.treasurySpokeOwner = deployer;
      sanitizedInputs.spokeProxyAdminOwner = deployer;
    }
    if (inputs.gatewayOwner == address(0)) {
      _logWarning(string.concat('Gateway owner', message, outcome));
      sanitizedInputs.gatewayOwner = deployer;
    }
    if (inputs.positionManagerOwner == address(0)) {
      _logWarning(string.concat('Position Manager owner', message, outcome));
      sanitizedInputs.positionManagerOwner = deployer;
    }
    if (inputs.salt == bytes32(0)) {
      _logWarning('salt is zero');
    }

    _executeUserPrompt();
    return sanitizedInputs;
  }

  function _executeUserPrompt() internal virtual {
    if (_promptLines.s.length > 0) {
      string memory ack = vm.prompt(
        string.concat(_joinLines(_promptLines), "\nEnter 'y' to continue")
      );
      if (keccak256(bytes(ack)) != keccak256(bytes('y'))) {
        revert('User did not acknowledge. Please try again.');
      }
    }
  }

  function _getHubBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/Hub.sol:Hub');
  }

  function _getSpokeBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
  }

  function _appendSummary(string memory line) internal virtual {
    _promptLines.s.push(line);
    _summaryLines.s.push(line);
  }

  function _logWarning(string memory warning) internal virtual {
    _promptLines.s.push(string.concat('WARNING: ', warning));
  }

  /// @dev Writes the deployment summary to the logger (called after deployment).
  function _logDeploySummary(MetadataLogger logger) internal virtual {
    for (uint256 i; i < _summaryLines.s.length; i++) {
      logger.log(_summaryLines.s[i]);
    }
  }

  function _joinLines(Lines storage lines) internal view virtual returns (string memory) {
    uint256 n = lines.s.length;
    if (n == 0) {
      return '';
    }
    string memory out = lines.s[0];
    for (uint256 i = 1; i < n; i++) {
      out = string.concat(out, '\n', lines.s[i]);
    }
    return string.concat(out, '\n');
  }
}
