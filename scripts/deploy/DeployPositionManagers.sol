// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {AllowancePositionManager} from 'src/position-manager/AllowancePositionManager.sol';
import {SupplyRepayPositionManager} from 'src/position-manager/SupplyRepayPositionManager.sol';
import {ConfigPositionManager} from 'src/position-manager/ConfigPositionManager.sol';
import {ConfigReader} from '../ConfigReader.sol';
import {DeployLogger} from '../DeployLogger.sol';
import {DeployReport, DeployReportLib} from './DeployTypes.sol';

/// @title DeployPositionManagers
/// @notice Deploys all position managers and registers them on spokes.
library DeployPositionManagers {
  using ConfigReader for string;
  using DeployReportLib for DeployReport;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Deploy enabled position managers and register on spokes.
  function deployPositionManagers(DeployReport storage report, string memory json) internal {
    (, address caller, ) = vm.readCallers();

    // Deploy each PM if enabled in config
    if (json.deploySignatureGateway()) {
      report.signatureGateway = address(new SignatureGateway(caller));
      DeployLogger.logPeriphery('signatureGateway', report.signatureGateway);
    }
    if (json.deployNativeTokenGateway()) {
      address nativeToken = report.findToken(json.nativeTokenKey()).token;
      report.nativeTokenGateway = address(new NativeTokenGateway(nativeToken, caller));
      DeployLogger.logPeriphery('nativeTokenGateway', report.nativeTokenGateway);
    }
    if (json.deployAllowancePositionManager()) {
      report.allowancePositionManager = address(new AllowancePositionManager(caller));
      DeployLogger.logPeriphery('allowancePositionManager', report.allowancePositionManager);
    }
    if (json.deploySupplyRepayPositionManager()) {
      report.supplyRepayPositionManager = address(new SupplyRepayPositionManager(caller));
      DeployLogger.logPeriphery('supplyRepayPositionManager', report.supplyRepayPositionManager);
    }
    if (json.deployConfigPositionManager()) {
      report.configPositionManager = address(new ConfigPositionManager(caller));
      DeployLogger.logPeriphery('configPositionManager', report.configPositionManager);
    }

    // Register on spokes
    for (uint256 i; i < report.spokes.length; ++i) {
      ConfigReader.SpokeDeployConfig memory sc = json.readSpoke(i);
      if (!sc.registerOnPositionManagers) continue;

      ISpoke spoke = ISpoke(report.spokes[i].spoke);
      _registerPm(spoke, report.signatureGateway);
      _registerPm(spoke, report.nativeTokenGateway);
      _registerPm(spoke, report.allowancePositionManager);
      _registerPm(spoke, report.supplyRepayPositionManager);
      _registerPm(spoke, report.configPositionManager);
    }
  }

  function _registerPm(ISpoke spoke, address pm) private {
    if (pm == address(0)) return;
    IPositionManagerBase(pm).registerSpoke(address(spoke), true);
    spoke.updatePositionManager(pm, true);
  }
}
