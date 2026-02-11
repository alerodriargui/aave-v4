// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ConfigReader} from './ConfigReader.sol';

/// @title DeployLogger
/// @notice Dual-output logging: console2 AND JSONL file.
///         Each public method logs human-readable to console and a JSON line to file.
library DeployLogger {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  string internal constant DEFAULT_LOG_PATH = 'output/deploy.log.jsonl';

  // ==================== Log Path ====================

  function logPath() internal view returns (string memory) {
    return vm.envOr('LOG_PATH', DEFAULT_LOG_PATH);
  }

  // ==================== Private JSON Helpers ====================

  function _str(string memory key, string memory val) private pure returns (string memory) {
    return string.concat('"', key, '":"', val, '"');
  }

  function _uint(string memory key, uint256 val) private pure returns (string memory) {
    return string.concat('"', key, '":', vm.toString(val));
  }

  function _addr(string memory key, address val) private pure returns (string memory) {
    return string.concat('"', key, '":"', vm.toString(val), '"');
  }

  function _bool(string memory key, bool val) private pure returns (string memory) {
    return string.concat('"', key, '":', val ? 'true' : 'false');
  }

  function _wrap(string memory event_, string memory fields) private view returns (string memory) {
    return
      string.concat(
        '{"ts":',
        vm.toString(vm.unixTime()),
        ',"event":"',
        event_,
        '","data":{',
        fields,
        '}}'
      );
  }

  function _writeLine(string memory line) private {
    vm.writeLine(logPath(), line);
  }

  // ==================== Section Headers ====================

  function logSection(string memory name) internal {
    // console.log(string.concat('\n-----', name, '-----'));
    _writeLine(_wrap('section', _str('name', name)));
  }

  // ==================== Simple Messages ====================

  function logAddress(string memory label, address addr) internal {
    // console.log(label, addr);
    _writeLine(_wrap('address', string.concat(_str('label', label), ',', _addr('address', addr))));
  }

  function logMessage(string memory event_, string memory message) internal {
    // console.log(message);
    _writeLine(_wrap(event_, _str('message', message)));
  }

  // ==================== Struct Loggers ====================

  function logAssetListed(
    ConfigReader.AssetConfig memory conf,
    uint256 assetId_,
    address treasury,
    address irStrategy
  ) internal {
    // console.log('token\t\t\t\t\t', conf.tokenKey);
    // console.log('assetId\t\t\t\t', assetId_);
    // console.log('treasury\t\t\t\t', treasury);
    // console.log('liquidityFee\t\t\t\t', conf.liquidityFee);
    // console.log('irStrategy\t\t\t\t', irStrategy);
    // console.log('irStrategy.optimalUsageRatio\t', conf.irData.optimalUsageRatio);
    // console.log('irStrategy.baseVariableBorrowRate\t', conf.irData.baseVariableBorrowRate);
    // console.log('irStrategy.variableRateSlope1\t', conf.irData.variableRateSlope1);
    // console.log('irStrategy.variableRateSlope2\t', conf.irData.variableRateSlope2);
    // console.log();

    string memory f1 = string.concat(
      _str('token', conf.tokenKey),
      ',',
      _str('hub', conf.hubKey),
      ',',
      _uint('assetId', assetId_),
      ','
    );
    string memory f2 = string.concat(
      _addr('treasury', treasury),
      ',',
      _uint('liquidityFee', uint256(conf.liquidityFee)),
      ',',
      _addr('irStrategy', irStrategy),
      ','
    );
    string memory f3 = string.concat(
      _uint('optimalUsageRatio', uint256(conf.irData.optimalUsageRatio)),
      ',',
      _uint('baseVariableBorrowRate', uint256(conf.irData.baseVariableBorrowRate)),
      ',',
      _uint('variableRateSlope1', uint256(conf.irData.variableRateSlope1)),
      ',',
      _uint('variableRateSlope2', uint256(conf.irData.variableRateSlope2))
    );
    _writeLine(_wrap('assetListed', string.concat(f1, f2, f3)));
  }

  function logSpokeRegistered(
    ConfigReader.SpokeRegConfig memory conf,
    IHub.SpokeConfig memory sc
  ) internal {
    // console.log('spoke\t\t\t\t\t', conf.spokeKey);
    // console.log('token\t\t\t\t\t', conf.assetKey);
    // console.log('addCap\t\t\t\t %e', sc.addCap);
    // console.log('drawCap\t\t\t\t %e', sc.drawCap);
    // console.log('active\t\t\t\t', sc.active);
    // console.log();

    string memory f1 = string.concat(
      _str('spoke', conf.spokeKey),
      ',',
      _str('token', conf.assetKey),
      ',',
      _str('hub', conf.hubKey),
      ',',
      _uint('addCap', uint256(sc.addCap)),
      ','
    );
    string memory f2 = string.concat(
      _uint('drawCap', uint256(sc.drawCap)),
      ',',
      _uint('riskPremiumThreshold', uint256(sc.riskPremiumThreshold)),
      ',',
      _bool('active', sc.active),
      ',',
      _bool('halted', sc.halted)
    );
    _writeLine(_wrap('spokeRegistered', string.concat(f1, f2)));
  }

  function logReserveListed(
    ConfigReader.ReserveConfig memory conf,
    uint256 reserveId_,
    uint256 assetId_,
    ISpoke.ReserveConfig memory rc,
    ISpoke.DynamicReserveConfig memory dyn,
    address priceFeed,
    uint256 price
  ) internal {
    // console.log('hub\t\t\t\t\t', conf.hubKey);
    // console.log('token\t\t\t\t\t', conf.assetKey);
    // console.log('reserveId\t\t\t\t', reserveId_);
    // console.log('assetId\t\t\t\t', assetId_);
    // console.log('frozen\t\t\t\t', rc.frozen);
    // console.log('paused\t\t\t\t', rc.paused);
    // console.log('borrowable\t\t\t\t', rc.borrowable);
    // console.log('collateralRisk\t\t\t', rc.collateralRisk);
    // console.log('maxLiquidationBonus\t\t\t', dyn.maxLiquidationBonus);
    // console.log('liquidationFee\t\t\t', dyn.liquidationFee);
    // console.log('collateralFactor\t\t\t', dyn.collateralFactor);
    // console.log('price feed\t\t\t\t', priceFeed);
    // console.log('price\t\t\t\t\t %e', price);
    // console.log();

    string memory f1 = string.concat(
      _str('hub', conf.hubKey),
      ',',
      _str('spoke', conf.spokeKey),
      ',',
      _str('token', conf.assetKey),
      ',',
      _uint('reserveId', reserveId_),
      ','
    );
    string memory f2 = string.concat(
      _uint('assetId', assetId_),
      ',',
      _bool('frozen', rc.frozen),
      ',',
      _bool('paused', rc.paused),
      ',',
      _bool('borrowable', rc.borrowable),
      ','
    );
    string memory f3 = string.concat(
      _uint('collateralRisk', uint256(rc.collateralRisk)),
      ',',
      _uint('maxLiquidationBonus', uint256(dyn.maxLiquidationBonus)),
      ',',
      _uint('liquidationFee', uint256(dyn.liquidationFee)),
      ','
    );
    string memory f4 = string.concat(
      _uint('collateralFactor', uint256(dyn.collateralFactor)),
      ',',
      _addr('priceFeed', priceFeed),
      ',',
      _uint('price', price)
    );
    _writeLine(_wrap('reserveListed', string.concat(f1, f2, f3, f4)));
  }

  function logSpokeUpdated(
    ConfigReader.SpokeRegConfig memory conf,
    IHub.SpokeConfig memory sc
  ) internal {
    // console.log('spoke\t\t\t\t\t', conf.spokeKey);
    // console.log('token\t\t\t\t\t', conf.assetKey);
    // console.log('addCap\t\t\t\t %e', sc.addCap);
    // console.log('drawCap\t\t\t\t %e', sc.drawCap);
    // console.log('active\t\t\t\t', sc.active);
    // console.log();

    string memory f1 = string.concat(
      _str('spoke', conf.spokeKey),
      ',',
      _str('token', conf.assetKey),
      ',',
      _str('hub', conf.hubKey),
      ',',
      _uint('addCap', uint256(sc.addCap)),
      ','
    );
    string memory f2 = string.concat(
      _uint('drawCap', uint256(sc.drawCap)),
      ',',
      _bool('active', sc.active)
    );
    _writeLine(_wrap('spokeUpdated', string.concat(f1, f2)));
  }

  function logLiquidationConfig(
    string memory spokeKey,
    ISpoke.LiquidationConfig memory lc
  ) internal {
    // console.log('Updated liquidation config for', spokeKey);

    string memory fields = string.concat(
      _str('spoke', spokeKey),
      ',',
      _uint('targetHealthFactor', uint256(lc.targetHealthFactor)),
      ',',
      _uint('healthFactorForMaxBonus', uint256(lc.healthFactorForMaxBonus)),
      ',',
      _uint('liquidationBonusFactor', uint256(lc.liquidationBonusFactor))
    );
    _writeLine(_wrap('liquidationConfig', fields));
  }

  // ==================== Deploy Events ====================

  function logSpokeDeployed(string memory key, address spokeAddr) internal {
    // console.log(spokeAddr, key);
    _writeLine(
      _wrap('spokeDeployed', string.concat(_str('key', key), ',', _addr('address', spokeAddr)))
    );
  }

  function logTokenizationSpokeDeployed(string memory tsKey, address tsAddr) internal {
    // console.log(tsAddr, string.concat('TOKENIZED_', tsKey));
    _writeLine(
      _wrap(
        'tokenizationSpokeDeployed',
        string.concat(_str('key', tsKey), ',', _addr('address', tsAddr))
      )
    );
  }

  function logPeriphery(string memory label, address addr) internal {
    // console.log(label, addr);
    _writeLine(
      _wrap('periphery', string.concat(_str('label', label), ',', _addr('address', addr)))
    );
  }

  function logConfigurator(string memory label, address addr) internal {
    // console.log(label, addr);
    _writeLine(
      _wrap('configurator', string.concat(_str('label', label), ',', _addr('address', addr)))
    );
  }
}
