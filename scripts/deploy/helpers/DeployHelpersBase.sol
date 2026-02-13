// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ScriptUtils} from 'scripts/ScriptUtils.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title DeployHelpersBase
/// @notice Shared imports and utility functions for hub-side and spoke-side deploy helpers.
///         Centralizes ConfigReader usage, role constants, and report resolution helpers.
abstract contract DeployHelpersBase {
  using ConfigReader for string;

  /// @dev Resolves a spoke key to the deployed spoke proxy address from the report.
  function _resolveSpokeAddress(
    string memory json,
    OrchestrationReports.FullDeploymentReport memory report,
    string memory spokeKey_,
    uint256 spokeCount
  ) internal pure returns (address) {
    for (uint256 i; i < spokeCount; i++) {
      if (ScriptUtils.strEq(json.spokeKey(i), spokeKey_)) {
        return report.spokeInstanceBatchReports[i].report.spokeProxy;
      }
    }
    revert(string.concat('Spoke key not found in report: ', spokeKey_));
  }

  /// @dev Finds tokenization config for an asset on a hub from the assets array.
  function _findTokenization(
    string memory json,
    string memory assetKey,
    string memory hubKey_
  ) internal view returns (bool enabled, uint40 addCap) {
    uint256 i;
    while (json.assetExists(i)) {
      ConfigReader.AssetConfig memory a = json.readAsset(i);
      if (ScriptUtils.strEq(a.tokenKey, assetKey) && ScriptUtils.strEq(a.hubKey, hubKey_)) {
        return (a.tokenizeEnabled, a.tokenizeAddCap);
      }
      i++;
    }
    return (false, 0);
  }

  /// @dev Finds the hub address for a spoke by looking at its reserve configs.
  function _findHubForSpoke(
    string memory json,
    OrchestrationReports.FullDeploymentReport memory report,
    string memory spokeKey_,
    uint256 reserveCount,
    uint256 hubCount
  ) internal pure returns (address) {
    for (uint256 i; i < reserveCount; i++) {
      ConfigReader.ReserveConfig memory r = json.readReserve(i);
      if (ScriptUtils.strEq(r.spokeKey, spokeKey_)) {
        for (uint256 h; h < hubCount; h++) {
          if (ScriptUtils.strEq(json.hubKey(h), r.hubKey)) {
            return report.hubBatchReports[h].report.hub;
          }
        }
      }
    }
    return address(0);
  }
}
